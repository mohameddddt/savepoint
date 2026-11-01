import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';
import '../util.dart';

/// Vertical bars with labels underneath. Animates in.
class Bars extends StatelessWidget {
  const Bars({super.key, required this.values, required this.labels, this.height = 140, this.color, this.highlight, this.format});
  final List<double> values;
  final List<String> labels;
  final double height;
  final Color? color;
  final int? highlight;
  final String Function(double)? format;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.accent;
    final mx = values.fold<double>(0, max);
    return SizedBox(
      height: height + 34,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (values[i] > 0)
                      Text(
                        format?.call(values[i]) ?? values[i].round().toString(),
                        maxLines: 1,
                        style: T.label.copyWith(fontSize: 8.5, color: i == highlight ? c : C.sub, letterSpacing: 0),
                      ),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: mx == 0 ? 0 : values[i] / mx),
                      duration: Duration(milliseconds: 500 + i * 30),
                      curve: Curves.easeOutCubic,
                      builder: (_, f, _) => Container(
                        height: max(3, f * (height - 16)),
                        decoration: BoxDecoration(
                          color: values[i] == 0 ? C.high : (highlight == null || i == highlight ? c : c.withValues(alpha: 0.45)),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(labels[i], maxLines: 1, style: T.label.copyWith(fontSize: 8.5, letterSpacing: 0.4)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Letterboxd-style rating spread: ten half-star buckets.
class RatingSpread extends StatelessWidget {
  const RatingSpread({super.key, required this.counts, this.height = 70});
  final List<int> counts; // index 0 = half star … 9 = five stars
  final double height;
  @override
  Widget build(BuildContext context) {
    final mx = counts.fold<int>(0, max);
    final total = counts.fold<int>(0, (a, b) => a + b);
    var sum = 0;
    for (var i = 0; i < counts.length; i++) {
      sum += counts[i] * (i + 1);
    }
    final avg = total == 0 ? 0.0 : sum / total / 2;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 2),
          child: Icon(Icons.star_half_rounded, size: 14, color: C.gold),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 10; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: mx == 0 ? 0 : counts[i] / mx),
                        duration: Duration(milliseconds: 450 + i * 35),
                        curve: Curves.easeOutCubic,
                        builder: (_, f, _) => Container(
                          height: max(2, f * height),
                          decoration: BoxDecoration(
                            color: counts[i] == 0 ? C.high : Color.lerp(C.faint, C.gold, 0.35 + 0.65 * (counts[i] / max(1, mx)))!,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(total == 0 ? '—' : avg.toStringAsFixed(1), style: T.h3.copyWith(color: C.gold, fontSize: 17)),
            const SizedBox(height: 2),
            const Text('★★★★★', style: TextStyle(color: C.gold, fontSize: 9)),
          ],
        ),
      ],
    );
  }
}

/// GitHub-style activity grid of the last [weeks] weeks, newest on the right.
class Heatmap extends StatelessWidget {
  const Heatmap({super.key, required this.minutesByDay, this.weeks = 53, this.cell = 12, this.gap = 3, this.end});
  final Map<DateTime, int> minutesByDay;
  final int weeks;
  final double cell;
  final double gap;
  final DateTime? end;
  @override
  Widget build(BuildContext context) {
    final w = weeks * (cell + gap);
    return SizedBox(
      height: 7 * (cell + gap) + 18,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: CustomPaint(size: Size(w, 7 * (cell + gap) + 18), painter: _HeatPainter(minutesByDay, weeks, cell, gap, context.accent, end ?? DateTime.now())),
      ),
    );
  }
}

class _HeatPainter extends CustomPainter {
  _HeatPainter(this.data, this.weeks, this.cell, this.gap, this.color, this.end);
  final Map<DateTime, int> data;
  final int weeks;
  final double cell, gap;
  final Color color;
  final DateTime end;

  @override
  void paint(Canvas canvas, Size size) {
    final last = DateUtils.dateOnly(end);
    final lastCol = last.subtract(Duration(days: last.weekday - 1)); // monday of current week
    final first = lastCol.subtract(Duration(days: (weeks - 1) * 7));
    final p = Paint();
    final r = Radius.circular(cell * 0.28);
    int? prevMonth;
    for (var wk = 0; wk < weeks; wk++) {
      final monday = DateTime(first.year, first.month, first.day + wk * 7);
      if (monday.month != prevMonth) {
        if (prevMonth != null || wk == 0) {
          final tp = TextPainter(
            text: TextSpan(
              text: mon[monday.month - 1],
              style: const TextStyle(fontFamily: T.mono, fontSize: 8.5, color: C.muted, fontWeight: FontWeight.w600),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          if (wk < weeks - 1) tp.paint(canvas, Offset(wk * (cell + gap), 0));
        }
        prevMonth = monday.month;
      }
      for (var d = 0; d < 7; d++) {
        final day = DateTime(monday.year, monday.month, monday.day + d);
        if (day.isAfter(last)) continue;
        final m = data[day] ?? 0;
        final double f = m <= 0 ? 0.0 : (m < 30 ? 0.3 : (m < 90 ? 0.55 : (m < 180 ? 0.8 : 1.0)));
        p.color = f == 0 ? C.raised : Color.lerp(C.raised, color, f)!;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(wk * (cell + gap), 16 + d * (cell + gap), cell, cell), r), p);
      }
    }
  }

  @override
  bool shouldRepaint(_HeatPainter o) => o.data != data || o.color != color;
}

/// Circular progress ring with centre content.
class Ring extends StatelessWidget {
  const Ring({super.key, required this.progress, this.size = 120, this.stroke = 10, this.color, this.child});
  final double progress;
  final double size;
  final double stroke;
  final Color? color;
  final Widget? child;
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0, 1)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => CustomPaint(
        size: Size.square(size),
        painter: _RingPainter(v, stroke, color ?? context.accent),
        child: SizedBox.square(
          dimension: size,
          child: Center(child: c),
        ),
      ),
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.stroke, this.color);
  final double v, stroke;
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    final rect = Offset(stroke / 2, stroke / 2) & Size(s.width - stroke, s.height - stroke);
    final bg = Paint()
      ..color = C.high
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, pi * 2, false, bg);
    if (v <= 0) return;
    final fg = Paint()
      ..shader = SweepGradient(
        startAngle: -pi / 2,
        endAngle: pi * 1.5,
        colors: [color.withValues(alpha: 0.55), color],
        transform: const GradientRotation(-pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(rect, -pi / 2, pi * 2 * v, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v || o.color != color;
}

/// Ranked horizontal bars (genres, platforms…).
class RankBars extends StatelessWidget {
  const RankBars({super.key, required this.items, this.color, this.max = 6, this.suffix = ''});
  final List<MapEntry<String, num>> items;
  final Color? color;
  final int max;
  final String suffix;
  @override
  Widget build(BuildContext context) {
    final c = color ?? context.accent;
    final list = items.take(max).toList();
    if (list.isEmpty) return Text('Nothing here yet', style: T.small);
    final top = list.first.value.toDouble();
    return Column(
      children: [
        for (var i = 0; i < list.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: Text('${i + 1}'.padLeft(2, '0'), style: T.label.copyWith(color: i == 0 ? c : C.muted)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 34,
                        decoration: BoxDecoration(color: C.raised, borderRadius: BorderRadius.circular(10)),
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: top == 0 ? 0 : list[i].value / top),
                        duration: Duration(milliseconds: 550 + i * 60),
                        curve: Curves.easeOutCubic,
                        builder: (_, f, _) => FractionallySizedBox(
                          widthFactor: f.clamp(0.02, 1.0),
                          child: Container(
                            height: 34,
                            decoration: BoxDecoration(
                              color: c.withValues(alpha: i == 0 ? 0.34 : 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(list[i].key, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.title.copyWith(fontSize: 13)),
                              ),
                              Text(
                                '${list[i].value is double ? (list[i].value as double).toStringAsFixed(0) : list[i].value}$suffix',
                                style: T.label.copyWith(color: C.text),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
