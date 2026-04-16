import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'model/activity_log_model.dart';

// --- NATIVE BRIDGE ---
class NativeMonitor {
  static const platform = MethodChannel('com.hybrid.office/monitor');

  static Future<String> getActiveWindowTitle() async {
    try {
      final String result = await platform.invokeMethod('getActiveWindow');
      return result;
    } on PlatformException catch (e) {
      return "Unknown Window (${e.message})";
    }
  }

  static Future<int> getIdleTimeInSeconds() async {
    try {
      final int seconds = await platform.invokeMethod('getIdleTime');
      return seconds;
    } on PlatformException {
      return 0;
    }
  }
}

enum WorkState { idle, working, onBreak, finished }

class ActivityMonitor extends ChangeNotifier {
  Timer? _timer;
  WorkState _state = WorkState.idle;
  String _lastWindow = "";
  bool _isIdlePopupOpen = false;
  final List<ActivityLog> logs = [];

  WorkState get state => _state;

  // --- BUTTON ACTIONS ---

  void resetShift() {
    logs.clear();
    _state = WorkState.idle;
    _lastWindow = "";
    _isIdlePopupOpen = false;
    _timer?.cancel();
    notifyListeners();
  }

  void updateLogComment(ActivityLog log, String newComment) {
    final index = logs.indexOf(log);
    if (index != -1) {
      logs[index].comment = newComment;
      notifyListeners();
    }
  }

  void startShift() {
    logs.clear();
    _state = WorkState.working;
    _lastWindow = "";
    _logActivity("System", "Shift Started");
    notifyListeners();
  }

  // RESTORED: Missing takeBreak method
  void takeBreak(String reason) {
    _state = WorkState.onBreak;
    _logActivity("Break: $reason", "Paused");
    notifyListeners();
  }

  // RESTORED: Missing resumeWork method
  void resumeWork() {
    _state = WorkState.working;
    _logActivity("System", "Shift Resumed");
    notifyListeners();
  }

  // RESTORED: Missing endShift method
  void endShift() {
    _state = WorkState.finished;
    _logActivity("System", "Shift Ended");
    _timer?.cancel();
    notifyListeners();
  }

  // --- MONITORING LOOP ---

  void startMonitoringLoop(BuildContext context) {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_state != WorkState.working) return;

      // 1. Get Current Activity
      String currentWindow = await NativeMonitor.getActiveWindowTitle();

      // 2. Check if Audio is playing (Prevents idle during videos/calls)
      bool audioPlaying = false;
      try {
        audioPlaying = await NativeMonitor.platform.invokeMethod('isAudioPlaying');
      } catch (_) {}

      // 3. Update Log if window changed
      if (currentWindow != _lastWindow && currentWindow.isNotEmpty) {
        _logActivity(currentWindow, "Window Switched");
        _lastWindow = currentWindow;
      }

      // 4. Idle Logic
      int idleSeconds = await NativeMonitor.getIdleTimeInSeconds();

      // If audio is playing or it's a known meeting window, stay active
      if (audioPlaying) return;

      // Check threshold (120 seconds = 2 minutes)
      if (idleSeconds >= 120 && !_isIdlePopupOpen) {
        _isIdlePopupOpen = true;
        _showIdleAlert(context);
      } else if (idleSeconds < 10) {
        _isIdlePopupOpen = false;
      }
    });
  }

  void _logActivity(String title, String status) {
    logs.insert(0, ActivityLog(
      timestamp: DateTime.now(),
      windowTitle: title,
      status: status,
    ));
    notifyListeners();
  }

  // --- THE IMPROVED ALERT ---
  Future<void> _showIdleAlert(BuildContext context) async {
    try {
      // Pulls the Flutter app to the front of macOS
      await NativeMonitor.platform.invokeMethod('forceFocus');
    } catch (e) {
      debugPrint("Focus failed: $e");
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Row(
          children: [
            Icon(Icons.timer_outlined, color: Colors.orangeAccent),
            SizedBox(width: 10),
            Text("Are you still there?"),
          ],
        ),
        content: const Text("System detected 2 minutes of inactivity."),
        actions: [
          TextButton(
            onPressed: () {
              _isIdlePopupOpen = false;
              Navigator.pop(context);
              resumeWork();
            },
            child: const Text("YES, I'M WORKING"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              _isIdlePopupOpen = false;
              Navigator.pop(context);
              takeBreak("Idle timeout");
            },
            child: const Text("TAKE BREAK", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
// --- UI VIEW ---
class LogListView extends StatelessWidget {
  const LogListView({super.key});

  @override
  Widget build(BuildContext context) {
    final monitor = Provider.of<ActivityMonitor>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Employee Productivity Tracker")),
      body: ListView.builder(
        itemCount: monitor.logs.length,
        itemBuilder: (context, index) {
          final log = monitor.logs[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              isThreeLine: true,
              title: Text(
                  log.windowTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold)
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Status: ${log.status} • ${DateFormat('hh:mm:ss a').format(log.timestamp)}"),
                  const SizedBox(height: 5),
                  TextField(
                    controller: TextEditingController(text: log.comment)..selection = TextSelection.collapsed(offset: log.comment!.length),
                    decoration: const InputDecoration(
                      hintText: "Add comment...",
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (val) => monitor.updateLogComment(log, val),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );  }
}