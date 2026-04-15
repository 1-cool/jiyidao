package com.pincode.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity: FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
        private const val SMS_EVENT_CHANNEL = "com.pincode.app/sms_receiver"
        const val SMS_CODE_RECEIVED = "com.pincode.app.SMS_CODE_RECEIVED"
    }
    
    private var smsEventSink: EventChannel.EventSink? = null
    private var smsReceiver: BroadcastReceiver? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 设置短信事件通道
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    smsEventSink = events
                    registerSmsReceiver()
                    Log.d(TAG, "EventChannel 已连接")
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
            unregisterReceiver(it)
            smsReceiver = null
            Log.d(TAG, "短信广播接收器已注销")
        }
    }
    
    override fun onDestroy() {
        unregisterSmsReceiver()
        super.onDestroy()
    }
}
