import 'dart:math';

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int? year = DateTime.now().year;
  bool hoursMode = false;

  List<int> _years() {
    final s = <int>{DateTime.now().year};
    for (final l in store.logs) {
      s.add(l.when.year);
    }
    for (final e in store.entries.values) {
      if (e.finishedAt != null) s.add(DateTime.fromMillisecondsSinceEpoch(e.finishedAt!).year);
    }
    return s.toList()..sort((a, b) => b.compareTo(a));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: Watch(
        builder: (context) {
          final years = _years();
          final s = _Stats(year);
          return ListView(
            padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 40),
            children: [
              SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  children: [
                    for (final y in years)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip2('$y', selected: year == y, onTap: () => setState(() => year = y)),
                      ),
                    Chip2('All time', selected: year == null, onTap: () => setState(() => year = null)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(year == null ? 'ALL TIME' : 'YEAR IN REVIEW', style: T.label.copyWith(color: context.accent, letterSpacing: 2.2)),
                    const SizedBox(height: 8),
                    Text(year == null ? 'Your whole\nsave file.' : '$year\nin games.', style: T.hero.copyWith(fontSize: 44)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                child: Card2(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: StatBlock('${s.finished.length}', 'games finished', color: context.accent)),
                          Expanded(child: StatBlock(fmtMinutes(s.minutes), 'played')),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: StatBlock('${s.sessions.length}', 'sessions')),
                          Expanded(child: StatBlock(s.avgRating == 0 ? '—' : s.avgRating.toStringAsFixed(2), 'avg rating', color: C.gold)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: StatBlock('${s.started}', 'games started')),
                          Expanded(child: StatBlock('${s.dropped}', 'abandoned', color: s.dropped > 0 ? Status.dropped.color : null)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              _Section(
                title: hoursMode ? 'Hours by ${year == null ? 'year' : 'month'}' : 'Finished by ${year == null ? 'year' : 'month'}',
                kicker: 'Rhythm',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip2('Games', selected: !hoursMode, onTap: () => setState(() => hoursMode = false)),
                    const SizedBox(width: 6),
                    Chip2('Hours', selected: hoursMode, onTap: () => setState(() => hoursMode = true)),
                  ],
                ),
                child: Bars(
                  values: hoursMode ? s.bucketMinutes.map((m) => m / 60).toList() : s.bucketFinished.map((e) => e.toDouble()).toList(),
                  labels: s.bucketLabels,
                  highlight: year == DateTime.now().year ? DateTime.now().month - 1 : null,
                  format: hoursMode ? (v) => v < 10 ? v.toStringAsFixed(1) : v.round().toString() : null,
                ),
              ),
              _Section(
                title: 'Activity',
                kicker: 'Every session',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Heatmap(minutesByDay: s.days, end: year == null || year == DateTime.now().year ? DateTime.now() : DateTime(year!, 12, 31)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: StatBlock('${s.longestStreak}d', 'longest streak')),
                        Expanded(child: StatBlock(fmtMinutes(s.longestSession), 'longest session')),
                        Expanded(child: StatBlock('${s.activeDays}', 'days played')),
                      ],
                    ),
                  ],
                ),
              ),
              if (s.weekday.any((m) => m > 0))
                _Section(
                  title: 'When you play',
                  kicker: 'Weekdays',
                  child: Bars(
                    values: s.weekday.map((m) => m / 60).toList(),
                    labels: wd.map((d) => d.substring(0, 2)).toList(),
                    height: 100,
                    format: (v) => '${v.round()}h',
                  ),
                ),
              _Section(
                title: 'Top genres',
                kicker: 'Taste',
                child: RankBars(items: s.genres),
              ),
              if (s.platforms.isNotEmpty)
                _Section(
                  title: 'Platforms',
                  kicker: 'Hardware',
                  child: RankBars(items: s.platforms, color: Status.playing.color),
                ),
              if (s.mostPlayed.isNotEmpty)
                _Section(
                  title: 'Most played',
                  kicker: 'Time sinks',
                  child: Column(
                    children: [
                      for (var i = 0; i < s.mostPlayed.length; i++)
                        Pressable(
                          onTap: () => openGame(context, s.mostPlayed[i].key),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 26,
                                  child: Text('${i + 1}', style: T.num.copyWith(fontSize: 18, color: i == 0 ? context.accent : C.muted)),
                                ),
                                SizedBox(width: 38, child: Cover(s.mostPlayed[i].key, radius: 5)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(s.mostPlayed[i].key.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.title.copyWith(fontSize: 14)),
                                ),
                                Text(fmtMinutes(s.mostPlayed[i].value), style: T.label.copyWith(color: C.text, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (s.topRated.isNotEmpty) ...[
                SectionHead('Highest rated', kicker: year == null ? 'All time' : 'Finished in $year'),
                GameRail(s.topRated, tag: 'st', width: 100, subtitle: (g) => stars(store.entry(g.id)?.rating ?? 0)),
              ],
              _Section(
                title: 'Rating spread',
                kicker: 'Generosity',
                child: RatingSpread(counts: s.spread),
              ),
              if (s.decades.isNotEmpty)
                _Section(
                  title: 'Release eras',
                  kicker: 'Retro vs. new',
                  child: Bars(
                    values: s.decades.map((e) => e.value.toDouble()).toList(),
                    labels: s.decades.map((e) => "'${e.key.toString().substring(2)}s").toList(),
                    height: 90,
                    color: C.gold,
                  ),
                ),
              _Section(title: 'Library', kicker: 'Status breakdown', child: const _StatusBreakdown()),
              _Section(title: 'Backlog forecast', kicker: 'The pile', child: const _Forecast()),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.kicker, required this.child, this.trailing});
  final String title;
  final String kicker;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: SectionHead(title, kicker: kicker)),
            if (trailing != null) Padding(padding: const EdgeInsets.only(right: 20, top: 30), child: trailing),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Card2(child: child),
        ),
      ],
    );
  }
}

class _Stats {
  _Stats(int? year) {
    final now = DateTime.now();
    final from = year == null ? 0 : DateTime(year).millisecondsSinceEpoch;
    final to = year == null ? 1 << 62 : DateTime(year + 1).millisecondsSinceEpoch;
    bool inP(int? ms) => ms != null && ms >= from && ms < to;

    final logs = store.logs.where((l) => inP(l.date)).toList();
    sessions = logs.where((l) => l.kind == LogKind.session).toList();
    minutes = sessions.fold<int>(0, (a, l) => a + l.minutes);
    if (year == null) {
      for (final e in store.entries.values) {
        minutes += e.baseMinutes;
      }
    }
    finished = store.entries.values.where((e) => e.status.finished && inP(e.finishedAt)).toList();
    started = logs.where((l) => l.kind == LogKind.started).map((l) => l.gameId).toSet().length;
    dropped = logs.where((l) => l.kind == LogKind.dropped).map((l) => l.gameId).toSet().length;

    final rated = (year == null ? store.entries.values.where((e) => e.rating > 0) : finished.where((e) => e.rating > 0)).toList();
    for (final e in rated) {
      spread[e.rating - 1]++;
    }
    avgRating = rated.isEmpty ? 0 : rated.fold<int>(0, (a, e) => a + e.rating) / rated.length / 2;

    // buckets
    if (year != null) {
      bucketLabels = mon.map((m) => m.substring(0, 1)).toList();
      bucketFinished = List.filled(12, 0);
      bucketMinutes = List.filled(12, 0);
      for (final e in finished) {
        bucketFinished[DateTime.fromMillisecondsSinceEpoch(e.finishedAt!).month - 1]++;
      }
      for (final l in sessions) {
        bucketMinutes[l.when.month - 1] += l.minutes;
      }
    } else {
      final ys = <int>{now.year};
      for (final e in finished) {
        ys.add(DateTime.fromMillisecondsSinceEpoch(e.finishedAt!).year);
      }
      for (final l in sessions) {
        ys.add(l.when.year);
      }
      final minY = max(ys.reduce(min), now.year - 9);
      final range = [for (var y = minY; y <= now.year; y++) y];
      bucketLabels = range.map((y) => "'${y.toString().substring(2)}").toList();
      bucketFinished = List.filled(range.length, 0);
      bucketMinutes = List.filled(range.length, 0);
      for (final e in finished) {
        final i = DateTime.fromMillisecondsSinceEpoch(e.finishedAt!).year - minY;
        if (i >= 0) bucketFinished[i]++;
      }
      for (final l in sessions) {
        final i = l.when.year - minY;
        if (i >= 0) bucketMinutes[i] += l.minutes;
      }
    }

    // days / streaks / weekdays
    for (final l in sessions) {
      final d = DateUtils.dateOnly(l.when);
      days[d] = (days[d] ?? 0) + l.minutes;
      weekday[l.when.weekday - 1] += l.minutes;
      longestSession = max(longestSession, l.minutes);
    }
    activeDays = days.length;
    final sortedDays = days.keys.toList()..sort();
    var run = 0;
    DateTime? prev;
    for (final d in sortedDays) {
      run = prev != null && DateTime(prev.year, prev.month, prev.day + 1) == d ? run + 1 : 1;
      longestStreak = max(longestStreak, run);
      prev = d;
    }

    // played set: finished in period or has sessions in period
    final played = <int>{...finished.map((e) => e.gameId), ...sessions.map((l) => l.gameId)};
    final gc = <String, int>{};
    final pc = <String, int>{};
    for (final id in played) {
      final g = store.game(id);
      for (final x in g?.genres ?? const <String>[]) {
        gc[x] = (gc[x] ?? 0) + 1;
      }
      final p = store.entry(id)?.platform;
      if (p != null) pc[p] = (pc[p] ?? 0) + 1;
    }
    genres = gc.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    platforms = pc.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final pm = <int, int>{};
    for (final l in sessions) {
      pm[l.gameId] = (pm[l.gameId] ?? 0) + l.minutes;
    }
    if (year == null) {
      for (final e in store.entries.values) {
        if (e.baseMinutes > 0) pm[e.gameId] = (pm[e.gameId] ?? 0) + e.baseMinutes;
      }
    }
    final mp = pm.entries.where((e) => store.game(e.key) != null).toList()..sort((a, b) => b.value.compareTo(a.value));
    mostPlayed = mp.take(5).map((e) => MapEntry(store.game(e.key)!, e.value)).toList();

    final tr = (year == null ? store.entries.values.where((e) => e.rating > 0) : finished.where((e) => e.rating > 0)).toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));
    topRated = tr.take(12).map((e) => store.game(e.gameId)).whereType<Game>().toList();

    final dc = <int, int>{};
    for (final e in (year == null ? store.entries.values.where((e) => e.status.finished) : finished)) {
      final y = store.game(e.gameId)?.year;
      if (y != null) dc[(y ~/ 10) * 10] = (dc[(y ~/ 10) * 10] ?? 0) + 1;
    }
    decades = dc.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  }

  late List<LogItem> sessions;
  int minutes = 0;
  late List<Entry> finished;
  int started = 0;
  int dropped = 0;
  final spread = List.filled(10, 0);
  double avgRating = 0;
  late List<String> bucketLabels;
  late List<int> bucketFinished;
  late List<int> bucketMinutes;
  final days = <DateTime, int>{};
  final weekday = List.filled(7, 0);
  int longestSession = 0;
  int longestStreak = 0;
  int activeDays = 0;
  late List<MapEntry<String, int>> genres;
  late List<MapEntry<String, int>> platforms;
  late List<MapEntry<Game, int>> mostPlayed;
  late List<Game> topRated;
  late List<MapEntry<int, int>> decades;
}

class _StatusBreakdown extends StatelessWidget {
  const _StatusBreakdown();
  @override
  Widget build(BuildContext context) {
    final total = store.entries.length;
    if (total == 0) return Text('Nothing logged yet', style: T.small);
    final counts = [for (final s in Status.values) (s, store.count(s))].where((e) => e.$2 > 0).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                for (final c in counts)
                  Expanded(
                    flex: c.$2,
                    child: Container(color: c.$1.color, margin: const EdgeInsets.only(right: 2)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 10,
          children: [
            for (final c in counts)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(color: c.$1.color, borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 6),
                  Text('${c.$1.label} ', style: T.small.copyWith(color: C.sub)),
                  Text('${c.$2}', style: T.label.copyWith(color: C.text)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text('Completion rate ${(_rate() * 100).round()}% — of games you started, how many you saw through.', style: T.small),
      ],
    );
  }

  double _rate() {
    final fin = store.entries.values.where((e) => e.status.finished).length;
    final quit = store.count(Status.dropped) + store.count(Status.shelved);
    return fin + quit == 0 ? 0 : fin / (fin + quit);
  }
}

class _Forecast extends StatelessWidget {
  const _Forecast();
  @override
  Widget build(BuildContext context) {
    final backlog = store.withStatus(Status.backlog).map((e) => store.game(e.gameId)).whereType<Game>().toList();
    final known = backlog.where((g) => g.ttbMain != null).toList();
    final hours = known.fold<double>(0, (a, g) => a + g.mainHours!);
    final avgKnown = known.isEmpty ? 15.0 : hours / known.length;
    final est = hours + (backlog.length - known.length) * avgKnown;
    final since = DateTime.now().subtract(const Duration(days: 90)).millisecondsSinceEpoch;
    final recent = store.logs.where((l) => l.kind == LogKind.session && l.date >= since).fold<int>(0, (a, l) => a + l.minutes) / 60;
    final perWeek = recent / (90 / 7);
    final weeks = perWeek <= 0 ? null : est / perWeek;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: StatBlock('${backlog.length}', 'games waiting')),
            Expanded(child: StatBlock('~${est.round()}h', 'to clear')),
            Expanded(child: StatBlock(perWeek == 0 ? '—' : '${perWeek.toStringAsFixed(1)}h', 'per week')),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          backlog.isEmpty
              ? 'Backlog cleared. Truly a legend.'
              : weeks == null
              ? 'Log a few sessions and we’ll forecast when you’ll clear the pile.'
              : 'At your recent pace, you’d clear the backlog in ${weeks < 52 ? '${weeks.round()} weeks' : '${(weeks / 52).toStringAsFixed(1)} years'} — assuming you buy nothing new. (You will.)',
          style: T.small.copyWith(color: C.sub, fontSize: 13),
        ),
      ],
    );
  }
}
