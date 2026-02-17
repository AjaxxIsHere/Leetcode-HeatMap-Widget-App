package com.example.leetcode_heatmap_widget_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.os.Bundle
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetPlugin
import kotlin.math.ceil
import androidx.core.graphics.toColorInt
import androidx.core.graphics.createBitmap
import androidx.core.content.ContextCompat
import android.content.res.Configuration
import android.content.Intent
import android.content.ComponentName

class LeetCodeWidgetProvider : HomeWidgetProvider() {

    // --- NEW: The Catcher's Mitt for OS Broadcasts ---
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        // If the OS shouts that the theme just changed (Light/Dark mode)
        if (intent.action == "android.intent.action.UI_MODE_CHANGED") {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, LeetCodeWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

            // Grab the saved data and force a redraw instantly!
            val widgetData = HomeWidgetPlugin.getData(context)
            for (widgetId in appWidgetIds) {
                drawResponsiveHeatmap(context, appWidgetManager, widgetId, widgetData)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (widgetId in appWidgetIds) {
            drawResponsiveHeatmap(context, appWidgetManager, widgetId, widgetData)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle?
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)

        val widgetData = HomeWidgetPlugin.getData(context)
        drawResponsiveHeatmap(context, appWidgetManager, appWidgetId, widgetData)
    }

    private fun drawResponsiveHeatmap(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        widgetData: SharedPreferences
    ) {
        val views = RemoteViews(context.packageName, R.layout.leet_code_widget_provider)
        val flutterData = widgetData.getString("widget_data", "")

        if (!flutterData.isNullOrEmpty()) {
            val allIntensities = flutterData.split(",").map { it.toIntOrNull() ?: 0 }

            val options = appWidgetManager.getAppWidgetOptions(widgetId)
            var widthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            if (widthDp == 0) widthDp = 320

            var heightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
            if (heightDp == 0) heightDp = 110

            val rows = 7
            val paddingDp = 1.5f

            val availableHeightDp = heightDp - 12f
            val cellSizeDp = (availableHeightDp / rows) - paddingDp

            val availableWidthDp = widthDp - 12f
            val columnWidthDp = cellSizeDp + paddingDp
            val maxCols = (availableWidthDp / columnWidthDp).toInt().coerceIn(1, 52)

            val maxDaysToFit = maxCols * rows
            val intensities = allIntensities.takeLast(maxDaysToFit)

            val density = context.resources.displayMetrics.density
            val cellSize = cellSizeDp * density
            val cellPadding = paddingDp * density

            val cols = ceil(intensities.size.toDouble() / rows).toInt()
            val widthPx = (cols * (cellSize + cellPadding)).toInt()
            val heightPx = (rows * (cellSize + cellPadding)).toInt()

            // Check if the OS is in Dark Mode
            val isNightMode = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES

            // Separate bitmaps for empty and filled cells allow independent tinting/theming.
            val emptyBitmap = createBitmap(widthPx, heightPx)
            val filledBitmap = createBitmap(widthPx, heightPx)

            val emptyCanvas = Canvas(emptyBitmap)
            val filledCanvas = Canvas(filledBitmap)

            // Paint for empty squares must be solid white so the XML tint can color it correctly.
            val emptyPaint = Paint().apply {
                style = Paint.Style.FILL
                color = Color.WHITE
            }

            val filledPaint = Paint().apply { style = Paint.Style.FILL }

            // Get the native empty cell color that respects the device's Light/Dark mode.
            val nativeEmptyColor = ContextCompat.getColor(context, R.color.empty_cell)

            val paletteString = widgetData.getString("widget_color_palette", "#333333,#0e4429,#006d32,#26a641,#39d353")
                ?: "#333333,#0e4429,#006d32,#26a641,#39d353"

            val colors = paletteString.split(",").map { hex ->
                try {
                    hex.trim().toColorInt()
                } catch (e: IllegalArgumentException) {
                    "#333333".toColorInt()
                }
            }.toIntArray()

            for (i in intensities.indices) {
                val col = i / rows
                val row = i % rows

                val left = col * (cellSize + cellPadding)
                val top = row * (cellSize + cellPadding)
                val right = left + cellSize
                val bottom = top + cellSize

                val intensityLevel = intensities[i].coerceIn(0, 4)

                // --- THE FIX: Reverse the intensity for Light Mode ---
                if (intensityLevel == 0) {
                    // Empty squares are handled by Android XML
                    emptyCanvas.drawRoundRect(left, top, right, bottom, 4f * density, 4f * density, emptyPaint)
                } else {
                    // If Dark Mode, use normal intensity (1,2,3,4)
                    // If Light Mode, reverse it: 5 - 1 = 4, 5 - 2 = 3, etc.
                    val mappedIntensity = if (isNightMode) intensityLevel else (5 - intensityLevel)

                    filledPaint.color = colors[mappedIntensity]
                    filledCanvas.drawRoundRect(left, top, right, bottom, 4f * density, 4f * density, filledPaint)
                }

//                // Draw to separate layers.
//                if (intensityLevel == 0) {
//                    emptyCanvas.drawRoundRect(left, top, right, bottom, 4f * density, 4f * density, emptyPaint)
//                } else {
//                    filledPaint.color = colors[intensityLevel]
//                    filledCanvas.drawRoundRect(left, top, right, bottom, 4f * density, 4f * density, filledPaint)
//                }
            }

            views.setImageViewBitmap(R.id.widget_empty_grid, emptyBitmap)
            views.setImageViewBitmap(R.id.widget_filled_grid, filledBitmap)
        }

        appWidgetManager.updateAppWidget(widgetId, views)
    }
}