package com.pincode.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder
import android.provider.Telephony
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * 前台服务
 * 
 * 用于：
 * 1. 后台保活，持续监听短信
 * 2. 显示常驻通知
 */
class PinCodeService : Service() {
    companion object {
        private const val TAG = "PinCodeService"
        private const val CHANNEL_ID = "pincode_service"
        private const val NOTIFICATION_ID = 1001
        
        // 取件码正则
        private val CODE_PATTERNS = listOf(
            Regex("""取件码[：:]\s*(\d{1,2}-\d{1,2}-\d{3,4})"""),
            Regex("""(?:丰巢|快递柜).*?取件码[：:]?\s*(\d{6,8})"""),
            Regex("""取件码[：:]\s*(\d{4,8})"""),
            Regex("""取餐码[：:]\s*(\d{2,4})"""),
        )
        
        // 来源关键词
        private val SOURCE_KEYWORDS = mapOf(
            "菜鸟驿站" to listOf("菜鸟驿站", "驿站"),
            "丰巢快递柜" to listOf("丰巢", "快递柜"),
            "美团外卖" to listOf("美团"),
            "饿了么" to listOf("饿了么", "蜂鸟"),
        )
    }
    
    private var smsReceiver: android.content.BroadcastReceiver? = null
    private var currentCode: String? = null
    private var currentSource: String? = null
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "服务创建")
        
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createServiceNotification())
        registerSmsReceiver()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "服务启动: action=${intent?.action}")
        
        when (intent?.action) {
            "SHOW_CODE" -> {
                // 显示取件码通知
                val code = intent.getStringExtra("code")
                val body = intent.getStringExtra("body")
                if (code != null && body != null) {
                    showCodeNotification(code, body)
                }
            }
            "UPDATE_CODE" -> {
                // 更新当前显示的码
                currentCode = intent.getStringExtra("code")
                currentSource = intent.getStringExtra("source")
                updateServiceNotification()
            }
            "CLEAR_CODE" -> {
                // 清除当前码
                currentCode = null
                currentSource = null
                updateServiceNotification()
            }
        }
        
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        Log.d(TAG, "服务销毁")
        unregisterSmsReceiver()
        super.onDestroy()
    }
    
    /**
     * 创建通知渠道
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "码钉服务",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "后台监听短信服务"
                setShowBadge(false)
            }
            
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
    
    /**
     * 创建服务通知
     */
    private fun createServiceNotification(): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("码钉")
            .setContentText(currentCode?.let { "取件码: $it" } ?: "正在监听短信...")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
    
    /**
     * 更新服务通知
     */
    private fun updateServiceNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, createServiceNotification())
    }
    
    /**
     * 显示取件码通知
     */
    private fun showCodeNotification(code: String, body: String) {
        val source = extractSource(body)
        
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, code.hashCode(), intent,
            PendingIntent.FLAG_IMMUTABLE
        )
        
        val notification = NotificationCompat.Builder(this, "pincode_channel")
            .setContentTitle("$source 📦")
            .setContentText("取件码: $code")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setAutoCancel(false)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText("取件码: $code\n来源: $source\n\n${body.take(100)}")
            )
            .build()
        
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(code.hashCode(), notification)
        
        // 更新服务通知
        currentCode = code
        currentSource = source
        updateServiceNotification()
    }
    
    /**
     * 注册短信接收器
     */
    private fun registerSmsReceiver() {
        smsReceiver = object : android.content.BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
                
                val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                for (sms in messages) {
                    val body = sms.messageBody ?: continue
                    
                    for (pattern in CODE_PATTERNS) {
                        val match = pattern.find(body)
                        if (match != null) {
                            val code = match.groupValues[1]
                            Log.d(TAG, "识别到取件码: $code")
                            showCodeNotification(code, body)
                            break
                        }
                    }
                }
            }
        }
        
        val filter = IntentFilter(Telephony.Sms.Intents.SMS_RECEIVED_ACTION)
        filter.priority = 999
        registerReceiver(smsReceiver, filter)
    }
    
    /**
     * 注销短信接收器
     */
    private fun unregisterSmsReceiver() {
        smsReceiver?.let {
            unregisterReceiver(it)
            smsReceiver = null
        }
    }
    
    /**
     * 提取来源
     */
    private fun extractSource(body: String): String {
        for ((name, keywords) in SOURCE_KEYWORDS) {
            for (keyword in keywords) {
                if (body.contains(keyword)) {
                    return name
                }
            }
        }
        return "快递通知"
    }
}
