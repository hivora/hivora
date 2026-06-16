import 'package:intl/intl.dart';

/// Shared date helpers for the sprint feature. Formats follow the HTML
/// reference (`Design/sprints`): "Mon, Jun 9" and "Jun 9 – Jun 20".
String prettyDate(DateTime date) => DateFormat('EEE, MMM d').format(date);

String shortDate(DateTime date) => DateFormat('MMM d').format(date);

String dateRange(DateTime? start, DateTime? end) {
  if (start == null || end == null) return '';
  return '${shortDate(start)} – ${shortDate(end)}';
}

/// End date auto-derived from a start date + week count, matching the
/// prototype's `start + weeks·7 − 3` (a Friday finish for a Monday start).
DateTime autoEndDate(DateTime start, int weeks) =>
    start.add(Duration(days: weeks * 7 - 3));

/// Day index (1-based) within a sprint window, clamped to [1, total].
({int day, int total})? sprintDay(DateTime? start, DateTime? end) {
  if (start == null || end == null || end.isBefore(start)) return null;
  final s = DateTime(start.year, start.month, start.day);
  final e = DateTime(end.year, end.month, end.day);
  final total = e.difference(s).inDays + 1;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final raw = today.difference(s).inDays + 1;
  return (day: raw.clamp(1, total), total: total);
}
