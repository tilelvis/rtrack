// Native Android AppWidgetProvider for Loan Tracker.
//
// Reads loan summary from SharedPreferences (the same backing store
// Flutter's `shared_preferences` package uses, prefixed with "flutter.")
// and renders it into the home-screen widget layout (widget_loan.xml).
//
// Update triggers:
//   1. Android system periodic update (every 30 min — see widget_info.xml)
//   2. APPWIDGET_UPDATE broadcast (sent by Flutter via HomeWidget or manual)
//   3. Whenever the user opens the app (WidgetService writes new values)

package com.example.loan_tracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews

class LoanWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        appWidgetIds.forEach { id ->
            updateWidget(context, appWidgetManager, id)
        }
    }

    override fun onEnabled(context: Context) {
        // Called when the first widget instance is placed.
        // Trigger an immediate refresh so the widget shows real data.
        pushUpdate(context)
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        // Read from Flutter's SharedPreferences (package_context + "FlutterSharedPreferences")
        val prefs: SharedPreferences = context.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE
        )

        // Read with the "flutter." prefix that shared_preferences adds internally
        val title = prefs.getString("flutter.widget_loan_title", "No active loan") ?: "No active loan"
        val balance = prefs.getString("flutter.widget_balance", "Ksh 0") ?: "Ksh 0"
        val nextDue = prefs.getString("flutter.widget_next_due", "Due —") ?: "Due —"
        val dailyAmount = prefs.getString("flutter.widget_daily_amount", "—") ?: "—"
        val progressDouble = prefs.getFloat("flutter.widget_progress", 0f)
        val progressPct = (progressDouble * 100).toInt().coerceIn(0, 100)

        val views = RemoteViews(context.packageName, R.layout.widget_loan)
        views.setTextViewText(R.id.widget_loan_title, title)
        views.setTextViewText(R.id.widget_balance, balance)
        views.setTextViewText(R.id.widget_progress_pct, "$progressPct%")
        views.setTextViewText(R.id.widget_next_due, nextDue)
        views.setTextViewText(R.id.widget_daily_amount, dailyAmount)
        views.setProgressBar(R.id.widget_progress_bar, 100, progressPct, false)

        // Tap on the widget opens the app
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            appWidgetId,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    companion object {
        /// Force every instance of the widget to refresh.
        /// Call from Flutter via a MethodChannel, or from the app's
        /// MainActivity whenever a payment is logged.
        fun pushUpdate(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(
                ComponentName(context, LoanWidgetProvider::class.java)
            )
            val provider = LoanWidgetProvider()
            provider.onUpdate(context, mgr, ids)
        }
    }
}
