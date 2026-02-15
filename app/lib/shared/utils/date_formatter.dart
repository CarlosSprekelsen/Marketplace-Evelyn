/// Centralized date formatting for the app.
/// Format: "15 Feb 2026, 14:30" (Spanish month abbreviations).
/// Always converts UTC to local before formatting.
String formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
  final day = local.day;
  final month = months[local.month - 1];
  final year = local.year;
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day $month $year, $hour:$minute';
}
