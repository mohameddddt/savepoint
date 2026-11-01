import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'diary.dart';
import 'library.dart';
import 'log_sheet.dart';
import 'search.dart';
import 'settings.dart';
import 'shell.dart';
import 'spin.dart';
import 'upcoming.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Late night,';
    if (h < 12) return 'Good morning,';
    if (h < 18) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Watch(
      builder: (context) {
        final now = DateTime.now();
        int lastTouch(Entry e) => store.lastSession(e.gameId)?.date ?? e.updatedAt;
        final playing = store.withStatus(Status.playing).toList()..sort((a, b) => lastTouch(b).compareTo(lastTouch(a)));
        final backlog = store.withStatus(Status.backlog).toList()
          ..sort((a, b) {
            final p = b.priority.compareTo(a.priority);
            return p != 0 ? p : a.addedAt.compareTo(b.addedAt);
          });
        final radar =
            store.entries.values
                .where((e) => e.status.unplayed || e.status == Status.playing)
                .map((e) => store.game(e.gameId))
                .whereType<Game>()
                .where((g) => g.upcoming)
                .toList()
              ..sort((a, b) => a.released!.compareTo(b.released!));
        final yearStart = DateTime(now.year).millisecondsSinceEpoch;
        final beaten = store.entries.values.where((e) => e.status.finished && (e.finishedAt ?? 0) >= yearStart).length;
        final yearMinutes = store.logs.where((l) => l.kind == LogKind.session && l.date >= yearStart).fold<int>(0, (a, l) => a + l.minutes);
        final empty = store.entries.isEmpty;

        return Stack(
          children: [
            Positioned(top: -170, right: -150, child: Glow(size: 480, opacity: 0.2)),
            ListView(
              padding: EdgeInsets.only(top: mq.padding.top + 12, bottom: mq.padding.bottom + 24),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Gem(size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'SAVEPOINT',
                        style: T.label.copyWith(color: C.text, letterSpacing: 3.2, fontSize: 11.5, fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      CircleBtn(Icons.search_rounded, onTap: () => push(context, const SearchScreen())),
                      const SizedBox(width: 8),
                      CircleBtn(Icons.tune_rounded, onTap: () => push(context, const SettingsScreen())),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'][now.weekday - 1]} · ${now.day} ${months[now.month - 1].toUpperCase()}',
                        style: T.label.copyWith(color: context.accent),
                      ),
                      const SizedBox(height: 10),
                      Text(_greeting(), style: T.hero.copyWith(color: C.muted, fontSize: 36)),
                      Text('${store.name}.', maxLines: 2, overflow: TextOverflow.ellipsis, style: T.hero.copyWith(fontSize: 36)),
                      if (!empty) ...[
                        const SizedBox(height: 12),
                        Text(
                          [
                            '${playing.length} in progress',
                            '${store.count(Status.backlog)} in backlog',
                            if (yearMinutes > 0) '${fmtMinutes(yearMinutes)} played in ${now.year}',
                          ].join('  ·  '),
                          style: T.small.copyWith(color: C.sub),
                        ),
                      ],
                    ],
                  ),
                ),
                if (empty)
                  _EmptyHome()
                else ...[
                  SectionHead('Now playing', kicker: 'Continue', action: playing.isEmpty ? null : 'All', onAction: () => _openLib(Status.playing)),
                  if (playing.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Card2(
                        onTap: () => push(context, const SpinScreen()),
                        child: Row(
                          children: [
                            const Icon(Icons.casino_outlined, color: C.sub),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text('Nothing on the go. Pick something from your backlog?', style: T.small.copyWith(color: C.sub, fontSize: 13.5)),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: C.muted),
                          ],
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 214,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: playing.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (_, i) =>
                            _NowPlayingCard(store.game(playing[i].gameId)!, width: playing.length == 1 ? mq.size.width - 40 : mq.size.width * 0.82),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _GoalCard(beaten: beaten, year: now.year),
                  ),
                  if (backlog.isNotEmpty) ...[
                    SectionHead('Up next', kicker: 'Backlog · ${backlog.length}', action: 'All', onAction: () => _openLib(Status.backlog)),
                    GameRail(
                      backlog.take(15).map((e) => store.game(e.gameId)).whereType<Game>().toList(),
                      tag: 'next',
                      width: 108,
                      subtitle: (g) {
                        final p = store.entry(g.id)?.priority ?? 0;
                        final h = g.mainHours;
                        return [if (p == 3) 'HIGH' else if (p == 2) 'MEDIUM', if (h != null) '~${h.round()}H'].join(' · ').ifEmpty('${g.year ?? 'TBA'}');
                      },
                    ),
                  ],
                  if (radar.isNotEmpty) ...[
                    SectionHead('Release radar', kicker: 'Coming soon', action: 'Calendar', onAction: () => push(context, const UpcomingScreen())),
                    SizedBox(
                      height: 92,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: radar.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (_, i) => RadarCard(radar[i]),
                      ),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                    child: _SpinPromo(count: backlog.length),
                  ),
                  if (store.logs.isNotEmpty) ...[
                    SectionHead('Recent activity', kicker: 'Diary', action: 'Diary', onAction: () => push(context, const DiaryScreen())),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(children: [for (final l in store.logs.take(5)) LogRow(l, monthLabel: true)]),
                    ),
                  ],
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  void _openLib(Status s) {
    LibraryScreen.filter.value = s;
    Shell.go(2);
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

class _EmptyHome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
      child: Card2(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Transform.translate(
                    offset: Offset(i * -10.0, 0),
                    child: Transform.rotate(
                      angle: (i - 1) * 0.12,
                      child: Container(
                        width: 54,
                        height: 72,
                        decoration: BoxDecoration(
                          color: [context.accent, Status.playing.color, Status.backlog.color][i].withValues(alpha: 0.85 - i * 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: C.bg, width: 2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Your shelf is empty.', style: T.h2),
            const SizedBox(height: 8),
            Text('Search for games you’ve played, are playing, or want to play. Rate them, log sessions, build lists — it all stays here.', style: T.body1),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Btn('Find a game', icon: Icons.search_rounded, expand: true, onTap: () => push(context, const SearchScreen())),
                ),
                const SizedBox(width: 10),
                Btn('Discover', ghost: true, onTap: () => Shell.go(1)),
              ],
            ),
            if (!store.igdb.configured) ...[
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => push(context, const IgdbSetupScreen()),
                child: Text(
                  'Connect IGDB first for covers & search →',
                  style: T.small.copyWith(color: context.accent, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NowPlayingCard extends StatelessWidget {
  const _NowPlayingCard(this.g, {required this.width});
  final Game g;
  final double width;
  @override
  Widget build(BuildContext context) {
    final mins = store.minutesFor(g.id);
    final last = store.lastSession(g.id);
    final live = store.session?.gameId == g.id;
    final pct = g.ttbMain == null || mins == 0 ? null : (mins * 60 / g.ttbMain!).clamp(0.0, 1.0);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final bg = g.hero != null ? img(g.hero, 't_screenshot_big') : img(g.cover, 't_cover_big');
    return Pressable(
      scale: 0.98,
      onTap: () => openGame(context, g, heroTag: 'np-${g.id}'),
      onLongPress: () => showQuickActions(context, g),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          width: width,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (bg != null)
                CachedNetworkImage(
                  imageUrl: bg,
                  fit: BoxFit.cover,
                  memCacheWidth: (width * dpr).round(),
                  errorWidget: (_, _, _) => ColoredBox(color: hueFor(g.id, l: 0.2)),
                )
              else
                ColoredBox(color: hueFor(g.id, l: 0.22)),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: 0.15), Colors.black.withValues(alpha: 0.5), Colors.black.withValues(alpha: 0.92)],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        live ? StatusBadge(Status.playing, solid: true) : const StatusBadge(Status.playing),
                        const SizedBox(width: 8),
                        Text(
                          live ? 'LIVE NOW' : (last == null ? 'NOT STARTED' : 'LAST PLAYED ${ago(last.date).toUpperCase()}'),
                          style: T.label.copyWith(fontSize: 9.5, color: C.sub),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(width: 58, child: Cover(g, radius: 8, heroTag: 'np-${g.id}')),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(g.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.h3.copyWith(fontSize: 19)),
                              const SizedBox(height: 5),
                              Text(
                                [fmtMinutes(mins, long: true), if (pct != null) '${(pct * 100).round()}% of main'].join(' · '),
                                style: T.small.copyWith(color: C.sub),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Pressable(
                          scale: 0.88,
                          onTap: () => live ? showSessionStop(context) : startSessionFlow(context, g),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(color: context.accent, shape: BoxShape.circle),
                            child: Icon(live ? Icons.stop_rounded : Icons.play_arrow_rounded, color: context.onAccent, size: 28),
                          ),
                        ),
                      ],
                    ),
                    if (pct != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(value: pct, minHeight: 4, backgroundColor: Colors.white.withValues(alpha: 0.15)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.beaten, required this.year});
  final int beaten;
  final int year;
  @override
  Widget build(BuildContext context) {
    final goal = store.goalFor(year);
    final now = DateTime.now();
    final day = now.difference(DateTime(year)).inDays + 1;
    final daysInYear = DateTime(year + 1).difference(DateTime(year)).inDays;
    final expected = goal * day / daysInYear;
    final delta = beaten - expected;
    String line;
    if (goal == 0) {
      line = 'Set a target for $year and watch the ring fill.';
    } else if (beaten >= goal) {
      line = 'Goal crushed. Raise the bar?';
    } else {
      final left = goal - beaten;
      final weeks = (daysInYear - day) / 7;
      final perWeek = weeks <= 0 ? left.toDouble() : left / weeks;
      final need = perWeek >= 1 ? '${perWeek.toStringAsFixed(1)} a week to make it' : 'one every ${(1 / perWeek).toStringAsFixed(1)} weeks to make it';
      line = delta >= 0.5
          ? '${delta.floor()} ahead of pace · $left to go'
          : delta <= -0.5
          ? '${(-delta).ceil()} behind pace — $need'
          : 'Right on pace · $left to go';
    }
    return Card2(
      onTap: () => _editGoal(context),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Ring(
            progress: goal == 0 ? 0 : beaten / goal,
            size: 96,
            stroke: 9,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$beaten', style: T.num.copyWith(fontSize: 30)),
                Text(goal == 0 ? 'BEATEN' : 'OF $goal', style: T.label.copyWith(fontSize: 8.5)),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$year CHALLENGE', style: T.label.copyWith(color: context.accent)),
                const SizedBox(height: 6),
                Text(goal == 0 ? 'No goal yet' : '$beaten / $goal games', style: T.h3),
                const SizedBox(height: 6),
                Text(line, style: T.small.copyWith(color: C.sub, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _editGoal(BuildContext context) {
    sheet(
      context,
      (c) => Watch(
        builder: (c) {
          final g = store.goalFor(year);
          return Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + MediaQuery.paddingOf(c).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$year GOAL', style: T.label.copyWith(color: c.accent)),
                const SizedBox(height: 10),
                Text('How many games will you finish?', textAlign: TextAlign.center, style: T.h2),
                const SizedBox(height: 26),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleBtn(Icons.remove_rounded, size: 54, onTap: () => store.setGoal(year, g - 1)),
                    SizedBox(
                      width: 130,
                      child: Text('$g', textAlign: TextAlign.center, style: T.hero.copyWith(fontSize: 64)),
                    ),
                    CircleBtn(Icons.add_rounded, size: 54, onTap: () => store.setGoal(year, g + 1)),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final n in [12, 24, 36, 52]) Chip2('$n', selected: g == n, onTap: () => store.setGoal(year, n)),
                  ],
                ),
                const SizedBox(height: 24),
                Btn('Done', expand: true, onTap: () => Navigator.pop(c)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class RadarCard extends StatelessWidget {
  const RadarCard(this.g, {super.key});
  final Game g;
  @override
  Widget build(BuildContext context) {
    final days = DateUtils.dateOnly(g.date!).difference(DateUtils.dateOnly(DateTime.now())).inDays;
    return Pressable(
      onTap: () => openGame(context, g),
      child: Container(
        width: 236,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: C.line),
        ),
        child: Row(
          children: [
            SizedBox(width: 50, child: Cover(g, radius: 7)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(g.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.title.copyWith(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(fmtDate(g.date!).toUpperCase(), style: T.label.copyWith(fontSize: 9)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(days <= 0 ? 'OUT' : '$days', style: T.num.copyWith(fontSize: 24, color: context.accent)),
                Text(days == 1 ? 'DAY' : 'DAYS', style: T.label.copyWith(fontSize: 8)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpinPromo extends StatelessWidget {
  const _SpinPromo({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.98,
      onTap: () => push(context, const SpinScreen()),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [context.accent, Color.lerp(context.accent, const Color(0xFF6A3CFF), 0.55)!],
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CAN’T DECIDE?', style: T.label.copyWith(color: context.onAccent.withValues(alpha: 0.7))),
                  const SizedBox(height: 6),
                  Text('Spin the backlog', style: T.h2.copyWith(color: context.onAccent)),
                  const SizedBox(height: 4),
                  Text(
                    count == 0 ? 'Add some games to your backlog first.' : 'Let fate pick from $count waiting games.',
                    style: T.small.copyWith(color: context.onAccent.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(color: context.onAccent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(18)),
              child: Icon(Icons.casino_rounded, size: 30, color: context.onAccent),
            ),
          ],
        ),
      ),
    );
  }
}
