import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../screens/game_detail.dart';
import '../screens/log_sheet.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';

/// Rebuilds when the store changes.
class Watch extends StatelessWidget {
  const Watch({super.key, required this.builder});
  final WidgetBuilder builder;
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: store, builder: (c, _) => builder(c));
}

class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.scale = 0.96});
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null && widget.onLongPress == null ? null : (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              _set(false);
              thud();
              widget.onLongPress!();
            },
      child: AnimatedScale(scale: _down ? widget.scale : 1, duration: const Duration(milliseconds: 110), curve: Curves.easeOut, child: widget.child),
    );
  }
}

/// Box-art with graceful generated fallback.
class Cover extends StatelessWidget {
  const Cover(this.game, {super.key, this.radius = 10, this.heroTag, this.size = 't_cover_big'});
  final Game game;
  final double radius;
  final Object? heroTag;
  final String size;

  @override
  Widget build(BuildContext context) {
    final url = img(game.cover, size);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    Widget child = LayoutBuilder(
      builder: (context, box) {
        if (url == null) return CoverArt(game);
        final w = box.maxWidth.isFinite ? (box.maxWidth * dpr).round() : null;
        return CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          memCacheWidth: w,
          fadeInDuration: const Duration(milliseconds: 160),
          fadeOutDuration: Duration.zero,
          placeholder: (_, _) => const ColoredBox(color: C.raised),
          errorWidget: (_, _, _) => CoverArt(game),
        );
      },
    );
    child = AspectRatio(
      aspectRatio: 3 / 4,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(radius), child: child),
      ),
    );
    return heroTag == null ? child : Hero(tag: heroTag!, child: child);
  }
}

/// Generated "cartridge label" for games without art.
class CoverArt extends StatelessWidget {
  const CoverArt(this.game, {super.key});
  final Game game;
  @override
  Widget build(BuildContext context) {
    final c = hueFor(game.id);
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth.isFinite ? box.maxWidth : 120.0;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c, Color.lerp(c, C.bg, 0.75)!]),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -w * 0.25,
                top: -w * 0.2,
                child: Gem(size: w * 0.9, color: Colors.white.withValues(alpha: 0.08)),
              ),
              if (w < 64)
                Center(
                  child: Text(
                    game.name.split(RegExp(r'[\s:]+')).where((s) => s.isNotEmpty).take(2).map((s) => s.characters.first.toUpperCase()).join(),
                    style: TextStyle(fontFamily: T.display, fontWeight: FontWeight.w800, fontSize: w * 0.34, color: Colors.white, letterSpacing: -0.5),
                  ),
                )
              else
                Padding(
                  padding: EdgeInsets.all(w * 0.09),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      game.name,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: T.display,
                        fontWeight: FontWeight.w800,
                        fontSize: (w * 0.14).clamp(9, 30),
                        height: 1.0,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The Savepoint gem — a save-crystal mark.
class Gem extends StatelessWidget {
  const Gem({super.key, this.size = 20, this.color, this.filled = false});
  final double size;
  final Color? color;
  final bool filled;
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _GemPainter(color ?? context.accent, filled));
}

class _GemPainter extends CustomPainter {
  _GemPainter(this.color, this.filled);
  final Color color;
  final bool filled;
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    Path diamond(double inset) => Path()
      ..moveTo(w / 2, h * inset)
      ..lineTo(w * (1 - inset), h / 2)
      ..lineTo(w / 2, h * (1 - inset))
      ..lineTo(w * inset, h / 2)
      ..close();
    final p = Paint()
      ..color = color
      ..isAntiAlias = true;
    if (filled) {
      canvas.drawPath(diamond(0.04), p);
    } else {
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.1
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(diamond(0.09), p);
      canvas.drawPath(diamond(0.34), Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_GemPainter o) => o.color != color || o.filled != filled;
}

class StarRow extends StatelessWidget {
  const StarRow(this.rating, {super.key, this.size = 12, this.color = C.gold});
  final int rating;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) {
    if (rating <= 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rating ~/ 2; i++) Icon(Icons.star_rounded, size: size, color: color),
        if (rating.isOdd) Icon(Icons.star_half_rounded, size: size, color: color),
      ],
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key, this.solid = false});
  final Status status;
  final bool solid;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(color: solid ? status.color : status.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.tag,
        style: T.label.copyWith(fontSize: 9, color: solid ? C.bg : status.color, fontWeight: FontWeight.w800, letterSpacing: 1.1),
      ),
    );
  }
}

/// Standard cover tile with title + overlays; tap → detail, long-press → quick actions.
class GameTile extends StatelessWidget {
  const GameTile(this.game, {super.key, this.width, this.tagPrefix = 't', this.meta = true, this.badges = true, this.subtitle});
  final Game game;
  final double? width;
  final String tagPrefix;
  final bool meta;
  final bool badges;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final tag = '$tagPrefix-${game.id}';
    final e = store.entry(game.id);
    final tile = Pressable(
      onTap: () => openGame(context, game, heroTag: tag),
      onLongPress: () => showQuickActions(context, game),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Cover(game, heroTag: tag),
              if (badges && e != null) ...[
                Positioned(left: 6, top: 6, child: _Dot(e.status)),
                if (e.rating > 0 || e.liked)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(6, 14, 6, 5),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                        ),
                      ),
                      child: Row(
                        children: [
                          StarRow(e.rating, size: 11),
                          const Spacer(),
                          if (e.liked) const Icon(Icons.favorite_rounded, size: 11, color: C.heart),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
          if (meta) ...[
            const SizedBox(height: 8),
            Text(game.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.title.copyWith(fontSize: 13, height: 1.2)),
            const SizedBox(height: 3),
            Text(
              subtitle ?? '${game.year ?? 'TBA'}${game.dev.isNotEmpty ? ' · ${game.dev}' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: T.label.copyWith(fontSize: 9.5, letterSpacing: 0.6),
            ),
          ],
        ],
      ),
    );
    return width == null ? tile : SizedBox(width: width, child: tile);
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.s);
  final Status s;
  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      color: C.bg.withValues(alpha: 0.82),
      shape: BoxShape.circle,
      border: Border.all(color: s.color, width: 1.5),
    ),
    child: Icon(s.icon, size: 12, color: s.color),
  );
}

void openGame(BuildContext context, Game g, {Object? heroTag}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, _, _) => GameDetailScreen(game: g, heroTag: heroTag),
      transitionsBuilder: (_, a, _, child) {
        final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: c,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(c),
            child: child,
          ),
        );
      },
    ),
  );
}

class SectionHead extends StatelessWidget {
  const SectionHead(this.title, {super.key, this.kicker, this.action, this.onAction, this.padding = const EdgeInsets.fromLTRB(20, 30, 16, 14)});
  final String title;
  final String? kicker;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (kicker != null) ...[
                  Row(
                    children: [
                      Gem(size: 9, color: context.accent, filled: true),
                      const SizedBox(width: 7),
                      Text(kicker!.toUpperCase(), style: T.label.copyWith(color: context.accent)),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                Text(title, style: T.h2),
              ],
            ),
          ),
          if (action != null)
            Pressable(
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 4, 4),
                child: Row(
                  children: [
                    Text(action!.toUpperCase(), style: T.label.copyWith(color: C.sub)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 13, color: C.sub),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class Btn extends StatelessWidget {
  const Btn(this.label, {super.key, this.icon, this.onTap, this.ghost = false, this.color, this.dense = false, this.expand = false});
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool ghost;
  final Color? color;
  final bool dense;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bg = ghost ? C.raised : (color ?? context.accent);
    final fg = ghost ? C.text : (color == null ? context.onAccent : C.bg);
    final row = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: dense ? 17 : 19, color: fg), const SizedBox(width: 8)],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: T.display, fontWeight: FontWeight.w700, fontSize: dense ? 14 : 15.5, color: fg, letterSpacing: -0.2),
          ),
        ),
      ],
    );
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: dense ? 42 : 52,
          padding: EdgeInsets.symmetric(horizontal: dense ? 14 : 20),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(dense ? 13 : 16),
            border: ghost ? Border.all(color: C.line) : null,
          ),
          child: row,
        ),
      ),
    );
  }
}

class CircleBtn extends StatelessWidget {
  const CircleBtn(this.icon, {super.key, this.onTap, this.size = 42, this.color, this.bg, this.tooltip});
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? color;
  final Color? bg;
  final String? tooltip;
  @override
  Widget build(BuildContext context) {
    final w = Pressable(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg ?? C.raised,
          shape: BoxShape.circle,
          border: Border.all(color: C.line),
        ),
        child: Icon(icon, size: size * 0.46, color: color ?? C.text),
      ),
    );
    return tooltip == null ? w : Tooltip(message: tooltip!, child: w);
  }
}

class Chip2 extends StatelessWidget {
  const Chip2(this.label, {super.key, this.selected = false, this.onTap, this.color, this.icon, this.count});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? color;
  final IconData? icon;
  final int? count;
  @override
  Widget build(BuildContext context) {
    final c = color ?? context.accent;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.16) : C.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? c : C.line, width: selected ? 1.3 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 14, color: selected ? c : C.sub), const SizedBox(width: 6)],
            Text(
              label,
              style: TextStyle(fontFamily: T.body, fontWeight: FontWeight.w700, fontSize: 13, color: selected ? c : C.sub),
            ),
            if (count != null) ...[const SizedBox(width: 6), Text('$count', style: T.label.copyWith(fontSize: 10, color: selected ? c : C.muted))],
          ],
        ),
      ),
    );
  }
}

class Card2 extends StatelessWidget {
  const Card2({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color, this.radius = 22, this.border = true});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;
  final bool border;
  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? C.surface,
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: C.line) : null,
      ),
      child: child,
    );
    return onTap == null ? box : Pressable(onTap: onTap, scale: 0.98, child: box);
  }
}

class Glow extends StatelessWidget {
  const Glow({super.key, this.color, this.size = 420, this.opacity = 0.22});
  final Color? color;
  final double size;
  final double opacity;
  @override
  Widget build(BuildContext context) {
    final c = color ?? context.accent;
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              c.withValues(alpha: opacity),
              c.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.body, this.action, this.onAction, this.icon});
  final String title;
  final String? body;
  final String? action;
  final VoidCallback? onAction;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 74,
            height: 74,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Gem(size: 74, color: C.line),
                if (icon != null) Icon(icon, color: C.muted, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: T.h3),
          if (body != null) ...[const SizedBox(height: 8), Text(body!, textAlign: TextAlign.center, style: T.small.copyWith(fontSize: 13.5, height: 1.5))],
          if (action != null) ...[const SizedBox(height: 20), Btn(action!, onTap: onAction, dense: true)],
        ],
      ),
    );
  }
}

class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.child});
  final Widget child;
  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: Tween(begin: 0.45, end: 1.0).animate(_c), child: widget.child);
}

class SkeletonRail extends StatelessWidget {
  const SkeletonRail({super.key, this.width = 118, this.height = 230});
  final double width;
  final double height;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Pulse(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 5,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: width,
                height: width * 4 / 3,
                decoration: BoxDecoration(color: C.raised, borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 10),
              Container(
                width: width * 0.8,
                height: 10,
                decoration: BoxDecoration(color: C.raised, borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(height: 6),
              Container(
                width: width * 0.5,
                height: 8,
                decoration: BoxDecoration(color: C.raised, borderRadius: BorderRadius.circular(4)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal cover rail.
class GameRail extends StatelessWidget {
  const GameRail(this.games, {super.key, this.tag = 'rail', this.width = 118, this.subtitle});
  final List<Game> games;
  final String tag;
  final double width;
  final String? Function(Game)? subtitle;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: width * 4 / 3 + 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: games.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => GameTile(games[i], width: width, tagPrefix: tag, subtitle: subtitle?.call(games[i])),
      ),
    );
  }
}

Future<R?> sheet<R>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<R>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: C.surface,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (c) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(color: C.faint, borderRadius: BorderRadius.circular(4)),
          ),
          Flexible(child: builder(c)),
        ],
      ),
    ),
  );
}

Future<bool> confirm(BuildContext context, String title, String body, {String yes = 'Delete', bool danger = true}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancel', style: TextStyle(color: C.sub)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(
            yes,
            style: TextStyle(color: danger ? const Color(0xFFFF5D5D) : c.accent, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
  return r == true;
}

class Labeled extends StatelessWidget {
  const Labeled(this.label, this.child, {super.key});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: T.label),
      const SizedBox(height: 9),
      child,
    ],
  );
}

/// Small big-number stat used in profile/stats.
class StatBlock extends StatelessWidget {
  const StatBlock(this.value, this.label, {super.key, this.color});
  final String value;
  final String label;
  final Color? color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(value, style: T.num.copyWith(color: color ?? C.text)),
      const SizedBox(height: 5),
      Text(label.toUpperCase(), style: T.label.copyWith(fontSize: 9.5)),
    ],
  );
}
