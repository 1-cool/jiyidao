package com.pincode.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.provider.Telephony
import android.telephony.SmsMessage
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 短信监听插件
 * 
 * 负责监听系统短信广播，识别取件码并通知 Flutter 层
 */
class SmsListenerPlugin : MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL_NAME = "com.pincode.app/sms"
        private const val ACTION_SMS_RECEIVED = "android.provider.Telephony.SMS_RECEIVED"
        
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
            // 登机口
            Regex("""登机口[：:]\s*([A-Z]\d{1,3})"""),
        )
        
        // 来源关键词
        private val SOURCE_KEYWORDS = mapOf(
            "菜鸟驿站" to listOf("菜鸟驿站", "驿站"),
            "丰巢快递柜" to listOf("丰巢", "快递柜"),
            "美团外卖" to listOf("美团"),
            "饿了么" to listOf("饿了么", "蜂鸟"),
            "顺丰快递" to listOf("顺丰"),
            "京东快递" to listOf("京东"),
        )
        
        fun registerWith(flutterEngine: FlutterEngine, context: Context) {
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            val plugin = SmsListenerPlugin(context, channel)
            channel.setMethodCallHandler(plugin)
        }
    }
    
    private val context: Context
    private val channel: MethodChannel
    private var smsReceiver: BroadcastReceiver? = null
    
    constructor(context: Context, channel: MethodChannel) {
        this.context = context
        this.channel = channel
    }
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startListening" -> {
                startSmsListener()
                result.success(null)
            }
            "stopListening" -> {
                stopSmsListener()
                result.success(null)
            }
            "hasPermission" -> {
                // 检查是否有短信权限
                val hasPermission = context.checkSelfPermission(
                    android.Manifest.permission.RECEIVE_SMS
                ) == android.content.pm.PackageManager.PERMISSION_GRANTED
                result.success(hasPermission)
            }
            else -> result.notImplemented()
        }
    }
    
    /**
     * 开始监听短信
     */
    private fun startSmsListener() {
        if (smsReceiver != null) return // 已经在监听
        
        smsReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent == null || intent.action != ACTION_SMS_RECEIVED) return
                
                val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                for (sms in messages) {
                    processSms(sms)
                }
            }
        }
        
        val filter = IntentFilter(ACTION_SMS_RECEIVED)
        filter.priority = IntentFilter.SYSTEM_HIGH_PRIORITY
        
        context.registerReceiver(smsReceiver, filter)
    }
    
    /**
     * 停止监听短信
     */
    private fun stopSmsListener() {
        smsReceiver?.let {
            context.unregisterReceiver(it)
            smsReceiver = null
        }
    }
    
    /**
     * 处理短信内容
     */
    private fun processSms(sms: SmsMessage) {
        val body = sms.messageBody ?: return
        val sender = sms.displayOriginatingAddress ?: ""
        
        // 匹配取件码
        for (pattern in CODE_PATTERNS) {
            val match = pattern.find(body)
            if (match != null) {
                val code = match.groupValues[1]
                val source = extractSource(body, sender)
                
                // 通知 Flutter 层
                channel.invokeMethod("onSmsReceived", mapOf(
                    "code" to code,
                    "source" to source,
                    "sender" to sender,
                    "body" to body
                ))
                
                break // 只匹配第一个
            }
        }
    }
    
    /**
     * 提取来源
     */
    private fun extractSource(body: String, sender: String): String {
        for ((name, keywords) in SOURCE_KEYWORDS) {
            for (keyword in keywords) {
                if (body.contains(keyword)) {
                    return name
                }
            }
        }
        
        // 根据发送者号码判断
        when {
            sender.contains("1069") -> return "快递通知"
            sender.contains("1065") -> return "外卖平台"
        }
        
        return "未知来源"
    }
}
