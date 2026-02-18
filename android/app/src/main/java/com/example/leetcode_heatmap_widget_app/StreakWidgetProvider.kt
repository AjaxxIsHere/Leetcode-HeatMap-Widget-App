package com.example.leetcode_heatmap_widget_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import androidx.core.graphics.toColorInt

// Notice we extend HomeWidgetProvider here, not AppWidgetProvider
class StreakWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.streak_widget_provider)

            // 1. Grab the streak count
            val streakStr = widgetData.getString("streak_count", "0") ?: "0"
            views.setTextViewText(R.id.streak_number, streakStr)

            // --- THE FIX: Dynamic Text Sizing ---
            // If streak is 1-2 digits (e.g., "99"), use 36sp (Big)
            // If streak is 3 digits (e.g., "100"), use 28sp (Medium)
            // If streak is 4+ digits (e.g., "1000"), use 22sp (Small)
            val textSize = when (streakStr.length) {
                in 0..2 -> 36f
                3 -> 28f
                else -> 22f
            }
            views.setTextViewTextSize(R.id.streak_number, android.util.TypedValue.COMPLEX_UNIT_SP, textSize)
            // ------------------------------------

            // 2. Grab the current theme palette
            val paletteString = widgetData.getString("widget_color_palette", "#333333,#0e4429,#006d32,#26a641,#39d353")
                ?: "#333333,#0e4429,#006d32,#26a641,#39d353"

            try {
                val colors = paletteString.split(",")
                val accentColor = Color.parseColor(colors.last().trim())
                views.setTextColor(R.id.streak_number, accentColor)
            } catch (e: Exception) {
                views.setTextColor(R.id.streak_number, Color.parseColor("#39d353"))
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}