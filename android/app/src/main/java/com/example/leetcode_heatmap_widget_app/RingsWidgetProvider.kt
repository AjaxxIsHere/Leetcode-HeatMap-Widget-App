package com.example.leetcode_heatmap_widget_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.os.Bundle
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class RingsWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (widgetId in appWidgetIds) {
            drawRings(context, appWidgetManager, widgetId, widgetData)
        }
    }

    private fun drawRings(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        widgetData: SharedPreferences
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_rings)

        // 1. Grab the Data
        val easy = widgetData.getString("solved_easy", "0")?.toIntOrNull() ?: 0
        val med = widgetData.getString("solved_medium", "0")?.toIntOrNull() ?: 0
        val hard = widgetData.getString("solved_hard", "0")?.toIntOrNull() ?: 0
        val total = widgetData.getString("solved_total", "0") ?: "0"

        // Update center text
        views.setTextViewText(R.id.total_solved_text, total)

        // 2. Setup Dimensions (Fixed 300x300 canvas for high quality)
        val size = 300
        val center = size / 2f
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        // 3. Setup Paints (The Colors!)
        val paint = Paint().apply {
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            isAntiAlias = true
        }

        // Define our goals (The denominator)
        val maxEasy = 500f
        val maxMed = 300f
        val maxHard = 100f

        // 4. Draw The Rings
        // We calculate sweep angle: (Current / Goal) * 360

        // -- Outer Ring (Easy - Green) --
        val radiusEasy = 120f
        val strokeEasy = 22f
        paint.strokeWidth = strokeEasy
        // Draw faint background ring
        paint.color = Color.parseColor("#1e3a29") // Dark green background
        canvas.drawCircle(center, center, radiusEasy, paint)
        // Draw progress arc
        paint.color = Color.parseColor("#00B8A3") // LeetCode Cyan/Green
        val sweepEasy = (easy / maxEasy).coerceAtMost(1f) * 360f
        canvas.drawArc(
            RectF(center - radiusEasy, center - radiusEasy, center + radiusEasy, center + radiusEasy),
            -90f, sweepEasy, false, paint
        )

        // -- Middle Ring (Medium - Yellow) --
        val radiusMed = 90f
        val strokeMed = 22f
        paint.strokeWidth = strokeMed
        paint.color = Color.parseColor("#3a301e") // Dark yellow background
        canvas.drawCircle(center, center, radiusMed, paint)
        paint.color = Color.parseColor("#FFC01E") // LeetCode Yellow
        val sweepMed = (med / maxMed).coerceAtMost(1f) * 360f
        canvas.drawArc(
            RectF(center - radiusMed, center - radiusMed, center + radiusMed, center + radiusMed),
            -90f, sweepMed, false, paint
        )

        // -- Inner Ring (Hard - Red) --
        val radiusHard = 60f
        val strokeHard = 22f
        paint.strokeWidth = strokeHard
        paint.color = Color.parseColor("#3a1e1e") // Dark red background
        canvas.drawCircle(center, center, radiusHard, paint)
        paint.color = Color.parseColor("#FF375F") // LeetCode Red
        val sweepHard = (hard / maxHard).coerceAtMost(1f) * 360f
        canvas.drawArc(
            RectF(center - radiusHard, center - radiusHard, center + radiusHard, center + radiusHard),
            -90f, sweepHard, false, paint
        )

        views.setImageViewBitmap(R.id.rings_image, bitmap)
        appWidgetManager.updateAppWidget(widgetId, views)
    }
}