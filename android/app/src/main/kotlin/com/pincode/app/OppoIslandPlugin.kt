package com.pincode.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.Icon
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
        private const val NOTIFICATION_CHANNEL_ID = "pincode_channel_v2"
        
        // 灵动岛通知的基础 ID
        private const val BASE_NOTIFICATION_ID = 10000
        
        // 日志缓存（最多保留 200 条）
        private val logBuffer = mutableListOf<String>()
        private const val MAX_LOG_SIZE = 200
        
        fun register(flutterEngine: FlutterEngine, context: Context) {
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            channel.setMethodCallHandler(OppoIslandPlugin(context))
        }
        
        private fun addLog(message: String) {
            val timestamp = java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault())
                .format(java.util.Date())
            val logEntry = "[$timestamp] $message"
            
            synchronized(logBuffer) {
                if (logBuffer.size >= MAX_LOG_SIZE) {
                    logBuffer.removeAt(0)
                }
                logBuffer.add(logEntry)
            }
            
            android.util.Log.d("OppoIslandPlugin", message)
        }
        
        private fun getLogs(): List<String> {
            synchronized(logBuffer) {
                return logBuffer.toList()
            }
        }
        
        private fun clearLogs() {
            synchronized(logBuffer) {
                logBuffer.clear()
            }
        }
    }
    
    private val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    
    init {
        createNotificationChannel()
    }
    
    /**
     * 创建通知渠道（Android 8.0+）
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val existingChannel = notificationManager.getNotificationChannel(NOTIFICATION_CHANNEL_ID)
            if (existingChannel != null) {
                addLog("通知渠道已存在: $NOTIFICATION_CHANNEL_ID")
                return
            }
            
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
            addLog("✅ 通知渠道创建成功: $NOTIFICATION_CHANNEL_ID")
        }
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
                addLog("=== showCode 被调用 ===")
                val id = call.argument<String>("id") ?: ""
                val title = call.argument<String>("title") ?: "取件码"
                val code = call.argument<String>("code") ?: ""
                val type = call.argument<String>("type") ?: "express"
                val location = call.argument<String>("location") ?: ""  // 地点信息
                
                val success = showLiveUpdateNotification(id, title, code, type, location)
                result.success(success)
            }
            "updateCode" -> {
                val id = call.argument<String>("id") ?: ""
                val title = call.argument<String>("title") ?: "取件码"
                val code = call.argument<String>("code") ?: ""
                val type = call.argument<String>("type") ?: "express"
                val location = call.argument<String>("location") ?: ""  // 地点信息
                
                val success = showLiveUpdateNotification(id, title, code, type, location)
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
            "getLogs" -> {
                val logs = getLogs()
                result.success(logs)
            }
            "clearLogs" -> {
                clearLogs()
                result.success(true)
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    /**
     * 检查是否支持灵动岛（ProgressStyle API）
     */
    private fun checkIslandSupport(): Boolean {
        val sdkInt = Build.VERSION.SDK_INT
        val manufacturer = Build.MANUFACTURER.lowercase()
        val brand = Build.BRAND.lowercase()
        
        addLog("=== 设备信息 ===")
        addLog("SDK 版本: $sdkInt (${getAndroidVersionName(sdkInt)})")
        addLog("厂商: $manufacturer")
        addLog("品牌: $brand")
        addLog("型号: ${Build.MODEL}")
        
        // 检查是否是 OPPO 系设备
        val isOppoDevice = manufacturer == "oppo" || 
                          manufacturer == "oneplus" || 
                          manufacturer == "realme" ||
                          brand == "oppo" ||
                          brand == "oneplus" ||
                          brand == "realme"
        
        if (isOppoDevice) {
            val colorOsVersion = getSystemProperty("ro.build.version.oplus")
            addLog("ColorOS 版本: $colorOsVersion")
        }
        
        // Android 16 (API 35) 及以上支持 ProgressStyle
        val progressStyleAvailable = sdkInt >= 35
        addLog("ProgressStyle API 可用: $progressStyleAvailable")
        
        return progressStyleAvailable
    }
    
    /**
     * 获取 Android 版本名称
     */
    private fun getAndroidVersionName(sdkInt: Int): String {
        return when (sdkInt) {
            35 -> "16 (BAKLAVA)"
            34 -> "14 (UPSIDE_DOWN_CAKE)"
            33 -> "13 (TIRAMISU)"
            32 -> "12L (S_V2)"
            31 -> "12 (S)"
            30 -> "11 (R)"
            29 -> "10 (Q)"
            28 -> "9 (P)"
            else -> "API $sdkInt"
        }
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
            "androidVersionName" to getAndroidVersionName(Build.VERSION.SDK_INT),
            "supportsProgressStyle" to (Build.VERSION.SDK_INT >= 35)
        )
    }
    
    /**
     * 显示实时活动通知
     */
    private fun showLiveUpdateNotification(id: String, title: String, code: String, type: String, location: String = ""): Boolean {
        addLog("=== 显示通知 ===")
        addLog("ID: $id, 标题: $title, 取件码: $code, 类型: $type, 地点: $location")
        
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
            
            // 根据类型选择颜色
            val accentColor = getTypeColor(type)
            
            // 构建通知
            val notification = if (Build.VERSION.SDK_INT >= 35) {
                // Android 16+: 使用 ProgressStyle API
                buildProgressStyleNotification(title, code, location, accentColor, pendingIntent)
            } else {
                // Android 16 以下: 使用普通高优先级通知
                buildFallbackNotification(title, code, location, accentColor, pendingIntent)
            }
            
            notificationManager.notify(notificationId, notification)
            addLog("✅ 通知显示成功，ID: $notificationId")
            true
        } catch (e: Exception) {
            addLog("❌ 显示通知失败: ${e.message}")
            e.printStackTrace()
            false
        }
    }
    
    /**
     * 获取类型对应的颜色
     */
    private fun getTypeColor(type: String): Int {
        return when (type) {
            "express" -> Color.parseColor("#FF9800")  // 橙色 - 快递
            "food" -> Color.parseColor("#4CAF50")     // 绿色 - 外卖
            "travel" -> Color.parseColor("#2196F3")   // 蓝色 - 出行
            else -> Color.parseColor("#9C27B0")       // 紫色 - 其他
        }
    }
    
    /**
     * 构建 ProgressStyle 通知（Android 16+）
     * 
     * 使用官方 API，无需反射
     * 
     * 注意：ProgressStyle 在 Android 16 (API 35) 引入，
     * 但部分设备可能需要更高版本才能完全支持
     */
    private fun buildProgressStyleNotification(
        title: String,
        code: String,
        location: String,
        accentColor: Int,
        pendingIntent: PendingIntent
    ): Notification {
        addLog("✅ 使用 ProgressStyle API 构建")
        
        // 创建 ProgressStyle
        // 使用 @Suppress 消除新 API 警告
        @Suppress("NewApi")
        val progressStyle = Notification.ProgressStyle()
            .setStyledByProgress(false)  // 不自动根据进度设置样式
            .setProgress(100)  // 总进度
            .setProgressSegments(
                listOf(
                    // 单个 Segment 表示完整进度，使用类型颜色
                    Notification.ProgressStyle.Segment(100).setColor(accentColor)
                )
            )
        
        // 解析标题：提取 emoji 和地点名称
        // 标题格式通常是 "📦 水岸明珠世纪华联"
        val (emoji, locationName) = parseTitle(title)
        
        // 构建通知
        // - subText: 显示地点（如果有）
        // - contentTitle: 显示取件码
        // - contentText: 显示来源/备注
        return Notification.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(getTypeIcon(emoji))  // 根据类型设置图标
            .setContentTitle(code)  // 标题显示取件码
            .setContentText(if (location.isNotEmpty()) location else locationName)  // 内容显示地点
            .setSubText(locationName.ifEmpty { null })  // 副标题显示地点名称
            .setContentIntent(pendingIntent)
            .setOngoing(true)  // 常驻通知
            .setAutoCancel(false)
            .setVisibility(Notification.VISIBILITY_PUBLIC)  // 锁屏可见
            .setCategory(Notification.CATEGORY_STATUS)
            .setColor(accentColor)  // 通知背景色
            .setStyle(progressStyle)  // 应用 ProgressStyle
            .build()
    }
    
    /**
     * 解析标题，提取 emoji 和地点名称
     * 
     * @param title 标题，格式通常是 "📦 水岸明珠世纪华联"
     * @return Pair(emoji, locationName)
     */
    private fun parseTitle(title: String): Pair<String, String> {
        // 查找第一个空格的位置
        val spaceIndex = title.indexOf(' ')
        return if (spaceIndex > 0) {
            val emoji = title.substring(0, spaceIndex).trim()
            val locationName = title.substring(spaceIndex + 1).trim()
            Pair(emoji, locationName)
        } else {
            Pair("", title)
        }
    }
    
    /**
     * 根据类型 emoji 获取对应的图标资源 ID
     */
    private fun getTypeIcon(emoji: String): Int {
        return when (emoji) {
            "📦" -> android.R.drawable.ic_menu_upload  // 快递 - 上传图标（盒子形状）
            "🍔" -> android.R.drawable.ic_menu_delete  // 外卖 - 删除图标（餐盘形状）
            "🚗" -> android.R.drawable.ic_menu_send    // 出行 - 发送图标（车辆形状）
            else -> android.R.drawable.ic_menu_info_details  // 默认 - 信息图标
        }
    }
    
    /**
     * 构建降级通知（Android 16 以下）
     */
    private fun buildFallbackNotification(
        title: String,
        code: String,
        location: String,
        accentColor: Int,
        pendingIntent: PendingIntent
    ): Notification {
        addLog("⚠️ 使用降级通知样式（Android 16 以下）")
        
        // 解析标题：提取 emoji 和地点名称
        val (emoji, locationName) = parseTitle(title)
        
        return NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(getTypeIcon(emoji))
            .setContentTitle(code)  // 标题显示取件码
            .setContentText(if (location.isNotEmpty()) location else locationName)  // 内容显示地点
            .setSubText(locationName.ifEmpty { null })  // 副标题显示地点名称
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
    
    /**
     * 隐藏实时活动通知
     */
    private fun hideLiveUpdateNotification(id: String): Boolean {
        return try {
            val notificationId = BASE_NOTIFICATION_ID + id.hashCode()
            notificationManager.cancel(notificationId)
            addLog("✅ 隐藏通知成功，ID: $notificationId")
            true
        } catch (e: Exception) {
            addLog("❌ 隐藏通知失败: ${e.message}")
            false
        }
    }
    
    /**
     * 隐藏所有实时活动通知
     */
    private fun hideAllLiveUpdates(): Boolean {
        return try {
            // 取消所有灵动岛通知（ID 范围 10000-20000）
            for (i in 10000..20000) {
                notificationManager.cancel(i)
            }
            addLog("✅ 隐藏所有通知成功")
            true
        } catch (e: Exception) {
            addLog("❌ 隐藏所有通知失败: ${e.message}")
            false
        }
    }
}
