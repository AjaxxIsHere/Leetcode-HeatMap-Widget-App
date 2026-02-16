import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'leetcode_service.dart';

// Type definitions for dependency injection
typedef FetchSubmissionCalendar = Future<String?> Function(String username);
typedef SaveWidgetData = Future<bool?> Function<T>(String key, T? value);
typedef UpdateWidget = Future<bool?> Function({String? name, String? androidName, String? iOSName, String? qualifiedAndroidName});

Future<bool> performBackgroundFetch({
  Future<SharedPreferences>? prefsFuture, 
  FetchSubmissionCalendar? fetchCalendar,
  SaveWidgetData? saveWidgetData,
  UpdateWidget? updateWidget,
}) async {
  try {
    final prefs = await (prefsFuture ?? SharedPreferences.getInstance());
    final username = prefs.getString('leetcode_username');
    
    // Retrieve the saved hex palette, defaulting to green if not found.
    final savedPalette = prefs.getString('widget_color_palette') 
        ?? '#333333,#0e4429,#006d32,#26a641,#39d353';

    if (username == null || username.isEmpty) {
      debugPrint("No username saved. Aborting background task.");
      return Future.value(true); 
    }
    
    final fetcher = fetchCalendar ?? LeetCodeService.fetchSubmissionCalendar;
    final rawData = await fetcher(username);
    
    if (rawData != null) {
      final String heatmapString = LeetCodeService.processHeatmapData(rawData, daysToFetch: 365);
      
      final saver = saveWidgetData ?? HomeWidget.saveWidgetData;
      final updater = updateWidget ?? HomeWidget.updateWidget;

      // Update widget data with palette and heatmap info.
      await saver<String>('widget_color_palette', savedPalette);
      await saver<String>('widget_data', heatmapString);
      await updater(name: 'LeetCodeWidgetProvider');
      
      return Future.value(true); 
    } else {
      return Future.value(false); 
    }
  } catch (err) {
    debugPrint("Background task failed: $err");
    return Future.value(false); 
  }
}