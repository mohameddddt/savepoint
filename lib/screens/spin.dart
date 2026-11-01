import 'dart:math';

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'log_sheet.dart';

/// "Pick for me" — a slot-machine reel over your backlog.
class SpinScreen extends StatefulWidget {
  const SpinScreen({super.key});
  @override
  State<SpinScreen> createState() => _SpinScreenState();
}

class _SpinScreenState extends State<SpinScreen> with SingleTickerProviderStateMixin {
  final pools = <Status>{Status.backlog};
  String length = 'any';
  String? platform;
  late final ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
  late Animation<double> pos = const AlwaysStoppedAnimation(0);
  List<Game> reel = [];
  Game? result;
  int _lastTick = 0;
  final _rnd = Random();

  @override
  void initState() {
    super.initState();
    reel = _pool();
    ac.addListener(() {
      final i = pos.value.floor();
      if (i != _lastTick) {
        _lastTick = i;
        tick();
      }
    });
    ac.addStatusListener((s) {
      if (s == AnimationStatus.completed && reel.isNotEmpty) {
        thud();
        setState(() => result = reel[pos.value.round() % reel.length]);
      }
    });
  }

  @override
  void dispose() {
    ac.dispose();
    super.dispose();
  }

  List<Game> _pool() {
    return store.entries.values
        .where((e) => pools.contains(e.status))
        .map((e) {
          final g = store.game(e.gameId);
          if (g == null) return null;
          final h = g.mainHours;
          if (length == 'short' && (h == null || h > 10)) return null;
          if (length == 'mid' && (h == null || h <= 10 || h > 30)) return null;
          if (length == 'long' && (h == null || h <= 30)) return null;
          if (platform != null && e.platform != platform && !g.platforms.contains(platform)) return null;
          if (g.upcoming) return null;
          return g;
        })
        .whereType<Game>()
        .toList()
      ..shuffle(_rnd);
  }

  void _refilter(VoidCallback f) {
    setState(() {
      f();
      reel = _pool();
      result = null;
      ac.reset();
      pos = const AlwaysStoppedAnimation(0);
    });
  }

  void _spin() {
    if (reel.isEmpty) return;
    final start = pos.value;
    final target = start.roundToDouble() + reel.length * 3 + _rnd.nextInt(reel.length) + (reel.length < 4 ? 8 : 0);
    setState(() {
      result = null;
      pos = Tween(begin: start, end: target).animate(CurvedAnimation(parent: ac, curve: const Cubic(0.12, 0.7, 0.16, 1)));
    });
    ac.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final platforms = <String>{
      for (final e in store.entries.values.where((e) => pools.contains(e.status))) ...[?e.platform],
    }.toList()..sort();
    final w = MediaQuery.sizeOf(context).width;
    return Scaffold(
      appBar: AppBar(title: const Text('Pick for me')),
      body: ListView(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 30),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text('Fate decides.\nYou play.', style: T.hero.copyWith(fontSize: 36)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 270,
            child: reel.isEmpty
                ? const Center(
                    child: EmptyState(title: 'Nothing to spin', body: 'No games match these filters. Widen the pool below.'),
                  )
                : AnimatedBuilder(
                    animation: ac,
                    builder: (_, _) => _Reel(games: reel, pos: pos.value, width: w, winner: result != null),
                  ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: result == null
                  ? Btn(
                      ac.isAnimating ? 'Spinning…' : 'Spin',
                      key: const ValueKey('spin'),
                      icon: Icons.casino_rounded,
                      expand: true,
                      onTap: ac.isAnimating || reel.isEmpty ? null : _spin,
                    )
                  : Column(
                      key: ValueKey(result!.id),
                      children: [
                        Text(result!.name, textAlign: TextAlign.center, style: T.h2),
                        const SizedBox(height: 6),
                        Text(
                          [
                            if (result!.mainHours != null) '~${result!.mainHours!.round()}h main story',
                            if (result!.genres.isNotEmpty) result!.genres.first,
                          ].join(' · '),
                          style: T.small,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Btn('Again', icon: Icons.refresh_rounded, ghost: true, onTap: _spin),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Btn(
                                'Start playing',
                                icon: Icons.play_arrow_rounded,
                                expand: true,
                                onTap: () {
                                  final g = result!;
                                  store.setStatus(g, Status.playing);
                                  Navigator.pop(context);
                                  startSessionFlow(context, g);
                                },
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => openGame(context, result!),
                          child: Text('VIEW GAME', style: T.label.copyWith(color: context.accent)),
                        ),
                      ],
                    ),
            ),
          ),
          SectionHead('The pool', kicker: '${reel.length} candidates'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in [Status.backlog, Status.wishlist, Status.shelved, Status.playing])
                      Chip2(
                        s.label,
                        icon: s.icon,
                        color: s.color,
                        count: store.count(s),
                        selected: pools.contains(s),
                        onTap: () => _refilter(() {
                          if (pools.contains(s)) {
                            if (pools.length > 1) pools.remove(s);
                          } else {
                            pools.add(s);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Labeled(
                  'How much time do you have?',
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final l in const [('any', 'Any length'), ('short', 'A weekend · ≤10h'), ('mid', 'A few weeks · 10–30h'), ('long', 'Epic · 30h+')])
                        Chip2(l.$2, selected: length == l.$1, onTap: () => _refilter(() => length = l.$1)),
                    ],
                  ),
                ),
                if (platforms.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Labeled(
                    'Platform',
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip2('Any', selected: platform == null, onTap: () => _refilter(() => platform = null)),
                        for (final p in platforms) Chip2(p, selected: platform == p, onTap: () => _refilter(() => platform = p)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text('Length filters use IGDB “time to beat” data where available.', style: T.small.copyWith(fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Reel extends StatelessWidget {
  const _Reel({required this.games, required this.pos, required this.width, required this.winner});
  final List<Game> games;
  final double pos;
  final double width;
  final bool winner;

  @override
  Widget build(BuildContext context) {
    const itemW = 150.0;
    final base = pos.floor();
    final children = <Widget>[];
    for (var k = base - 3; k <= base + 3; k++) {
      final d = k - pos;
      final g = games[((k % games.length) + games.length) % games.length];
      final scale = (1 - d.abs() * 0.18).clamp(0.5, 1.0);
      final opacity = (1 - d.abs() * 0.32).clamp(0.0, 1.0);
      children.add(
        Positioned(
          left: width / 2 - itemW / 2 + d * (itemW * 0.78),
          top: 10,
          width: itemW,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0015)
                  ..rotateY(d * -0.35),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: d.abs() < 0.5 && winner ? [BoxShadow(color: context.accent.withValues(alpha: 0.6), blurRadius: 40, spreadRadius: 2)] : null,
                  ),
                  child: Cover(g, radius: 14),
                ),
              ),
            ),
          ),
        ),
      );
    }
    // draw nearest last so it sits on top
    children.sort((a, b) {
      double dist(Widget w) => ((w as Positioned).left! - (width / 2 - itemW / 2)).abs();
      return dist(b).compareTo(dist(a));
    });
    return Stack(clipBehavior: Clip.none, children: children);
  }
}
