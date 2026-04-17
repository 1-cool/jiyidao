package com.pincode.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
        private const val SMS_EVENT_CHANNEL = "com.pincode.app/sms_receiver"
        private const val METHOD_CHANNEL = "com.pincode.app/method"
        const val SMS_CODE_RECEIVED = "com.pincode.app.SMS_CODE_RECEIVED"
        const val PREF_SMS_ENABLED = "sms_listener_enabled"
    }
    
    private var smsEventSink: EventChannel.EventSink? = null
    private var smsReceiver: BroadcastReceiver? = null
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
                        val editor = prefs.edit()
                        editor.putBoolean(PREF_SMS_ENABLED, enabled)
                        editor.apply()
                        
                        if (enabled) {
                            registerSmsReceiver()
                        } else {
                            unregisterSmsReceiver()
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
        
        // 事件通道 - 用于接收短信
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    smsEventSink = events
                    
                    // 检查是否启用
                    val enabled = prefs.getBoolean(PREF_SMS_ENABLED, false)
                    if (enabled) {
                        registerSmsReceiver()
                    }
                    
                    Log.d(TAG, "EventChannel 已连接, 短信监听: $enabled")
                }
                
                override fun onCancel(arguments: Any?) {
                    smsEventSink = null
                    unregisterSmsReceiver()
                    Log.d(TAG, "EventChannel 已断开")
                }
            })
    }
    
    /**
     * 注册短信广播接收器
     */
    private fun registerSmsReceiver() {
        if (smsReceiver != null) return
        
        smsReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent == null) return
                
                val code = intent.getStringExtra("code") ?: return
                val body = intent.getStringExtra("body") ?: ""
                val sender = intent.getStringExtra("sender") ?: ""
                
                Log.d(TAG, "收到短信取件码: $code")
                
                // 发送到 Flutter
                smsEventSink?.success(mapOf(
                    "code" to code,
                    "body" to body,
                    "sender" to sender
                ))
            }
        }
        
        val filter = IntentFilter(SMS_CODE_RECEIVED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(smsReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(smsReceiver, filter)
        }
        
        Log.d(TAG, "短信广播接收器已注册")
    }
    
    /**
     * 注销短信广播接收器
     */
    private fun unregisterSmsReceiver() {
        smsReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {
                Log.e(TAG, "注销接收器失败: ${e.message}")
            }
            smsReceiver = null
            Log.d(TAG, "短信广播接收器已注销")
        }
    }
    
    override fun onDestroy() {
        unregisterSmsReceiver()
        super.onDestroy()
    }
}
