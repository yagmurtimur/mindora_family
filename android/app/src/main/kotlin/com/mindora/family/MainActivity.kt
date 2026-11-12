package com.mindora.family

import android.app.admin.DevicePolicyManager
import android.app.usage.UsageStatsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {

    private val CHANNEL = "mindora/usage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                // ========================================
                // GÜNLÜK KULLANIM
                // ========================================

                "getTodayUsage" -> {
                    try {
                        val usageData = getTodayUsage()
                        result.success(usageData)
                    } catch (e: Exception) {
                        result.error(
                            "USAGE_ERROR",
                            e.message,
                            null
                        )
                    }
                }

                // ========================================
                // KULLANIM ERİŞİMİ KONTROLÜ
                // ========================================

                "hasUsageAccess" -> {
                    result.success(hasUsageAccess())
                }

                // ========================================
                // YÜKLÜ UYGULAMALARI GETİR
                // ========================================

                "getInstalledApps" -> {
                    try {
                        val apps = getInstalledApps()
                        result.success(apps)
                    } catch (e: Exception) {
                        result.error(
                            "APPS_ERROR",
                            e.message,
                            null
                        )
                    }
                }

                // ========================================
                // DEVICE ADMIN AKTİF Mİ?
                // ========================================

                "isDeviceAdminActive" -> {

                    val devicePolicyManager =
                        getSystemService(
                            Context.DEVICE_POLICY_SERVICE
                        ) as DevicePolicyManager

                    val adminComponent =
                        ComponentName(
                            this,
                            MindoraDeviceAdminReceiver::class.java
                        )

                    result.success(
                        devicePolicyManager.isAdminActive(
                            adminComponent
                        )
                    )
                }

                // ========================================
                // DEVICE ADMIN AKTİFLEŞTİR
                // ========================================

                "requestDeviceAdmin" -> {

                    try {

                        val devicePolicyManager =
                            getSystemService(
                                Context.DEVICE_POLICY_SERVICE
                            ) as DevicePolicyManager

                        val adminComponent =
                            ComponentName(
                                this,
                                MindoraDeviceAdminReceiver::class.java
                            )

                        if (
                            devicePolicyManager.isAdminActive(
                                adminComponent
                            )
                        ) {

                            result.success(true)

                        } else {

                            val intent =
                                Intent(
                                    DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN
                                ).apply {

                                    putExtra(
                                        DevicePolicyManager.EXTRA_DEVICE_ADMIN,
                                        adminComponent
                                    )

                                    putExtra(
                                        DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                                        "Mindora, ebeveyn tarafından belirlenen uygulama kısıtlamalarını uygulamak için cihaz yöneticisi yetkisine ihtiyaç duyar."
                                    )
                                }

                            startActivity(intent)

                            result.success(false)
                        }

                    } catch (e: Exception) {

                        result.error(
                            "DEVICE_ADMIN_ERROR",
                            e.message,
                            null
                        )
                    }
                }

                // ========================================
                // KULLANIM AYARLARINI AÇ
                // ========================================

                "openUsageSettings" -> {

                    try {

                        val intent =
                            Intent(
                                Settings.ACTION_USAGE_ACCESS_SETTINGS
                            )

                        startActivity(intent)

                        result.success(true)

                    } catch (e: Exception) {

                        result.error(
                            "SETTINGS_ERROR",
                            e.message,
                            null
                        )
                    }
                }

                // ========================================
                // UYGULAMA ENGELLE / ENGELİ KALDIR
                // ========================================

                "setAppBlocked" -> {

                    val packageName =
                        call.argument<String>("packageName")

                    val blocked =
                        call.argument<Boolean>("blocked")

                    if (
                        packageName == null ||
                        blocked == null
                    ) {

                        result.error(
                            "INVALID_ARGUMENT",
                            "packageName veya blocked eksik.",
                            null
                        )

                        return@setMethodCallHandler
                    }

                    try {

                        val success =
                            setAppBlocked(
                                packageName,
                                blocked
                            )

                        result.success(success)

                    } catch (e: SecurityException) {

                        result.error(
                            "SECURITY_ERROR",
                            "Mindora gerekli cihaz yönetimi yetkisine sahip değil.",
                            null
                        )

                    } catch (e: Exception) {

                        result.error(
                            "BLOCK_ERROR",
                            e.message,
                            null
                        )
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // ========================================
    // KULLANIM ERİŞİMİ
    // ========================================

    private fun hasUsageAccess(): Boolean {

        val usageStatsManager =
            getSystemService(
                Context.USAGE_STATS_SERVICE
            ) as UsageStatsManager

        val endTime =
            System.currentTimeMillis()

        val startTime =
            endTime - 60 * 60 * 1000

        val stats =
            usageStatsManager.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY,
                startTime,
                endTime
            )

        return stats != null &&
                stats.isNotEmpty()
    }

    // ========================================
    // GÜNLÜK KULLANIM VERİSİ
    // ========================================

    private fun getTodayUsage(): Map<String, Any> {

        val usageStatsManager =
            getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

        val stats = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            calendar.timeInMillis,
            System.currentTimeMillis()
        )

        var totalMinutes = 0L
        var socialMediaMinutes = 0L
        var gamingMinutes = 0L
        var videoMinutes = 0L

        // Aynı paket için dönen kayıtları tekilleştir.
        val usageByPackage = stats.orEmpty()
            .groupBy { it.packageName }
            .mapValues { (_, records) ->
                records.maxOfOrNull { it.totalTimeInForeground } ?: 0L
            }

        for ((packageName, foregroundTime) in usageByPackage) {
            val minutes = foregroundTime / 60_000L
            totalMinutes += minutes

            val name = packageName.lowercase()

            if (listOf("instagram", "facebook", "tiktok", "twitter", "snapchat")
                    .any { name.contains(it) }) {
                socialMediaMinutes += minutes
            }

            if (listOf("game", "pubg", "mobilelegends", "roblox")
                    .any { name.contains(it) }) {
                gamingMinutes += minutes
            }

            if (listOf("youtube", "netflix", "twitch")
                    .any { name.contains(it) }) {
                videoMinutes += minutes
            }
        }

        return mapOf(
            "totalMinutes" to totalMinutes,
            "socialMediaMinutes" to socialMediaMinutes,
            "gamingMinutes" to gamingMinutes,
            "videoMinutes" to videoMinutes
        )
    }

    // ========================================
    // UYGULAMA ENGELLEME
    // ========================================

    private fun setAppBlocked(
        packageName: String,
        blocked: Boolean
    ): Boolean {

        val devicePolicyManager =
            getSystemService(
                DevicePolicyManager::class.java
            )

        val adminComponent =
            ComponentName(
                this,
                MindoraDeviceAdminReceiver::class.java
            )

        val failedPackages =
            devicePolicyManager.setPackagesSuspended(
                adminComponent,
                arrayOf(packageName),
                blocked
            )

        return !failedPackages.contains(
            packageName
        )
    }

    // ========================================
    // YÜKLÜ UYGULAMALARI GETİR
    // ========================================

    private fun getInstalledApps():
            List<Map<String, String>> {

        val packageManager =
            packageManager

        val intent =
            Intent(
                Intent.ACTION_MAIN,
                null
            ).apply {

                addCategory(
                    Intent.CATEGORY_LAUNCHER
                )
            }

        val packages =
            packageManager.queryIntentActivities(
                intent,
                0
            )

        return packages
            .map { resolveInfo ->

                val applicationInfo =
                    resolveInfo
                        .activityInfo
                        .applicationInfo

                val appName =
                    packageManager
                        .getApplicationLabel(
                            applicationInfo
                        )
                        .toString()

                val packageName =
                    applicationInfo.packageName

                                mapOf(
                    "appName" to appName,
                    "packageName" to packageName
                )
            }
            .distinctBy {
                it["packageName"]
            }
            .sortedBy {
                it["appName"]?.lowercase()
            }
    }
}
