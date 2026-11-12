
package com.mindora.family

import android.app.usage.UsageStatsManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.google.android.gms.tasks.Tasks
import com.google.firebase.firestore.FirebaseFirestore
import java.util.Calendar

class AppLimitWorker(
    context: Context,
    params: WorkerParameters
) : Worker(context, params) {

    override fun doWork(): Result {
        val childId = inputData.getString("childId")
            ?: return Result.failure()

        return try {
            val db = FirebaseFirestore.getInstance()

            val limits = Tasks.await(
                db.collection("users")
                    .document(childId)
                    .collection("appLimits")
                    .get()
            )

            val usageManager =
                applicationContext.getSystemService(
                    Context.USAGE_STATS_SERVICE
                ) as UsageStatsManager

            val calendar = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }

            val startTime = calendar.timeInMillis
            val endTime = System.currentTimeMillis()

            val usageStats = usageManager.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY,
                startTime,
                endTime
            ) ?: emptyList()

            val policyManager =
                applicationContext.getSystemService(
                    Context.DEVICE_POLICY_SERVICE
                ) as DevicePolicyManager

            val adminComponent = ComponentName(
                applicationContext,
                MindoraDeviceAdminReceiver::class.java
            )

            if (!policyManager.isDeviceOwnerApp(
                    applicationContext.packageName
                )
            ) {
                return Result.failure()
            }

            for (doc in limits.documents) {
                val data: Map<String, Any> = doc.data ?: continue

		if (data["enabled"] as? Boolean == false) continue

                val packageName =
                    data["packageName"] as? String ?: doc.id

                val limit = (data["dailyLimitMinutes"] as? Number)
                    ?.toLong() ?: continue

                if (limit <= 0) continue

                val usedMillis = usageStats
                    .filter { it.packageName == packageName }
                    .sumOf { it.totalTimeInForeground }

                val usedMinutes = usedMillis / 60_000L

                if (usedMinutes >= limit) {
                    policyManager.setPackagesSuspended(
                        adminComponent,
                        arrayOf(packageName),
                        true
                    )
                }
            }

            Result.success()
        } catch (e: Exception) {
            android.util.Log.e(
                "AppLimitWorker",
                "Süre sınırı kontrolü başarısız",
                e
            )
            Result.retry()
        }
    }
}
