import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';

/// Release calendar for games you're tracking.
class UpcomingScreen extends StatelessWidget {
  const UpcomingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Release radar')),
      body: Watch(
        builder: (context) {
          final now = DateTime.now();
          final tracked = store.entries.values.map((e) => store.game(e.gameId)).whereType<Game>().toList();
          final upcoming = tracked.where((g) => g.upcoming).toList()..sort((a, b) => a.released!.compareTo(b.released!));
          final justOut =
              tracked
                  .where((g) => !g.upcoming && g.date != null && now.difference(g.date!).inDays <= 45 && (store.entry(g.id)?.status.unplayed ?? false))
                  .toList()
                ..sort((a, b) => b.released!.compareTo(a.released!));
          final tba = tracked.where((g) => g.released == null && (store.entry(g.id)?.status.unplayed ?? false)).toList();

          final groups = <(int, int), List<Game>>{};
          for (final g in upcoming) {
            groups.putIfAbsent((g.date!.year, g.date!.month), () => []).add(g);
          }

          if (upcoming.isEmpty && justOut.isEmpty && tba.isEmpty) {
            return const Center(
              child: EmptyState(title: 'Radar is quiet', body: 'Wishlist an unreleased game and it’ll show up here with a countdown.'),
            );
          }

          return ListView(
            padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.paddingOf(context).bottom + 30),
            children: [
              if (justOut.isNotEmpty) ...[
                _Head('Out now', 'Recently released from your wishlist', color: Status.completed.color),
                for (final g in justOut) _Row(g, out: true),
              ],
              for (final k in groups.keys) ...[
                _Head('${months[k.$2 - 1]} ${k.$1}', '${groups[k]!.length} ${groups[k]!.length == 1 ? 'release' : 'releases'}'),
                for (final g in groups[k]!) _Row(g),
              ],
              if (tba.isNotEmpty) ...[const _Head('Someday', 'No date announced'), for (final g in tba) _Row(g)],
            ],
          );
        },
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.t, this.sub, {this.color});
  final String t;
  final String sub;
  final Color? color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(t, style: T.h2.copyWith(color: color)),
        const Spacer(),
        Text(sub.toUpperCase(), style: T.label.copyWith(fontSize: 9)),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row(this.g, {this.out = false});
  final Game g;
  final bool out;
  @override
  Widget build(BuildContext context) {
    final e = store.entry(g.id);
    final d = g.date;
    final days = d == null ? null : DateUtils.dateOnly(d).difference(DateUtils.dateOnly(DateTime.now())).inDays;
    return Pressable(
      scale: 0.98,
      onTap: () => openGame(context, g),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: out ? Status.completed.color.withValues(alpha: 0.5) : C.line),
        ),
        child: Row(
          children: [
            if (d != null)
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: C.raised, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Text(mon[d.month - 1], style: T.label.copyWith(fontSize: 9, color: context.accent)),
                    Text('${d.day}', style: T.num.copyWith(fontSize: 22)),
                  ],
                ),
              ),
            if (d != null) const SizedBox(width: 12),
            SizedBox(width: 44, child: Cover(g, radius: 6)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.title.copyWith(fontSize: 14)),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      if (e != null) StatusBadge(e.status),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(g.platforms.take(3).join(', '), maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small.copyWith(fontSize: 11.5)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (days != null)
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 4),
                child: Text(
                  out ? relDays(d!).toUpperCase() : (days == 0 ? 'TODAY' : '${days}D'),
                  style: T.label.copyWith(color: out ? Status.completed.color : C.text, fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
