import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:workmanager/workmanager.dart';
import 'leetcode_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'background_task.dart';
import 'dart:ui';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    return await performBackgroundFetch();
  });
}

void main() {
  // Ensure Flutter bindings are initialized before doing background work.
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the Workmanager.
  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true, // Set to true to see debug logs.
  );

  // Schedule the recurring task.
  Workmanager().registerPeriodicTask(
    "update-leetcode-widget-task",
    "fetchLeetCodeData",
    frequency: const Duration(hours: 1),
    constraints: Constraints(
      networkType: NetworkType.connected, // Only run if the device has internet.
    ),
  );

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WidgetSetupScreen(),
    ),
  );
}

class WidgetSetupScreen extends StatefulWidget {
  const WidgetSetupScreen({super.key});

  @override
  State<WidgetSetupScreen> createState() => _WidgetSetupScreenState();
}

class _WidgetSetupScreenState extends State<WidgetSetupScreen> with WidgetsBindingObserver {
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;

  // The currently selected theme in the dropdown
  String _selectedTheme = 'LeetCode Green';

  // The hex codes for Intensity 0 (empty) through Intensity 4 (max)
  final Map<String, String> themePalettes = {
    'LeetCode Green': '#333333,#0e4429,#006d32,#26a641,#39d353',
    'Dracula (Purple)': '#282A36,#44475A,#6272A4,#BD93F9,#FF79C6',
    'Nord (Frost Blue)': '#2E3440,#4C566A,#81A1C1,#88C0D0,#8FBCBB',
    'Catppuccin (Mauve)': '#313244,#45475A,#585B70,#B4BEFE,#CBA6F7',
    'Monokai (Green Accent)': '#272822,#3E3D32,#75715E,#A6E22E,#E6DB74',
    'Tokyo Night (Blue)': '#1A1B26,#24283B,#414868,#7AA2F7,#BB9AF7',
    'Gruvbox (Warm)': '#282828,#3C3836,#665C54,#D79921,#FABD2F',
    'Solarized Dark (Cyan)': '#002B36,#073642,#586E75,#2AA198,#93A1A1',
    'One Dark (Blue)': '#282C34,#3E4451,#5C6370,#61AFEF,#98C379',
    'Rose Pine (Dawn)': '#191724,#26233A,#6E6A86,#EB6F92,#F6C177',
    'Kanagawa (Wave)': '#1F1F28,#2A2A37,#54546D,#7E9CD8,#98BB6C',
    'Ayu Dark (Orange)': '#0A0E14,#1F2430,#3E4B59,#FFB454,#FF8F40',
    'Everforest (Green)': '#2B3339,#3A464C,#7A8478,#A7C080,#D3C6AA',
    'Material Ocean (Teal)': '#0F111A,#1A1C25,#3B4252,#80CBC4,#A3D5FF',
    'Midnight Purple': '#1B1B2F,#162447,#1F4068,#533483,#E43F5A',
    'Sunset (Red-Orange)': '#2B0B0E,#4A1C1E,#7A2E2E,#C44536,#FF6B6B',
    'Iceberg (Cool Blue)': '#161821,#1E2132,#6B7089,#84A0C6,#C6C8D1',
    'Forest (Emerald)': '#0B1F1A,#12332A,#1F5F4A,#2BAE66,#A8E6CF',
    'Cherry Blossom (Pink)': '#2A1A2E,#412234,#7A3E65,#C06C84,#F8BBD0',
    'Smooth Green': '#0B1F14,#0F3D2E,#136F3A,#1FA64C,#39E75F',
    'Smooth Blue': '#0B1C2D,#123B63,#1F5FA8,#3D8BFF,#82B1FF',
    'Smooth Purple': '#1B1028,#341A4D,#5C2D91,#8E5CF7,#C9A6FF',
    'Smooth Orange': '#2A1405,#5C2C07,#A64B00,#FF7A00,#FFB347',
    'Smooth Red': '#2A0A0A,#5C1414,#A61E1E,#E53935,#FF8A80',
    'Smooth Pink': '#2A1020,#5C1F44,#A63D7A,#E66BB0,#FFB7E5',
    'Smooth Teal': '#062626,#0F4C4C,#1B7F7F,#2BC0C0,#7FEFEF',
    'Smooth Indigo': '#0F1026,#1B1E4B,#2F3E8F,#4F6DFF,#9FAEFF',
    'Smooth Gold': '#2A2305,#5C4A07,#A68A00,#E6C200,#FFE680',
    'Smooth Cyan': '#062A2F,#0E4F5A,#178A9A,#27C5D9,#8FF3FF',
  };

  /// Computes the dynamic palette based on the system theme.
  String _getDynamicPalette() {
    final basePalette = themePalettes[_selectedTheme]!;
    
    // Check the phone's current OS brightness
    final brightness = PlatformDispatcher.instance.platformBrightness;
    
    if (brightness == Brightness.light) {
      // If Light Mode, split the string and replace the 0th color with light grey
      List<String> colors = basePalette.split(',');
      colors[0] = '#EBEDF0'; 
      return colors.join(',');
    }
    
    return basePalette; // Return normal dark theme if in Dark Mode
  }

  @override
  void initState() {
    super.initState();
    _loadSavedUsername();
    // Register the OS listener.
    WidgetsBinding.instance.addObserver(this); 
  }

  @override
  void dispose() {
    // Unregister the listener to prevent memory leaks.
    WidgetsBinding.instance.removeObserver(this);
    _usernameController.dispose();
    super.dispose();
  }

  // Called when the platform brightness changes (e.g. Light/Dark mode).
  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    _redrawWidgetFast(); 
  }

  Future<void> _loadSavedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('leetcode_username');
    final savedTheme = prefs.getString('widget_theme_name'); // Load saved theme

    setState(() {
      if (savedName != null) _usernameController.text = savedName;
      if (savedTheme != null && themePalettes.containsKey(savedTheme)) {
        _selectedTheme = savedTheme;
      }
    });
  }

  Future<void> updateWidget() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('leetcode_username', username);
      // Save the theme name locally so the UI remembers it
      await prefs.setString('widget_theme_name', _selectedTheme);

      final String hexPalette = _getDynamicPalette();

      // Save the hex string to Flutter's local storage for the background task.
      await prefs.setString('widget_color_palette', hexPalette);
      
      await HomeWidget.saveWidgetData<String>(
        'widget_color_palette',
        hexPalette,
      );

      final rawCalendarData = await LeetCodeService.fetchSubmissionCalendar(
        username,
      );

      if (rawCalendarData != null) {
        final String heatmapString = LeetCodeService.processHeatmapData(
          rawCalendarData,
          daysToFetch: 365,
        );

        // Send the raw hex string to Android native code.
        final String hexPalette = themePalettes[_selectedTheme]!;
        await HomeWidget.saveWidgetData<String>(
          'widget_color_palette',
          hexPalette,
        );

        await HomeWidget.saveWidgetData<String>('widget_data', heatmapString);
        await HomeWidget.updateWidget(name: 'LeetCodeWidgetProvider');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Widget updated successfully!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("User not found or network error."),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("ERROR: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Triggers a native redraw without making a network request
  Future<void> _redrawWidgetFast() async {
    try {
      // Recalculate colors for the new theme.
      final String newPalette = _getDynamicPalette();
      
      // Send the updated colors to Native Android.
      await HomeWidget.saveWidgetData<String>('widget_color_palette', newPalette);
      
      // Trigger the redraw.
      await HomeWidget.updateWidget(name: 'LeetCodeWidgetProvider');
      debugPrint("Widget fast-redrawn for theme change!");
    } catch (e) {
      debugPrint("Error redrawing widget: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // A clean, dark-themed starting point for our ricing setup
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          "LeetCode Widget",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Setup Your Profile",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _usernameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "LeetCode Username",
                labelStyle: const TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.green),
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.person, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedTheme,
                  dropdownColor: const Color(0xFF1E1E1E),
                  icon: const Icon(Icons.palette, color: Colors.grey),
                  isExpanded: true,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  items: themePalettes.keys.map((String themeName) {
                    return DropdownMenuItem<String>(
                      value: themeName,
                      child: Text(themeName),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedTheme = newValue;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : updateWidget,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "Save & Sync Widget",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
