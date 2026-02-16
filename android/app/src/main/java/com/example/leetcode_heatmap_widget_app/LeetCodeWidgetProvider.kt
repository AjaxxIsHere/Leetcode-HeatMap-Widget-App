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
// --- NEW IMPORT ---
import androidx.core.content.ContextCompat

class LeetCodeWidgetProvider : HomeWidgetProvider() {

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

            // --- CREATE TWO CANVASES ---
            val emptyBitmap = createBitmap(widthPx, heightPx)
            val filledBitmap = createBitmap(widthPx, heightPx)
            
            val emptyCanvas = Canvas(emptyBitmap)
            val filledCanvas = Canvas(filledBitmap)
            
            // Paint for empty squares MUST be solid white so the XML tint can color it
            val emptyPaint = Paint().apply { 
                style = Paint.Style.FILL 
                color = Color.WHITE 
            }
            
            val filledPaint = Paint().apply { style = Paint.Style.FILL }

            // --- THE FIX: Grab the native Android color ---
            // This natively respects your values/colors.xml and values-night/colors.xml
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

                // --- THE FIX: Split the drawing layers ---
                if (intensityLevel == 0) {
                    emptyCanvas.drawRoundRect(left, top, right, bottom, 4f * density, 4f * density, emptyPaint)
                } else {
                    filledPaint.color = colors[intensityLevel]
                    filledCanvas.drawRoundRect(left, top, right, bottom, 4f * density, 4f * density, filledPaint)
                }
            }

            views.setImageViewBitmap(R.id.widget_empty_grid, emptyBitmap)
            views.setImageViewBitmap(R.id.widget_filled_grid, filledBitmap)
        }

        appWidgetManager.updateAppWidget(widgetId, views)
    }
}