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
        // 使用 Flutter 端的通知渠道，不再创建独立渠道
        private const val NOTIFICATION_CHANNEL_ID = "pincode_channel_v2"
        
        // 灵动岛通知的基础 ID
        private const val BASE_NOTIFICATION_ID = 10000
        
        // Android 16 (API 35)
        private const val ANDROID_16 = 35
        
        // 日志缓存（最多保留 200 条）
        private val logBuffer = mutableListOf<String>()
        private const val MAX_LOG_SIZE = 200
        
        fun register(flutterEngine: FlutterEngine, context: Context) {
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            channel.setMethodCallHandler(OppoIslandPlugin(context))
        }
        
        // 添加日志到缓存
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
            
            // 同时输出到 logcat
            android.util.Log.d("OppoIslandPlugin", message)
        }
        
        // 获取所有日志
        private fun getLogs(): List<String> {
            synchronized(logBuffer) {
                return logBuffer.toList()
            }
        }
        
        // 清空日志
        private fun clearLogs() {
            synchronized(logBuffer) {
                logBuffer.clear()
            }
        }
    }
    
    private val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    
    init {
        // 确保通知渠道存在（Flutter 端可能还没初始化完成）
        createNotificationChannel()
    }
    
    /**
     * 创建通知渠道（Android 8.0+）
     * 
     * 注意：即使 Flutter 端也会创建，这里也要创建以确保原生端能正常显示通知
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // 检查渠道是否已存在
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
     * 检查是否支持灵动岛
     */
    private fun checkIslandSupport(): Boolean {
        val sdkInt = Build.VERSION.SDK_INT
        val manufacturer = Build.MANUFACTURER.lowercase()
        val brand = Build.BRAND.lowercase()
        
        addLog("=== 设备信息 ===")
        addLog("SDK 版本: $sdkInt")
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
        
        // 检查 ProgressStyle API 是否可用
        val progressStyleAvailable = checkProgressStyleAvailable()
        addLog("ProgressStyle API 可用: $progressStyleAvailable")
        
        return progressStyleAvailable
    }
    
    /**
     * 检查 ProgressStyle API 是否可用
     */
    private fun checkProgressStyleAvailable(): Boolean {
        return try {
            // 尝试加载 ProgressStyle 类
            val progressStyleClass = Class.forName("android.app.Notification\$ProgressStyle")
            addLog("✅ ProgressStyle 类加载成功")
            true
        } catch (e: ClassNotFoundException) {
            addLog("❌ ProgressStyle 类不存在: ${e.message}")
            false
        } catch (e: Exception) {
            addLog("❌ ProgressStyle 检查失败: ${e.message}")
            false
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
        val progressStyleAvailable = checkProgressStyleAvailable()
        
        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "brand" to Build.BRAND,
            "colorOsVersion" to colorOsVersion,
            "oxygenOsVersion" to oxygenOsVersion,
            "androidVersion" to Build.VERSION.SDK_INT,
            "supportsProgressStyle" to progressStyleAvailable
        )
    }
    
    /**
     * 显示实时活动通知
     */
    private fun showLiveUpdateNotification(id: String, title: String, code: String, type: String): Boolean {
        addLog("=== 显示通知 ===")
        addLog("ID: $id, 标题: $title, 取件码: $code, 类型: $type")
        
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
            
            // 尝试使用 ProgressStyle API
            val notification = tryBuildProgressStyleNotification(title, code, pendingIntent)
                ?: buildFallbackNotification(title, code, pendingIntent)
            
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
     * 尝试构建 ProgressStyle 通知
     * 
     * @return 成功返回 Notification，失败返回 null
     */
    private fun tryBuildProgressStyleNotification(
        title: String, 
        code: String,
        pendingIntent: PendingIntent
    ): Notification? {
        return try {
            addLog("尝试使用 ProgressStyle API...")
            
            // 加载 ProgressStyle 类
            val progressStyleClass = Class.forName("android.app.Notification\$ProgressStyle")
            val segmentClass = Class.forName("android.app.Notification\$ProgressStyle\$Segment")
            val pointClass = Class.forName("android.app.Notification\$ProgressStyle\$Point")
            
            addLog("✅ ProgressStyle 类加载成功")
            
            // 创建 ProgressStyle 实例
            val progressStyle = progressStyleClass.getDeclaredConstructor().newInstance()
            
            // setStyledByProgress(false)
            val setStyledByProgress = progressStyleClass.getMethod("setStyledByProgress", Boolean::class.javaPrimitiveType)
            setStyledByProgress.invoke(progressStyle, false)
            
            // setProgress(100)
            val setProgress = progressStyleClass.getMethod("setProgress", Int::class.javaPrimitiveType)
            setProgress.invoke(progressStyle, 100)
            
            // 创建一个 Segment（表示进度）
            val segment = segmentClass.getDeclaredConstructor(Int::class.javaPrimitiveType).newInstance(100)
            val setColor = segmentClass.getMethod("setColor", Int::class.javaPrimitiveType)
            setColor.invoke(segment, Color.parseColor("#4CAF50")) // 绿色
            
            // setProgressSegments
            val setProgressSegments = progressStyleClass.getMethod("setProgressSegments", List::class.java)
            setProgressSegments.invoke(progressStyle, listOf(segment))
            
            addLog("✅ ProgressStyle 配置成功")
            
            // 构建通知
            val builder = Notification.Builder(context, NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle(title)
                .setContentText(code)
                .setSubText("取件码")  // 副标题
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .setAutoCancel(false)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setCategory(Notification.CATEGORY_STATUS)
            
            // 应用 ProgressStyle
            val setStyle = Notification.Builder::class.java.getMethod("setStyle", Notification.Style::class.java)
            setStyle.invoke(builder, progressStyle)
            
            addLog("✅ ProgressStyle 通知构建成功")
            builder.build()
        } catch (e: ClassNotFoundException) {
            addLog("❌ ProgressStyle 类不存在: ${e.message}")
            null
        } catch (e: NoSuchMethodException) {
            addLog("❌ ProgressStyle 方法不存在: ${e.message}")
            null
        } catch (e: Exception) {
            addLog("❌ ProgressStyle 构建失败: ${e.javaClass.simpleName} - ${e.message}")
            e.printStackTrace()
            null
        }
    }
    
    /**
     * 构建降级通知（普通高优先级通知）
     */
    private fun buildFallbackNotification(
        title: String, 
        code: String,
        pendingIntent: PendingIntent
    ): Notification {
        addLog("⚠️ 使用降级通知样式（ProgressStyle 不可用）")
        
        return NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(code)
            .setSubText("取件码")
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
