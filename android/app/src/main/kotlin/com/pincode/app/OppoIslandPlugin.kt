package com.pincode.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall

/**
 * 灵动岛插件 - 基于 Android 16 Live Updates API
 * 
 * Android 16 引入了 Notification.ProgressStyle API，用于创建以进度为中心的通知。
 * OPPO ColorOS 16 完整兼容 Android 16 的 Live Updates API，
 * 只需使用标准的 ProgressStyle API 即可自动适配 OPPO 流体云！
 * 
 * 参考：
 * - https://developer.android.com/about/versions/16/features/progress-centric-notifications
 * - https://developer.android.com/reference/android/app/Notification.ProgressStyle
 */
class OppoIslandPlugin(private val context: Context) : MethodChannel.MethodCallHandler {
    
    companion object {
        private const val CHANNEL_NAME = "com.pincode.app/oppo_island"
        private const val NOTIFICATION_CHANNEL_ID = "pincode_channel_v2"
        
        // 日志缓存（最多保留 200 条）
        private val logBuffer = mutableListOf<String>()
        private const val MAX_LOG_SIZE = 200
        
        // 已创建的通知 ID 集合（用于高效取消）
        private val activeNotificationIds = mutableSetOf<Int>()
        
        fun register(flutterEngine: FlutterEngine, context: Context) {
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            channel.setMethodCallHandler(OppoIslandPlugin(context))
        }
        
        private fun addLog(message: String) {
            val timestamp = java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault())
                .format(java.util.Date())
            val logEntry = "[$timestamp] $message"
            
            synchronized(logBuffer) {
                if (logBuffer.size >= MAX_LOG_SIZE) logBuffer.removeAt(0)
                logBuffer.add(logEntry)
            }
            
            android.util.Log.d("OppoIslandPlugin", message)
        }
        
        private fun getLogs(): List<String> = synchronized(logBuffer) { logBuffer.toList() }
        
        private fun clearLogs() = synchronized(logBuffer) { logBuffer.clear() }
    }
    
    private val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    
    init {
        createNotificationChannel()
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val existingChannel = notificationManager.getNotificationChannel(NOTIFICATION_CHANNEL_ID)
            if (existingChannel != null) return
            
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "常驻通知",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "显示取件码、取餐码等常驻信息"
                setShowBadge(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            
            notificationManager.createNotificationChannel(channel)
            addLog("通知渠道创建成功: $NOTIFICATION_CHANNEL_ID")
        }
    }
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> result.success(checkIslandSupport())
            "getDeviceInfo" -> result.success(getDeviceInfo())
            "showCode" -> {
                val id = call.argument<String>("id") ?: ""
                val title = call.argument<String>("title") ?: "取件码"
                val code = call.argument<String>("code") ?: ""
                val type = call.argument<String>("type") ?: "express"
                val location = call.argument<String>("location") ?: ""
                result.success(showLiveUpdateNotification(id, title, code, type, location))
            }
            "updateCode" -> {
                val id = call.argument<String>("id") ?: ""
                val title = call.argument<String>("title") ?: "取件码"
                val code = call.argument<String>("code") ?: ""
                val type = call.argument<String>("type") ?: "express"
                val location = call.argument<String>("location") ?: ""
                result.success(showLiveUpdateNotification(id, title, code, type, location))
            }
            "hideCode" -> {
                val id = call.argument<String>("id") ?: ""
                result.success(hideLiveUpdateNotification(id))
            }
            "hideAll" -> result.success(hideAllLiveUpdates())
            "getLogs" -> result.success(getLogs())
            "clearLogs" -> { clearLogs(); result.success(true) }
            else -> result.notImplemented()
        }
    }
    
    private fun checkIslandSupport(): Boolean {
        val sdkInt = Build.VERSION.SDK_INT
        addLog("SDK: $sdkInt, 厂商: ${Build.MANUFACTURER}, 型号: ${Build.MODEL}")
        
        // Android 16 (API 35) 及以上支持 ProgressStyle
        val progressStyleAvailable = sdkInt >= 35
        addLog("ProgressStyle API 可用: $progressStyleAvailable")
        
        return progressStyleAvailable
    }
    
    private fun getDeviceInfo(): Map<String, Any?> {
        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "brand" to Build.BRAND,
            "androidVersion" to Build.VERSION.SDK_INT,
            "supportsProgressStyle" to (Build.VERSION.SDK_INT >= 35)
        )
    }
    
    private fun showLiveUpdateNotification(id: String, title: String, code: String, type: String, location: String = ""): Boolean {
        return try {
            val notificationId = 10000 + (id.hashCode() and 0xFFFF)
            
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pendingIntent = PendingIntent.getActivity(
                context, notificationId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val accentColor = getTypeColor(type)
            
            val notification = if (Build.VERSION.SDK_INT >= 35) {
                buildProgressStyleNotification(title, code, location, accentColor, pendingIntent)
            } else {
                buildFallbackNotification(title, code, location, accentColor, pendingIntent)
            }
            
            notificationManager.notify(notificationId, notification)
            
            // 记录已创建的通知 ID
            synchronized(activeNotificationIds) { activeNotificationIds.add(notificationId) }
            
            addLog("通知显示成功: $code, ID: $notificationId")
            true
        } catch (e: Exception) {
            addLog("通知显示失败: ${e.message}")
            false
        }
    }
    
    private fun getTypeColor(type: String): Int = when (type) {
        "express" -> Color.parseColor("#FF9800")
        "food" -> Color.parseColor("#4CAF50")
        "travel" -> Color.parseColor("#2196F3")
        else -> Color.parseColor("#9C27B0")
    }
    
    @Suppress("NewApi")
    private fun buildProgressStyleNotification(
        title: String, code: String, location: String, accentColor: Int, pendingIntent: PendingIntent
    ): Notification {
        val (emoji, locationName) = parseTitle(title)
        
        val progressPoints = listOf(
            Notification.ProgressStyle.Point(0).setColor(Color.parseColor("#4CAF50")),
            Notification.ProgressStyle.Point(100).setColor(Color.parseColor("#9E9E9E"))
        )
        
        val progressSegments = listOf(
            Notification.ProgressStyle.Segment(100).setColor(accentColor)
        )
        
        // 构建头部图标
        val headerIcon = android.graphics.drawable.Icon.createWithResource(context, R.mipmap.ic_launcher)
        
        val progressStyle = Notification.ProgressStyle()
            .setStyledByProgress(false)
            .setProgress(100)
            .setProgressTrackerIcon(headerIcon)
            .setProgressSegments(progressSegments)
            .setProgressPoints(progressPoints)
            .setHeaderIcon(headerIcon)           // 设置头部图标（关键！）
            .setHeaderText(locationName.ifEmpty { location })  // 设置头部文本（关键！）
        
        // 构建通知
        val builder = Notification.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(locationName.ifEmpty { location })
            .setContentText(code)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setCategory(Notification.CATEGORY_STATUS)
            .setColor(accentColor)
            .setStyle(progressStyle)
        
        // Android 16 QPR1 (API 36+) 支持 requestPromotedOngoing
        // 这是让通知成为 Live Update 的关键 API！
        if (Build.VERSION.SDK_INT >= 36) {
            builder.requestPromotedOngoing(true)
            addLog("已启用 Live Updates (requestPromotedOngoing)")
        }
        
        return builder.build()
    }
    
    private fun parseTitle(title: String): Pair<String, String> {
        val spaceIndex = title.indexOf(' ')
        return if (spaceIndex > 0) {
            title.substring(0, spaceIndex).trim() to title.substring(spaceIndex + 1).trim()
        } else {
            "" to title
        }
    }
    
    private fun buildFallbackNotification(
        title: String, code: String, location: String, accentColor: Int, pendingIntent: PendingIntent
    ): Notification {
        val (emoji, locationName) = parseTitle(title)
        
        return NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(locationName.ifEmpty { location })
            .setContentText(code)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setColor(accentColor)
            .setStyle(NotificationCompat.BigTextStyle().bigText(code))
            .build()
    }
    
    private fun hideLiveUpdateNotification(id: String): Boolean {
        return try {
            val notificationId = 10000 + (id.hashCode() and 0xFFFF)
            notificationManager.cancel(notificationId)
            
            synchronized(activeNotificationIds) { activeNotificationIds.remove(notificationId) }
            
            addLog("通知隐藏成功: $notificationId")
            true
        } catch (e: Exception) {
            addLog("通知隐藏失败: ${e.message}")
            false
        }
    }
    
    /**
     * 隐藏所有通知（只取消已创建的通知，不再遍历 10001 个 ID）
     */
    private fun hideAllLiveUpdates(): Boolean {
        return try {
            synchronized(activeNotificationIds) {
                for (id in activeNotificationIds) {
                    notificationManager.cancel(id)
                }
                activeNotificationIds.clear()
            }
            addLog("所有通知已隐藏")
            true
        } catch (e: Exception) {
            addLog("隐藏所有通知失败: ${e.message}")
            false
        }
    }
}
