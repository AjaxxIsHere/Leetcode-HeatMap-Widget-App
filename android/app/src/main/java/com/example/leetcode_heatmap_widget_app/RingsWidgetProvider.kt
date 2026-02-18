package com.example.leetcode_heatmap_widget_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import androidx.core.content.edit
import androidx.core.graphics.toColorInt
import androidx.core.graphics.createBitmap

class RingsWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val ACTION_TOGGLE_VIEW = "com.example.leetcode_heatmap_widget_app.TOGGLE_RINGS_VIEW"
        const val PREF_SHOW_STATS = "show_stats_view"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (widgetId in appWidgetIds) {
            drawWidget(context, appWidgetManager, widgetId, widgetData)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        if (intent.action == ACTION_TOGGLE_VIEW) {
            val widgetData = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val currentMode = widgetData.getBoolean(PREF_SHOW_STATS, false)
            widgetData.edit { putBoolean(PREF_SHOW_STATS, !currentMode) }

            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = android.content.ComponentName(context, RingsWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

            val views = RemoteViews(context.packageName, R.layout.rings_widget)
            views.showNext(R.id.view_flipper)

            if (!currentMode) {
                views.setViewVisibility(R.id.total_solved_text, android.view.View.GONE)
            } else {
                views.setViewVisibility(R.id.total_solved_text, android.view.View.VISIBLE)
            }

            appWidgetManager.updateAppWidget(appWidgetIds, views)
        }
    }

    private fun drawWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        widgetData: SharedPreferences
    ) {
        val views = RemoteViews(context.packageName, R.layout.rings_widget)

        val intent = Intent(context, RingsWidgetProvider::class.java).apply {
            action = ACTION_TOGGLE_VIEW
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.rings_root, pendingIntent)

        // --- NEW: Parse the Theme Palette ---
        val paletteString = widgetData.getString("widget_color_palette", "#333333,#0e4429,#006d32,#26a641,#39d353")
            ?: "#333333,#0e4429,#006d32,#26a641,#39d353"
        val colors = paletteString.split(",").map { it.trim() }

        // Fallback safety
        val colorEasy = if (colors.size > 2) colors[2].toColorInt() else "#00B8A3".toColorInt()
        val colorMed  = if (colors.size > 3) colors[3].toColorInt() else "#FFC01E".toColorInt()
        val colorHard = if (colors.size > 4) colors[4].toColorInt() else "#FF375F".toColorInt()

        // Pass these colors to the generators!
        val bitmapFront = generateRingsBitmap(context, widgetData, colorEasy, colorMed, colorHard)
        val bitmapBack = generateStatsBitmap(context, widgetData, colorEasy, colorMed, colorHard)

        views.setImageViewBitmap(R.id.rings_front, bitmapFront)
        views.setImageViewBitmap(R.id.rings_back, bitmapBack)

        val showStats = widgetData.getBoolean(PREF_SHOW_STATS, false)
        views.setDisplayedChild(R.id.view_flipper, if (showStats) 1 else 0)

        val total = widgetData.getString("solved_total", "0") ?: "0"
        views.setTextViewText(R.id.total_solved_text, total)

        val ringTextSize = when (total.length) {
            in 0..2 -> 22f // "99" fits fine
            3 -> 18f       // "500" needs to shrink
            4 -> 15f       // "1200" needs to be small
            else -> 12f    // "10000" (God mode) needs to be tiny
        }
        views.setTextViewTextSize(R.id.total_solved_text, android.util.TypedValue.COMPLEX_UNIT_SP, ringTextSize)
        // Set the center text color to the brightest accent color (Hard Color)
        views.setTextColor(R.id.total_solved_text, colorHard)

        views.setViewVisibility(R.id.total_solved_text, if (showStats) android.view.View.GONE else android.view.View.VISIBLE)

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    // Helper to dim a color for the "track" background
    private fun darkenColor(color: Int): Int {
        val hsv = FloatArray(3)
        Color.colorToHSV(color, hsv)
        hsv[2] *= 0.3f // Darken to 30% brightness
        return Color.HSVToColor(hsv)
    }

    private fun generateRingsBitmap(
        context: Context,
        widgetData: SharedPreferences,
        cEasy: Int, cMed: Int, cHard: Int
    ): Bitmap {
        val easy = widgetData.getString("solved_easy", "0")?.toIntOrNull() ?: 0
        val med = widgetData.getString("solved_medium", "0")?.toIntOrNull() ?: 0
        val hard = widgetData.getString("solved_hard", "0")?.toIntOrNull() ?: 0

        val size = 300
        val center = size / 2f
        val bitmap = createBitmap(size, size)
        val canvas = Canvas(bitmap)
        val paint = Paint().apply {
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            isAntiAlias = true
        }

        val goalEasy = 500f
        val goalMed = 300f
        val goalHard = 100f

        // Easy (Outer) - Uses Color Index 2
        val rEasy = 120f
        paint.strokeWidth = 22f
        paint.color = darkenColor(cEasy) // Darker track
        canvas.drawCircle(center, center, rEasy, paint)
        paint.color = cEasy
        canvas.drawArc(RectF(center - rEasy, center - rEasy, center + rEasy, center + rEasy), -90f, (easy / goalEasy).coerceAtMost(1f) * 360f, false, paint)

        // Medium (Middle) - Uses Color Index 3
        val rMed = 90f
        paint.color = darkenColor(cMed)
        canvas.drawCircle(center, center, rMed, paint)
        paint.color = cMed
        canvas.drawArc(RectF(center - rMed, center - rMed, center + rMed, center + rMed), -90f, (med / goalMed).coerceAtMost(1f) * 360f, false, paint)

        // Hard (Inner) - Uses Color Index 4 (Accent)
        val rHard = 60f
        paint.color = darkenColor(cHard)
        canvas.drawCircle(center, center, rHard, paint)
        paint.color = cHard
        canvas.drawArc(RectF(center - rHard, center - rHard, center + rHard, center + rHard), -90f, (hard / goalHard).coerceAtMost(1f) * 360f, false, paint)

        return bitmap
    }

    private fun generateStatsBitmap(
        context: Context,
        widgetData: SharedPreferences,
        cEasy: Int, cMed: Int, cHard: Int
    ): Bitmap {
        val easy = widgetData.getString("solved_easy", "0")?.toIntOrNull() ?: 0
        val med = widgetData.getString("solved_medium", "0")?.toIntOrNull() ?: 0
        val hard = widgetData.getString("solved_hard", "0")?.toIntOrNull() ?: 0

        val totalEasy = widgetData.getString("platform_easy", "800")?.toFloatOrNull() ?: 800f
        val totalMed = widgetData.getString("platform_medium", "1600")?.toFloatOrNull() ?: 1600f
        val totalHard = widgetData.getString("platform_hard", "700")?.toFloatOrNull() ?: 700f

        val w = 400
        val h = 400
        val bitmap = createBitmap(w, h)
        val canvas = Canvas(bitmap)

        val textPaint = Paint().apply {
            textSize = 28f
            isAntiAlias = true
            typeface = android.graphics.Typeface.DEFAULT_BOLD
        }

        val barBgPaint = Paint().apply {
            color = "#333333".toColorInt()
            style = Paint.Style.FILL
            isAntiAlias = true
        }

        fun drawRow(label: String, color: Int, solved: Int, total: Float, yPos: Float) {
            textPaint.color = color
            canvas.drawText("$label: $solved / ${total.toInt()}", 20f, yPos, textPaint)

            val barTop = yPos + 15f
            val barBottom = barTop + 20f
            val barWidth = 360f
            canvas.drawRoundRect(20f, barTop, 20f + barWidth, barBottom, 10f, 10f, barBgPaint)

            val progressPaint = Paint().apply { this.color = color }
            val progress = (solved / total).coerceAtMost(1f) * barWidth
            if (progress > 0) {
                canvas.drawRoundRect(20f, barTop, 20f + progress, barBottom, 10f, 10f, progressPaint)
            }
        }

        // Draw the 3 rows using the passed theme colors
        drawRow("Easy", cEasy, easy, totalEasy, 80f)
        drawRow("Medium", cMed, med, totalMed, 180f)
        drawRow("Hard", cHard, hard, totalHard, 280f)

        return bitmap
    }
}