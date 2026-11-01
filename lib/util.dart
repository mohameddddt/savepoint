import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const mon = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
const wd = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

String fmtMinutes(int m, {bool long = false}) {
  if (m <= 0) return long ? '0 hours' : '0h';
  if (m < 60) return long ? '$m min' : '${m}m';
  final h = m / 60;
  final s = h >= 100 ? h.round().toString() : (h % 1 == 0 ? h.toStringAsFixed(0) : h.toStringAsFixed(1));
  return long ? '$s ${s == '1' ? 'hour' : 'hours'}' : '${s}h';
}

String fmtClock(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
}

String fmtSecondsAsHours(int? s) {
  if (s == null || s <= 0) return '—';
  final h = s / 3600;
  if (h < 1) return '${(s / 60).round()}m';
  return h >= 20 ? '${h.round()}h' : '${h.toStringAsFixed(h % 1 < 0.05 ? 0 : 1)}h';
}

String fmtDate(DateTime d, {bool year = true}) =>
    '${d.day} ${mon[d.month - 1].toLowerCase().replaceFirstMapped(RegExp(r'^.'), (m) => m[0]!.toUpperCase())}${year ? ' ${d.year}' : ''}';

String fmtMs(int? ms, {bool year = true}) => ms == null ? '—' : fmtDate(DateTime.fromMillisecondsSinceEpoch(ms), year: year);

String relDays(DateTime d) {
  final today = DateUtils.dateOnly(DateTime.now());
  final diff = DateUtils.dateOnly(d).difference(today).inDays;
  if (diff == 0) return 'today';
  if (diff == 1) return 'tomorrow';
  if (diff == -1) return 'yesterday';
  if (diff > 0) return diff < 60 ? 'in $diff days' : 'in ${(diff / 30).round()} months';
  final a = -diff;
  if (a < 30) return '$a days ago';
  if (a < 365) return '${(a / 30).round()} mo ago';
  return '${(a / 365).floor()}y ago';
}

String ago(int ms) {
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return fmtMs(ms, year: DateTime.fromMillisecondsSinceEpoch(ms).year != DateTime.now().year);
}

String stars(int r) => r <= 0 ? '' : '${'★' * (r ~/ 2)}${r.isOdd ? '½' : ''}';

void tick() => HapticFeedback.selectionClick();
void thud() => HapticFeedback.mediumImpact();

Future<T?> push<T>(BuildContext context, Widget page) => Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

void toast(BuildContext context, String msg, {String? action, VoidCallback? onAction}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      content: Text(msg),
      duration: const Duration(milliseconds: 2600),
      action: action == null ? null : SnackBarAction(label: action, onPressed: onAction ?? () {}),
    ),
  );
}

/// Deterministic colour from a seed — used for cover-less placeholder art.
Color hueFor(int seed, {double s = 0.55, double l = 0.42}) {
  final h = (seed.abs() * 137.508) % 360;
  return HSLColor.fromAHSL(1, h, s, l).toColor();
}
