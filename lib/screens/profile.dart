import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'diary.dart';
import 'library.dart';
import 'lists.dart';
import 'reviews.dart';
import 'search.dart';
import 'settings.dart';
import 'shell.dart';
import 'spin.dart';
import 'stats.dart';
import 'upcoming.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Watch(
      builder: (context) {
        final entries = store.entries.values;
        final finished = entries.where((e) => e.status.finished).toList()..sort((a, b) => (b.finishedAt ?? 0).compareTo(a.finishedAt ?? 0));
        final y = DateTime(DateTime.now().year).millisecondsSinceEpoch;
        final thisYear = finished.where((e) => (e.finishedAt ?? 0) >= y).length;
        final spread = List.filled(10, 0);
        for (final e in entries) {
          if (e.rating > 0) spread[e.rating - 1]++;
        }
        final since = entries.isEmpty ? null : entries.map((e) => e.addedAt).reduce((a, b) => a < b ? a : b);
        final reviews = entries.where((e) => e.review.isNotEmpty).length;
        final upcoming = entries.where((e) => store.game(e.gameId)?.upcoming == true).length;

        return Stack(
          children: [
            Positioned(top: -200, left: -120, child: Glow(size: 520, opacity: 0.18)),
            ListView(
              padding: EdgeInsets.only(top: mq.padding.top + 14, bottom: mq.padding.bottom + 24),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text('PROFILE', style: T.label.copyWith(color: context.accent, letterSpacing: 2.5)),
                      const Spacer(),
                      CircleBtn(Icons.tune_rounded, onTap: () => push(context, const SettingsScreen())),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [context.accent, Color.lerp(context.accent, const Color(0xFF6A3CFF), 0.6)!],
                          ),
                        ),
                        child: Text(store.name.characters.first.toUpperCase(), style: T.hero.copyWith(color: context.onAccent, fontSize: 38)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(store.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.h1.copyWith(fontSize: 28)),
                            const SizedBox(height: 6),
                            Text(since == null ? 'NEW SAVE FILE' : 'LOGGING SINCE ${fmtMs(since).toUpperCase()}', style: T.label),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Card2(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 6),
                    child: Row(
                      children: [
                        _Num('${finished.length}', 'Finished', () => push(context, const StatsScreen())),
                        _div(),
                        _Num('$thisYear', '${DateTime.now().year}', () => push(context, const StatsScreen())),
                        _div(),
                        _Num('${store.count(Status.backlog)}', 'Backlog', () {
                          LibraryScreen.filter.value = Status.backlog;
                          Shell.go(2);
                        }),
                        _div(),
                        _Num(fmtMinutes(store.totalMinutes), 'Hours', () => push(context, const StatsScreen())),
                      ],
                    ),
                  ),
                ),
                SectionHead('Top five', kicker: 'All-time favourites', action: store.favs.isEmpty ? null : 'Edit', onAction: () => _editFavs(context)),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: _Favs()),
                const SectionHead('Ratings', kicker: 'Your taste'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Card2(child: RatingSpread(counts: spread)),
                ),
                const SectionHead('Your save file', kicker: 'Everything'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.count(
                    padding: EdgeInsets.zero,
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.55,
                    children: [
                      _Tile(
                        Icons.auto_stories_rounded,
                        'Diary',
                        '${store.logs.length} entries',
                        const Color(0xFF4FD8E8),
                        () => push(context, const DiaryScreen()),
                      ),
                      _Tile(Icons.insights_rounded, 'Stats', 'Year in review', context.accent, () => push(context, const StatsScreen())),
                      _Tile(Icons.rate_review_rounded, 'Reviews', '$reviews written', const Color(0xFFB4F25A), () => push(context, const ReviewsScreen())),
                      _Tile(
                        Icons.format_list_bulleted_rounded,
                        'Lists',
                        '${store.lists.length} lists',
                        const Color(0xFFA48BFF),
                        () => push(context, const ListsScreen()),
                      ),
                      _Tile(Icons.event_rounded, 'Release radar', '$upcoming upcoming', const Color(0xFFFF7EB9), () => push(context, const UpcomingScreen())),
                      _Tile(Icons.casino_rounded, 'Pick for me', 'Spin the backlog', C.gold, () => push(context, const SpinScreen())),
                    ],
                  ),
                ),
                if (finished.isNotEmpty) ...[
                  const SectionHead('Recently finished', kicker: 'Credits rolled'),
                  GameRail(
                    finished.take(15).map((e) => store.game(e.gameId)).whereType<Game>().toList(),
                    tag: 'fin',
                    width: 104,
                    subtitle: (g) => fmtMs(store.entry(g.id)?.finishedAt).toUpperCase(),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _div() => Container(width: 1, height: 34, color: C.line);

  void _editFavs(BuildContext context) {
    sheet(
      context,
      (c) => Watch(
        builder: (c) {
          final favs = store.favs;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.paddingOf(c).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reorder your top five', style: T.h3),
                const SizedBox(height: 4),
                Text('Drag to rearrange. Swipe to remove.', style: T.small),
                const SizedBox(height: 12),
                ReorderableListView(
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  onReorderItem: (a, b) {
                    final f = List<int>.from(favs);
                    f.insert(b, f.removeAt(a));
                    store.setFavs(f);
                  },
                  children: [
                    for (var i = 0; i < favs.length; i++)
                      Dismissible(
                        key: ValueKey(favs[i]),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => store.setFavs(List<int>.from(favs)..removeAt(i)),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF5D5D)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Text('${i + 1}', style: T.num.copyWith(fontSize: 22, color: c.accent)),
                              const SizedBox(width: 14),
                              SizedBox(
                                width: 40,
                                child: Cover(store.game(favs[i]) ?? Game(id: favs[i], name: '?'), radius: 6),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(store.game(favs[i])?.name ?? '?', style: T.title)),
                              ReorderableDragStartListener(
                                index: i,
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.drag_indicator_rounded, color: C.muted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Num extends StatelessWidget {
  const _Num(this.v, this.l, this.onTap);
  final String v;
  final String l;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Pressable(
      onTap: onTap,
      child: Column(
        children: [
          FittedBox(child: Text(v, style: T.num.copyWith(fontSize: 26))),
          const SizedBox(height: 5),
          Text(l.toUpperCase(), style: T.label.copyWith(fontSize: 9)),
        ],
      ),
    ),
  );
}

class _Favs extends StatelessWidget {
  const _Favs();
  @override
  Widget build(BuildContext context) {
    final favs = store.favs;
    return Row(
      children: [
        for (var i = 0; i < 5; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: i < favs.length && store.game(favs[i]) != null
                ? GameTile(store.game(favs[i])!, tagPrefix: 'fav', meta: false, badges: false)
                : Pressable(
                    onTap: () async {
                      final g = await push<Game>(context, const SearchScreen(pick: true, title: 'Pick a favourite'));
                      if (g != null) store.setFav(favs.length, g);
                    },
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: C.surface,
                          border: Border.all(color: C.line),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded, color: i == favs.length ? context.accent : C.faint),
                            const SizedBox(height: 2),
                            Text('${i + 1}', style: T.label.copyWith(fontSize: 9)),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.icon, this.title, this.sub, this.color, this.onTap);
  final IconData icon;
  final String title;
  final String sub;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Card2(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: color, size: 19),
          ),
          const Spacer(),
          Text(title, style: T.h3.copyWith(fontSize: 16)),
          const SizedBox(height: 2),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small.copyWith(fontSize: 11.5)),
        ],
      ),
    );
  }
}
