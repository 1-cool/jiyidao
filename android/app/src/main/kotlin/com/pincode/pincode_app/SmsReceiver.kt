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
        // 启动前台服务来显示通知
        val intent = Intent(context, PinCodeService::class.java).apply {
            action = "SHOW_CODE"
            putExtra("code", code)
            putExtra("body", body)
        }
        context.startService(intent)
    }
    
    /**
     * 通知 Flutter 层
     */
    private fun notifyFlutter(context: Context, code: String, body: String, sender: String) {
        // 通过 EventChannel 或 MethodChannel 通知 Flutter
        // 这里简化处理，实际需要通过 FlutterEngine 通信
        val intent = Intent("com.pincode.app.SMS_CODE_RECEIVED").apply {
            putExtra("code", code)
            putExtra("body", body)
            putExtra("sender", sender)
            setPackage(context.packageName)
        }
        context.sendBroadcast(intent)
    }
}
