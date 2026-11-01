import 'package:flutter/material.dart';

import '../theme.dart';
import '../util.dart';

/// Drag or tap across five stars; half-star precision. Tap the current value to clear.
class RatingBar extends StatefulWidget {
  const RatingBar({super.key, required this.value, required this.onChanged, this.size = 40});
  final int value;
  final ValueChanged<int> onChanged;
  final double size;
  @override
  State<RatingBar> createState() => _RatingBarState();
}

class _RatingBarState extends State<RatingBar> {
  late int _v = widget.value;
  int? _dragStart;

  @override
  void didUpdateWidget(RatingBar old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _v = widget.value;
  }

  int _at(double dx) {
    final w = widget.size * 5;
    return ((dx.clamp(0, w) / w) * 10).ceil().clamp(1, 10);
  }

  void _set(int v) {
    if (v == _v) return;
    tick();
    setState(() => _v = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) {
        final v = _at(d.localPosition.dx);
        final nv = v == widget.value ? 0 : v;
        tick();
        setState(() => _v = nv);
        widget.onChanged(nv);
      },
      onHorizontalDragStart: (d) {
        _dragStart = _v;
        _set(_at(d.localPosition.dx));
      },
      onHorizontalDragUpdate: (d) => _set(_at(d.localPosition.dx)),
      onHorizontalDragEnd: (_) {
        if (_dragStart != _v) widget.onChanged(_v);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 5; i++)
            AnimatedScale(
              scale: _v >= i * 2 + 1 ? 1.0 : 0.86,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutBack,
              child: Icon(
                _v >= (i + 1) * 2
                    ? Icons.star_rounded
                    : _v == i * 2 + 1
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
                size: widget.size,
                color: _v >= i * 2 + 1 ? C.gold : C.faint,
              ),
            ),
        ],
      ),
    );
  }
}
