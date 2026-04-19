package com.pincode.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log

/**
 * 短信接收器
 * 
 * 监听系统短信广播，识别取件码
 */
class SmsReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "SmsReceiver"
        private const val PREF_SMS_ENABLED = "sms_listener_enabled"
        
        // 取件码正则表达式
        private val CODE_PATTERNS = listOf(
            // 菜鸟驿站格式
            Regex("""取件码[：:]\s*(\d{1,2}-\d{1,2}-\d{3,4})"""),
            // 丰巢/快递柜
            Regex("""(?:丰巢|快递柜).*?取件码[：:]?\s*(\d{6,8})"""),
            // 通用取件码
            Regex("""取件码[：:]\s*(\d{4,8})"""),
            // 取餐码
            Regex("""取餐码[：:]\s*(\d{2,4})"""),
        )
    }
    
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        
        // 检查开关状态
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val enabled = prefs.getBoolean(PREF_SMS_ENABLED, false)
        if (!enabled) {
            Log.d(TAG, "短信监听已关闭，跳过处理")
            return
        }
        
        Log.d(TAG, "收到短信广播")
        
        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        for (sms in messages) {
            val body = sms.messageBody ?: continue
            val sender = sms.displayOriginatingAddress ?: ""
            
            Log.d(TAG, "短信内容: $body")
            
            // 匹配取件码
            for (pattern in CODE_PATTERNS) {
                val match = pattern.find(body)
                if (match != null) {
                    val code = match.groupValues[1]
                    Log.d(TAG, "识别到取件码: $code")
                    
                    // 发送通知
                    showNotification(context, code, body)
                    
                    // 通知 Flutter（如果 App 正在运行）
                    notifyFlutter(context, code, body, sender)
                    
                    break
                }
            }
        }
    }
    
    /**
     * 显示通知
     */
    private fun showNotification(context: Context, code: String, body: String) {
        // 不再启动前台服务，直接通过 Flutter 端处理
        // Flutter 端的 NotificationService 会显示通知
        Log.d(TAG, "取件码已识别，等待 Flutter 端处理: $code")
    }
    
    /**
     * 通知 Flutter 层
     */
    private fun notifyFlutter(context: Context, code: String, body: String, sender: String) {
        // 通过广播通知 MainActivity
        val intent = Intent("com.pincode.app.SMS_CODE_RECEIVED").apply {
            putExtra("code", code)
            putExtra("body", body)
            putExtra("sender", sender)
            setPackage(context.packageName)
        }
        context.sendBroadcast(intent)
    }
}
