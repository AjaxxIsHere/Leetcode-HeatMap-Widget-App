import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leetcode_heatmap_widget_app/background_task.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Background Task Execution Tests', () {

    // --- YOUR ORIGINAL HAPPY PATH ---
    test('1. SUCCESS: Executes task and updates widget when user exists', () async {
      SharedPreferences.setMockInitialValues({'leetcode_username': 'AjaxxIsHere'});

      bool fetchCalled = false;
      bool saveCalled = false;
      bool updateCalled = false;

      final result = await performBackgroundFetch(
        fetchCalendar: (username) async {
          fetchCalled = true;
          return '{"1677628800": 1}'; 
        },
        saveWidgetData: <T>(key, value) async {
          saveCalled = true;
          return true;
        },
        updateWidget: ({name, androidName, iOSName, qualifiedAndroidName}) async {
          updateCalled = true;
          return true;
        },
      );

      expect(result, true, reason: 'Task should complete successfully');
      expect(fetchCalled, true, reason: 'Should attempt to fetch data');
      expect(saveCalled, true, reason: 'Should save to widget');
      expect(updateCalled, true, reason: 'Should trigger widget update');
    });

    // --- NEGATIVE TEST CASE 1: NO USERNAME ---
    test('2. ABORT: Aborts silently and returns true if no username is saved', () async {
      // Mock empty preferences
      SharedPreferences.setMockInitialValues({}); 

      bool fetchCalled = false;

      final result = await performBackgroundFetch(
        fetchCalendar: (username) async {
          fetchCalled = true;
          return null;
        },
      );

      // It should return TRUE so the OS doesn't keep retrying a hopeless task
      expect(result, true, reason: 'Task should abort cleanly');
      // The API should NEVER be called
      expect(fetchCalled, false, reason: 'Should not attempt to fetch data without a username');
    });

    // --- NEGATIVE TEST CASE 2: NETWORK FAILURE ---
    test('3. RETRY: Returns false to trigger OS retry if LeetCode returns null', () async {
      SharedPreferences.setMockInitialValues({'leetcode_username': 'test_user'});

      bool saveCalled = false;

      final result = await performBackgroundFetch(
        fetchCalendar: (username) async {
          // Simulate a 404 error or a network drop returning null
          return null; 
        },
        saveWidgetData: <T>(key, value) async {
          saveCalled = true;
          return true;
        },
      );

      // It MUST return FALSE to tell Android to try again in 10 minutes
      expect(result, false, reason: 'Should fail and trigger OS exponential backoff');
      // It should never try to send empty data to the native widget
      expect(saveCalled, false, reason: 'Should not update widget with null data');
    });

    // --- NEGATIVE TEST CASE 3: UNEXPECTED EXCEPTION ---
    test('4. CATCH: Catches fatal exceptions and returns false to trigger OS retry', () async {
      SharedPreferences.setMockInitialValues({'leetcode_username': 'test_user'});

      final result = await performBackgroundFetch(
        fetchCalendar: (username) async {
          // Simulate a complete crash (e.g., SocketException, JSON parsing error)
          throw Exception("CRITICAL NETWORK FAILURE"); 
        },
      );

      // Even if the code explodes, it should be caught and tell the OS to retry
      expect(result, false, reason: 'Should catch exception and trigger retry');
    });
  });
}