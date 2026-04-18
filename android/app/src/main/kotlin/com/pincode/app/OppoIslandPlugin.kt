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
 * 灵动岛插件 - 基于 Android 16 ProgressStyle API
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
        private const val NOTIFICATION_CHANNEL_ID = "live_update_channel"
        private const val NOTIFICATION_CHANNEL_NAME = "取件码灵动岛"
        
        // 灵动岛通知的基础 ID
        private const val BASE_NOTIFICATION_ID = 10000
        
        // Android 16 (API 35)
        private const val ANDROID_16 = 35
        
        fun register(flutterEngine: FlutterEngine, context: Context) {
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            channel.setMethodCallHandler(OppoIslandPlugin(context))
        }
    }
    
    private val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    
    init {
        createNotificationChannel()
    }
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> {
                val isSupported = checkIslandSupport()
                result.success(isSupported)
            }
            "getDeviceInfo" -> {
                val info = getDeviceInfo()
                result.success(info)
            }
            "showCode" -> {
                val id = call.argument<String>("id") ?: ""
                val title = call.argument<String>("title") ?: "取件码"
                val code = call.argument<String>("code") ?: ""
                val type = call.argument<String>("type") ?: "express"
                
                val success = showLiveUpdateNotification(id, title, code, type)
                result.success(success)
            }
            "updateCode" -> {
                val id = call.argument<String>("id") ?: ""
                val title = call.argument<String>("title") ?: "取件码"
                val code = call.argument<String>("code") ?: ""
                val type = call.argument<String>("type") ?: "express"
                
                val success = showLiveUpdateNotification(id, title, code, type)
                result.success(success)
            }
            "hideCode" -> {
                val id = call.argument<String>("id") ?: ""
                val success = hideLiveUpdateNotification(id)
                result.success(success)
            }
            "hideAll" -> {
                val success = hideAllLiveUpdates()
                result.success(success)
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    /**
     * 检查是否支持灵动岛
     * 
     * Android 16+ 设备都支持 ProgressStyle API
     * OPPO ColorOS 16 额外会将其渲染为流体云样式
     */
    private fun checkIslandSupport(): Boolean {
        val sdkInt = Build.VERSION.SDK_INT
        val manufacturer = Build.MANUFACTURER.lowercase()
        val brand = Build.BRAND.lowercase()
        
        android.util.Log.d("OppoIslandPlugin", "SDK: $sdkInt, 厂商: $manufacturer, 品牌: $brand")
        
        // Android 16+ 才支持 ProgressStyle API
        if (sdkInt < ANDROID_16) {
            android.util.Log.d("OppoIslandPlugin", "Android 版本低于 16，不支持 ProgressStyle API")
            return false
        }
        
        // 检查是否是 OPPO 系设备（会渲染为流体云样式）
        val isOppoDevice = manufacturer == "oppo" || 
                          manufacturer == "oneplus" || 
                          manufacturer == "realme" ||
                          brand == "oppo" ||
                          brand == "oneplus" ||
                          brand == "realme"
        
        if (isOppoDevice) {
            val colorOsVersion = getSystemProperty("ro.build.version.oplus")
            android.util.Log.d("OppoIslandPlugin", "OPPO 系设备, ColorOS 版本: $colorOsVersion")
        }
        
        // Android 16+ 都支持，只是 OPPO 设备会有更漂亮的流体云样式
        android.util.Log.d("OppoIslandPlugin", "支持 ProgressStyle API, OPPO 设备: $isOppoDevice")
        return true
    }
    
    /**
     * 获取系统属性
     */
    private fun getSystemProperty(key: String): String {
        return try {
            val process = Runtime.getRuntime().exec("getprop $key")
            process.inputStream.bufferedReader().readText().trim()
        } catch (e: Exception) {
            ""
        }
    }
    
    /**
     * 获取设备信息
     */
    private fun getDeviceInfo(): Map<String, Any?> {
        val colorOsVersion = getSystemProperty("ro.build.version.oplus")
        val oxygenOsVersion = getSystemProperty("ro.build.version.oxygen")
        
        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "brand" to Build.BRAND,
            "colorOsVersion" to colorOsVersion,
            "oxygenOsVersion" to oxygenOsVersion,
            "androidVersion" to Build.VERSION.SDK_INT,
            "supportsProgressStyle" to (Build.VERSION.SDK_INT >= ANDROID_16)
        )
    }
    
    /**
     * 创建通知渠道
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                NOTIFICATION_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "显示取件码的实时活动通知"
                enableLights(true)
                enableVibration(false)
                setShowBadge(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    /**
     * 显示实时活动通知（使用 Android 16 ProgressStyle API）
     */
    private fun showLiveUpdateNotification(id: String, title: String, code: String, type: String): Boolean {
        return try {
            val notificationId = BASE_NOTIFICATION_ID + id.hashCode()
            
            // 创建点击 Intent
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pendingIntent = PendingIntent.getActivity(
                context,
                notificationId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val notification = if (Build.VERSION.SDK_INT >= ANDROID_16) {
                // Android 16+: 使用 ProgressStyle API
                buildProgressStyleNotification(title, code, type, pendingIntent)
            } else {
                // 降级：使用普通高优先级通知
                buildLegacyNotification(title, code, pendingIntent)
            }
            
            notificationManager.notify(notificationId, notification)
            android.util.Log.d("OppoIslandPlugin", "显示实时活动通知成功: $title - $code")
            true
        } catch (e: Exception) {
            android.util.Log.e("OppoIslandPlugin", "显示实时活动通知失败", e)
            false
        }
    }
    
    /**
     * 构建 Android 16 ProgressStyle 通知
     * 
     * ProgressStyle 是 Android 16 新增的 API，用于创建以进度为中心的通知。
     * OPPO ColorOS 16 会自动将其渲染为流体云样式！
     */
    private fun buildProgressStyleNotification(
        title: String, 
        code: String, 
        type: String,
        pendingIntent: PendingIntent
    ): Notification {
        val builder = Notification.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(code)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setCategory(Notification.CATEGORY_STATUS)
        
        // 使用 ProgressStyle
        // 注意：ProgressStyle 在 Android 16 (API 35) 才可用
        // 这里使用反射来调用，因为编译时可能还没有 API 35
        try {
            val progressStyleClass = Class.forName("android.app.Notification\$ProgressStyle")
            val progressStyleBuilder = progressStyleClass.getDeclaredConstructor().newInstance()
            
            // 设置进度样式
            val setStyledByProgress = progressStyleClass.getMethod("setStyledByProgress", Boolean::class.java)
            setStyledByProgress.invoke(progressStyleBuilder, false)
            
            // 设置进度（这里用 100 表示完成状态）
            val setProgress = progressStyleClass.getMethod("setProgress", Int::class.java)
            setProgress.invoke(progressStyleBuilder, 100)
            
            // 将 ProgressStyle 应用到通知
            val setStyle = Notification.Builder::class.java.getMethod("setStyle", Notification.Style::class.java)
            setStyle.invoke(builder, progressStyleBuilder)
            
            android.util.Log.d("OppoIslandPlugin", "使用 ProgressStyle API 成功")
        } catch (e: Exception) {
            // 如果反射失败，使用普通样式
            android.util.Log.w("OppoIslandPlugin", "ProgressStyle API 不可用，使用普通样式: ${e.message}")
            builder.setStyle(Notification.BigTextStyle().bigText(code))
        }
        
        return builder.build()
    }
    
    /**
     * 构建传统通知（Android 16 以下）
     */
    private fun buildLegacyNotification(
        title: String, 
        code: String,
        pendingIntent: PendingIntent
    ): Notification {
        return NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(code)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setStyle(NotificationCompat.BigTextStyle().bigText(code))
            .build()
    }
    
    /**
     * 隐藏实时活动通知
     */
    private fun hideLiveUpdateNotification(id: String): Boolean {
        return try {
            val notificationId = BASE_NOTIFICATION_ID + id.hashCode()
            notificationManager.cancel(notificationId)
            android.util.Log.d("OppoIslandPlugin", "隐藏实时活动通知成功")
            true
        } catch (e: Exception) {
            android.util.Log.e("OppoIslandPlugin", "隐藏实时活动通知失败", e)
            false
        }
    }
    
    /**
     * 隐藏所有实时活动通知
     */
    private fun hideAllLiveUpdates(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                notificationManager.deleteNotificationChannel(NOTIFICATION_CHANNEL_ID)
                createNotificationChannel()
            }
            android.util.Log.d("OppoIslandPlugin", "隐藏所有实时活动通知成功")
            true
        } catch (e: Exception) {
            android.util.Log.e("OppoIslandPlugin", "隐藏所有实时活动通知失败", e)
            false
        }
    }
}
