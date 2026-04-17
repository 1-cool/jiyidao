package com.pincode.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall

/**
 * OPPO 灵动岛插件
 * 
 * 通过 OPPO Push SDK 的实时活动通知 API 实现
 * 文档：https://open.oppomobile.com/documentation/page/info?id=12658
 * 
 * 注意：OPPO 的实时活动通知需要：
 * 1. ColorOS 14+ 系统
 * 2. 申请 OPPO 开发者账号
 * 3. 集成 OPPO Push SDK
 * 
 * 当前实现为模拟版本，使用自定义通知样式模拟灵动岛效果
 * 完整实现需要接入 OPPO Push SDK
 */
class OppoIslandPlugin(private val context: Context) : MethodChannel.MethodCallHandler {
    
    companion object {
        private const val CHANNEL_NAME = "com.pincode.app/oppo_island"
        private const val NOTIFICATION_CHANNEL_ID = "oppo_island_channel"
        private const val NOTIFICATION_CHANNEL_NAME = "灵动岛"
        
        // OPPO 灵动岛通知的基础 ID
        private const val BASE_NOTIFICATION_ID = 10000
        
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
                // 检查是否支持 OPPO 灵动岛
                val isSupported = checkIslandSupport()
                result.success(isSupported)
            }
            "getDeviceInfo" -> {
                // 返回设备信息
                val info = getDeviceInfo()
                result.success(info)
            }
            "showCode" -> {
                val id = call.argument<String>("id") ?: ""
                val title = call.argument<String>("title") ?: "取件码"
                val code = call.argument<String>("code") ?: ""
                val type = call.argument<String>("type") ?: "express"
                
                val success = showIslandNotification(id, title, code, type)
                result.success(success)
            }
            "updateCode" -> {
                val id = call.argument<String>("id") ?: ""
                val title = call.argument<String>("title") ?: "取件码"
                val code = call.argument<String>("code") ?: ""
                val type = call.argument<String>("type") ?: "express"
                
                val success = showIslandNotification(id, title, code, type)
                result.success(success)
            }
            "hideCode" -> {
                val id = call.argument<String>("id") ?: ""
                val success = hideIslandNotification(id)
                result.success(success)
            }
            "hideAll" -> {
                val success = hideAllIslands()
                result.success(success)
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    /**
     * 检查是否支持 OPPO 灵动岛
     */
    private fun checkIslandSupport(): Boolean {
        // 检查是否是 OPPO 系设备（OPPO、OnePlus、realme 都使用 ColorOS）
        val manufacturer = Build.MANUFACTURER.lowercase()
        val isOppo = manufacturer == "oppo" || manufacturer == "oneplus" || manufacturer == "realme"
        
        if (!isOppo) {
            return false
        }
        
        // 检查 ColorOS 版本（需要 ColorOS 14+）
        try {
            val version = getSystemProperty("ro.build.version.oplus")
            if (version.isNotEmpty()) {
                // 解析版本号，ColorOS 14 对应版本号 14.x
                val majorVersion = version.split(".").firstOrNull()?.toIntOrNull() ?: 0
                return majorVersion >= 14
            }
        } catch (e: Exception) {
            // 忽略解析错误
        }
        
        // 如果无法确定版本，假设支持（降级到普通通知）
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
        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "brand" to Build.BRAND,
            "colorOsVersion" to getSystemProperty("ro.build.version.oplus"),
            "androidVersion" to Build.VERSION.SDK_INT
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
                description = "显示取件码的灵动岛通知"
                enableLights(true)
                enableVibration(false)
                setShowBadge(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    /**
     * 显示灵动岛通知
     */
    private fun showIslandNotification(id: String, title: String, code: String, type: String): Boolean {
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
            
            // 构建通知
            val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle(title)
                .setContentText(code)
                .setContentIntent(pendingIntent)
                .setOngoing(true) // 常驻通知
                .setAutoCancel(false)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setCategory(NotificationCompat.CATEGORY_STATUS)
                .setStyle(NotificationCompat.BigTextStyle()
                    .bigText(code)
                    .setBigContentTitle(title))
                .build()
            
            notificationManager.notify(notificationId, notification)
            true
        } catch (e: Exception) {
            android.util.Log.e("OppoIslandPlugin", "显示灵动岛通知失败", e)
            false
        }
    }
    
    /**
     * 隐藏灵动岛通知
     */
    private fun hideIslandNotification(id: String): Boolean {
        return try {
            val notificationId = BASE_NOTIFICATION_ID + id.hashCode()
            notificationManager.cancel(notificationId)
            true
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * 隐藏所有灵动岛通知
     */
    private fun hideAllIslands(): Boolean {
        return try {
            // 只取消灵动岛渠道的通知，不影响其他通知
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                notificationManager.deleteNotificationChannel(NOTIFICATION_CHANNEL_ID)
                createNotificationChannel() // 重新创建渠道
            }
            true
        } catch (e: Exception) {
            false
        }
    }
}
