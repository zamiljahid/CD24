class ActivityLog {
  final String windowTitle;
  final String status;
  final DateTime timestamp;
  String? comment; // Add this line

  ActivityLog({
    required this.windowTitle,
    required this.status,
    required this.timestamp,
    this.comment, // Add this line
  });
}