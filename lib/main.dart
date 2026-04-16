import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'activity_monitor.dart';
import 'model/activity_log_model.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ActivityMonitor()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hybrid Office Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E1E2E),
        ),
        scaffoldBackgroundColor: const Color(0xFF181825),
        cardTheme: CardThemeData(
          color: const Color(0xFF313244),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const LogListView(),
    );
  }
}

class LogListView extends StatefulWidget {
  const LogListView({super.key});

  @override
  State<LogListView> createState() => _LogListViewState();
}

class _LogListViewState extends State<LogListView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ActivityMonitor>(context, listen: false).startMonitoringLoop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final monitor = Provider.of<ActivityMonitor>(context);

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 280,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(right: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                const Text("Activity\nTracker",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -1)),
                const SizedBox(height: 8),
                Text("v1.0.2 - macOS Native",
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                const Spacer(),
                const ControlPanel(),
                const SizedBox(height: 20),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _buildTopStatsBar(monitor),
                Expanded(
                  child: monitor.logs.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                    itemCount: monitor.logs.length,
                    padding: const EdgeInsets.all(20),
                    itemBuilder: (context, index) {
                      final log = monitor.logs[monitor.logs.length - 1 - index];
                      return _buildLogCard(context, log, monitor);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopStatsBar(ActivityMonitor monitor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          Text("Recent Activity",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.9))),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStateColor(monitor.state).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _getStateColor(monitor.state).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.circle, size: 8, color: _getStateColor(monitor.state)),
                const SizedBox(width: 8),
                Text(monitor.state.name.toUpperCase(),
                    style: TextStyle(color: _getStateColor(monitor.state), fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(BuildContext context, ActivityLog log, ActivityMonitor monitor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF313244),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  log.status == "Active" ? Icons.computer : Icons.timer_outlined,
                  color: log.status == "Active" ? Colors.blueAccent : Colors.orangeAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(log.windowTitle,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      "${log.status} • ${DateFormat('hh:mm:ss a').format(log.timestamp)}",
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showCommentDialog(context, log, monitor),
                icon: Icon(Icons.add_comment_outlined,
                    size: 18,
                    color: log.comment != null ? Colors.white : Colors.white24),
                tooltip: "Add Note",
              ),
            ],
          ),
          if (log.comment != null && log.comment!.isNotEmpty) ...[
            const Divider(color: Colors.white10, height: 20),
            Container(
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "Note: ${log.comment}",
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.white70),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showCommentDialog(BuildContext context, ActivityLog log, ActivityMonitor monitor) {
    final controller = TextEditingController(text: log.comment);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text("Log Note"),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: "Enter details about this activity..."),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              // Ensure your ActivityLog has a comment field and ActivityMonitor has an update method
              monitor.updateLogComment(log, controller.text);
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insights, size: 64, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text("Waiting for activity...", style: TextStyle(color: Colors.white.withOpacity(0.3))),
        ],
      ),
    );
  }

  Color _getStateColor(WorkState state) {
    switch (state) {
      case WorkState.working: return const Color(0xFF81F7AD);
      case WorkState.onBreak: return Colors.orangeAccent;
      case WorkState.idle: return Colors.grey;
      case WorkState.finished: return Colors.blueAccent;
    }
  }
}

class ControlPanel extends StatelessWidget {
  const ControlPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final monitor = Provider.of<ActivityMonitor>(context);
    final state = monitor.state;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state == WorkState.idle)
          _actionButton(
            label: "Start Shift",
            icon: Icons.play_arrow_rounded,
            color: const Color(0xFF6366F1),
            onPressed: () {
              monitor.startShift();
              monitor.startMonitoringLoop(context);
            },
          ),

        if (state == WorkState.working) ...[
          _actionButton(
            label: "Take a Break",
            icon: Icons.pause_rounded,
            color: Colors.orangeAccent,
            onPressed: () => _showBreakDialog(context, monitor),
          ),
          const SizedBox(height: 12),
          _actionButton(
            label: "End Shift",
            icon: Icons.stop_rounded,
            color: const Color(0xFFF38BA8),
            onPressed: monitor.endShift,
          ),
        ],

        if (state == WorkState.onBreak)
          _actionButton(
            label: "Resume Work",
            icon: Icons.bolt_rounded,
            color: const Color(0xFF89B4FA),
            onPressed: monitor.resumeWork,
          ),

        if (state == WorkState.finished) ...[
          const Center(
            child: Text("Shift Completed ✓",
                style: TextStyle(color: Color(0xFF81F7AD), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          _actionButton(
            label: "New Shift",
            icon: Icons.refresh_rounded,
            color: const Color(0xFF6366F1),
            onPressed: () {
              // Ensure this method exists in your provider to clear logs and reset state to idle
              monitor.resetShift();
            },
          ),
        ],
      ],
    );
  }

  Widget _actionButton({required String label, required IconData icon, required Color color, required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }

  void _showBreakDialog(BuildContext context, ActivityMonitor monitor) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text("Break Reason"),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "e.g., Lunch, Coffee, Meeting...",
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                monitor.takeBreak(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text("Start Break"),
          ),
        ],
      ),
    );
  }
}