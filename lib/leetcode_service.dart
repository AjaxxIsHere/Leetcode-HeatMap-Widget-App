import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LeetCodeService {
  static const String _endpoint = 'https://leetcode.com/graphql';

  static Future<Map<String, dynamic>?> fetchUserData(String username) async {
    final Map<String, dynamic> requestBody = {
      "query": """
        query getUserProfile(\$username: String!) {
          allQuestionsCount {
            difficulty
            count
          }
          matchedUser(username: \$username) {
            submissionCalendar
            submitStats {
              acSubmissionNum {
                difficulty
                count
              }
            }
          }
        }
      """,
      "variables": {
        "username": username
      }
    };

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        final matchedUser = data['data']['matchedUser'];
        final allQuestions = data['data']['allQuestionsCount']; // New Data!

        if (matchedUser == null) {
          debugPrint("Error: User not found on LeetCode.");
          return null;
        }

        // 1. Extract Calendar
        final calendarStr = matchedUser['submissionCalendar'];
        
        // 2. Extract Solved Counts (User)
        final List<dynamic> acSubmissionNum = matchedUser['submitStats']['acSubmissionNum'];
        int easy = 0, medium = 0, hard = 0, total = 0;
        for (var item in acSubmissionNum) {
          if (item['difficulty'] == 'Easy') easy = item['count'];
          if (item['difficulty'] == 'Medium') medium = item['count'];
          if (item['difficulty'] == 'Hard') hard = item['count'];
          if (item['difficulty'] == 'All') total = item['count'];
        }

        // 3. Extract Platform Totals (LeetCode Global)
        int totalEasy = 1, totalMedium = 1, totalHard = 1;
        for (var item in allQuestions) {
          if (item['difficulty'] == 'Easy') totalEasy = item['count'];
          if (item['difficulty'] == 'Medium') totalMedium = item['count'];
          if (item['difficulty'] == 'Hard') totalHard = item['count'];
        }

        // 4. Calculate Streak
        int streak = _calculateCurrentStreak(calendarStr);

        return {
          'calendar': calendarStr,
          'streak': streak,
          'easy': easy,
          'medium': medium,
          'hard': hard,
          'total': total,
          'platform_easy': totalEasy,
          'platform_medium': totalMedium,
          'platform_hard': totalHard,
        };
      } else {
        debugPrint("Server error: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("Network error: $e");
      return null;
    }
  }

  static int _calculateCurrentStreak(String jsonString) {
    final Map<String, dynamic> decodedData = jsonDecode(jsonString);
    Map<DateTime, int> dailySubmissions = {};

    decodedData.forEach((timestampStr, count) {
      final int milliseconds = int.parse(timestampStr) * 1000;
      final DateTime date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
      final DateTime normalizedDate = DateTime(date.year, date.month, date.day);
      dailySubmissions[normalizedDate] = (dailySubmissions[normalizedDate] ?? 0) + (count as int);
    });

    int streak = 0;
    final DateTime now = DateTime.now();
    DateTime targetDate = DateTime(now.year, now.month, now.day);

    if ((dailySubmissions[targetDate] ?? 0) > 0) {
      streak++;
      targetDate = targetDate.subtract(const Duration(days: 1));
    } else {
      targetDate = targetDate.subtract(const Duration(days: 1));
      if ((dailySubmissions[targetDate] ?? 0) == 0) return 0;
    }

    while (true) {
      if ((dailySubmissions[targetDate] ?? 0) > 0) {
        streak++;
        targetDate = targetDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  static String processHeatmapData(String jsonString, {int daysToFetch = 365}) {
    // (This logic remains exactly the same as before)
    final Map<String, dynamic> decodedData = jsonDecode(jsonString);
    Map<DateTime, int> dailySubmissions = {};
    decodedData.forEach((timestampStr, count) {
      final int milliseconds = int.parse(timestampStr) * 1000;
      final DateTime date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
      final DateTime normalizedDate = DateTime(date.year, date.month, date.day);
      dailySubmissions[normalizedDate] = (dailySubmissions[normalizedDate] ?? 0) + (count as int);
    });
    List<int> intensities = [];
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    for (int i = daysToFetch - 1; i >= 0; i--) {
      final DateTime targetDate = today.subtract(Duration(days: i));
      final int count = dailySubmissions[targetDate] ?? 0;
      if (count == 0) {
        intensities.add(0);
      } else if (count <= 2) {
        intensities.add(1);
      } else if (count <= 5) {
        intensities.add(2);
      } else if (count <= 8) {
        intensities.add(3);
      } else {
        intensities.add(4);
      }
    }
    return intensities.join(',');
  }
}