import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'leetcode_service.dart';

// Type definitions for dependency injection
typedef FetchUserData = Future<Map<String, dynamic>?> Function(String username);
typedef SaveWidgetData = Future<bool?> Function<T>(String key, T? value);
typedef UpdateWidget = Future<bool?> Function({String? name, String? androidName, String? iOSName, String? qualifiedAndroidName});

Future<bool> performBackgroundFetch({
  Future<SharedPreferences>? prefsFuture, 
  FetchUserData? fetchUserData,
  SaveWidgetData? saveWidgetData,
  UpdateWidget? updateWidget,
}) async {
  try {
    final prefs = await (prefsFuture ?? SharedPreferences.getInstance());
    final username = prefs.getString('leetcode_username');
    
    final savedPalette = prefs.getString('widget_color_palette') 
        ?? '#333333,#0e4429,#006d32,#26a641,#39d353';

    if (username == null || username.isEmpty) {
      debugPrint("No username saved. Aborting background task.");
      return Future.value(true); 
    }
    
    // Call our upgraded API fetcher
    final fetcher = fetchUserData ?? LeetCodeService.fetchUserData;
    final userData = await fetcher(username);
    
    // ... inside performBackgroundFetch ...

    if (userData != null) {
      final String heatmapString = LeetCodeService.processHeatmapData(userData['calendar'], daysToFetch: 365);
      
      final saver = saveWidgetData ?? HomeWidget.saveWidgetData;
      final updater = updateWidget ?? HomeWidget.updateWidget;

      await saver<String>('widget_color_palette', savedPalette);
      await saver<String>('widget_data', heatmapString);
      
      await saver<String>('streak_count', userData['streak'].toString());
      await saver<String>('solved_easy', userData['easy'].toString());
      await saver<String>('solved_medium', userData['medium'].toString());
      await saver<String>('solved_hard', userData['hard'].toString());
      await saver<String>('solved_total', userData['total'].toString());
      
      // NEW: Save Platform Totals
      await saver<String>('platform_easy', userData['platform_easy'].toString());
      await saver<String>('platform_medium', userData['platform_medium'].toString());
      await saver<String>('platform_hard', userData['platform_hard'].toString());

      await updater(name: 'LeetCodeWidgetProvider');
      await updater(name: 'StreakWidgetProvider');
      await updater(name: 'RingsWidgetProvider');
      
      return Future.value(true); 
    } else {
      return Future.value(false); 
    }
  } catch (err) {
    debugPrint("Background task failed: $err");
    return Future.value(false); 
  }
}