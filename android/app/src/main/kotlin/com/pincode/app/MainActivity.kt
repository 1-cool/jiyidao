package com.pincode.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
import android.provider.Telephony
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * 主 Activity
 * 
 * 负责：
 * 1. 注册 Flutter 插件
 * 2. 监听系统短信广播
 * 3. 将短信内容传递给 Flutter 层处理
 */
class MainActivity: FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
        private const val SMS_EVENT_CHANNEL = "com.pincode.app/sms_receiver"
        private const val METHOD_CHANNEL = "com.pincode.app/method"
        private const val PREF_SMS_ENABLED = "sms_listener_enabled"
        private const val ACTION_SMS_RECEIVED = "android.provider.Telephony.SMS_RECEIVED"
    }
    
    private var smsEventSink: EventChannel.EventSink? = null
    private var systemSmsReceiver: BroadcastReceiver? = null
    private lateinit var prefs: SharedPreferences
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 注册 OPPO 灵动岛插件
        OppoIslandPlugin.register(flutterEngine, this)
        
        // 方法通道 - 用于同步设置
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSmsListenerEnabled" -> {
                        val enabled = call.arguments as? Boolean ?: false
                        prefs.edit().putBoolean(PREF_SMS_ENABLED, enabled).apply()
                        
                        if (enabled) {
                            registerSystemSmsReceiver()
                        } else {
                            unregisterSystemSmsReceiver()
                        }
                        
                        result.success(null)
                    }
                    "isSmsListenerEnabled" -> {
                        val enabled = prefs.getBoolean(PREF_SMS_ENABLED, false)
                        result.success(enabled)
                    }
                    else -> result.notImplemented()
                }
            }
        
        // 事件通道 - 用于向 Flutter 发送短信内容
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    smsEventSink = events
                    
                    // 检查是否启用
                    val enabled = prefs.getBoolean(PREF_SMS_ENABLED, false)
                    if (enabled) {
                        registerSystemSmsReceiver()
                    }
                    
                    Log.d(TAG, "EventChannel 已连接, 短信监听: $enabled")
                }
                
                override fun onCancel(arguments: Any?) {
                    smsEventSink = null
                    unregisterSystemSmsReceiver()
                    Log.d(TAG, "EventChannel 已断开")
                }
            })
    }
    
    /**
     * 注册系统短信广播接收器
     * 
     * 直接监听系统短信，将原始内容传递给 Flutter 层处理
     * 不在原生层做正则匹配，统一由 Flutter 的 PatternMatcher 处理
     */
    private fun registerSystemSmsReceiver() {
        if (systemSmsReceiver != null) return
        
        systemSmsReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent == null || intent.action != ACTION_SMS_RECEIVED) return
                
                val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                for (sms in messages) {
                    val body = sms.messageBody ?: continue
                    val sender = sms.displayOriginatingAddress ?: ""
                    
                    Log.d(TAG, "收到短信: sender=$sender, body=${body.take(50)}...")
                    
                    // 将原始短信内容发送到 Flutter 层
                    // Flutter 的 PatternMatcher 会进行正则匹配
                    smsEventSink?.success(mapOf(
                        "body" to body,
                        "sender" to sender
                    ))
                }
            }
        }
        
        val filter = IntentFilter(ACTION_SMS_RECEIVED)
        filter.priority = IntentFilter.SYSTEM_HIGH_PRIORITY
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(systemSmsReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(systemSmsReceiver, filter)
        }
        
        Log.d(TAG, "系统短信接收器已注册")
    }
    
    /**
     * 注销系统短信广播接收器
     */
    private fun unregisterSystemSmsReceiver() {
        systemSmsReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {
                Log.e(TAG, "注销接收器失败: ${e.message}")
            }
            systemSmsReceiver = null
            Log.d(TAG, "系统短信接收器已注销")
        }
    }
    
    override fun onDestroy() {
        unregisterSystemSmsReceiver()
        super.onDestroy()
    }
}
