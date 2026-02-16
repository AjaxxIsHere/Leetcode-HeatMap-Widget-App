import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LeetCodeService {
  static const String _endpoint = 'https://leetcode.com/graphql';

  static Future<String?> fetchSubmissionCalendar(String username) async {
    // 1. Define the GraphQL query
    final Map<String, dynamic> requestBody = {
      "query": """
        query getUserProfile(\$username: String!) {
          matchedUser(username: \$username) {
            submissionCalendar
          }
        }
      """,
      "variables": {
        "username": username
      }
    };

    try {
      // 2. Send the POST request
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      // 3. Parse the response
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        final matchedUser = data['data']['matchedUser'];
        if (matchedUser == null) {
          debugPrint("Error: User not found on LeetCode.");
          return null;
        }

        // LeetCode actually returns the calendar as a stringified JSON object!
        return matchedUser['submissionCalendar']; 
      } else {
        debugPrint("Server error: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("Network error: $e");
      return null;
    }
  }

  static String processHeatmapData(String jsonString, {int daysToFetch = 365}) {
    // 1. Decode the raw JSON string
    final Map<String, dynamic> decodedData = jsonDecode(jsonString);
    
    // 2. Map timestamps to normalized local dates
    Map<DateTime, int> dailySubmissions = {};
    
    decodedData.forEach((timestampStr, count) {
      // LeetCode sends seconds, Dart needs milliseconds
      final int milliseconds = int.parse(timestampStr) * 1000;
      final DateTime date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
      
      // Normalize to strictly Year-Month-Day to avoid timezone shifts
      final DateTime normalizedDate = DateTime(date.year, date.month, date.day);
      
      // Sum the counts (just in case LeetCode split them across timezones)
      dailySubmissions[normalizedDate] = (dailySubmissions[normalizedDate] ?? 0) + (count as int);
    });

    // 3. Generate the intensity list for the last X days
    List<int> intensities = [];
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    // Loop from 59 days ago up to today
    for (int i = daysToFetch - 1; i >= 0; i--) {
      final DateTime targetDate = today.subtract(Duration(days: i));
      final int count = dailySubmissions[targetDate] ?? 0;

      // 4. Convert raw count to an intensity level (0-4)
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

    // 5. Join into a simple comma-separated string (e.g., "0,1,0,4,2...")
    return intensities.join(',');
  }
}