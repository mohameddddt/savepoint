import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'log_sheet.dart';
import 'search.dart';

const _sorts = <(String, String)>[
  ('recent', 'Recently updated'),
  ('added', 'Date added'),
  ('finished', 'Date finished'),
  ('title', 'Title A–Z'),
  ('rating', 'Your rating'),
  ('released', 'Release date'),
  ('time', 'Time played'),
  ('priority', 'Priority'),
];

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  static final filter = ValueNotifier<Status?>(null);
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final qc = TextEditingController();
  bool searching = false;
  String q = '';
  bool liked = false;
  bool reviewed = false;
  final plats = <String>{};
  final genres = <String>{};
  final tags = <String>{};

  String get sort => store.kv['lib_sort'] ?? 'recent';
  bool get grid => store.kv['lib_view'] != 'list';
  int get filterCount => plats.length + genres.length + tags.length + (reviewed ? 1 : 0);

  @override
  void dispose() {
    qc.dispose();
    super.dispose();
  }

  List<Entry> _apply(Status? s) {
    final lq = q.trim().toLowerCase();
    final list = store.entries.values.where((e) {
      if (s != null && e.status != s) return false;
      if (liked && !e.liked) return false;
      if (reviewed && e.review.isEmpty) return false;
      final g = store.game(e.gameId);
      if (g == null) return false;
      if (lq.isNotEmpty && !g.name.toLowerCase().contains(lq) && !e.tags.any((t) => t.contains(lq))) return false;
      if (plats.isNotEmpty && !(plats.contains(e.platform) || g.platforms.any(plats.contains))) return false;
      if (genres.isNotEmpty && !g.genres.any(genres.contains)) return false;
      if (tags.isNotEmpty && !e.tags.any(tags.contains)) return false;
      return true;
    }).toList();
    int byName(Entry a, Entry b) => (store.game(a.gameId)?.name ?? '').toLowerCase().compareTo((store.game(b.gameId)?.name ?? '').toLowerCase());
    switch (sort) {
      case 'added':
        list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      case 'finished':
        list.sort((a, b) => (b.finishedAt ?? 0).compareTo(a.finishedAt ?? 0));
      case 'title':
        list.sort(byName);
      case 'rating':
        list.sort((a, b) {
          final c = b.rating.compareTo(a.rating);
          return c != 0 ? c : byName(a, b);
        });
      case 'released':
        list.sort((a, b) => (store.game(b.gameId)?.released ?? 0).compareTo(store.game(a.gameId)?.released ?? 0));
      case 'time':
        list.sort((a, b) => store.minutesFor(b.gameId).compareTo(store.minutesFor(a.gameId)));
      case 'priority':
        list.sort((a, b) {
          final c = b.priority.compareTo(a.priority);
          return c != 0 ? c : a.addedAt.compareTo(b.addedAt);
        });
      default:
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return ValueListenableBuilder<Status?>(
      valueListenable: LibraryScreen.filter,
      builder: (context, status, _) => Watch(
        builder: (context) {
          final items = _apply(status);
          final counts = {for (final s in Status.values) s: store.count(s)};
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, mq.padding.top + 18, 14, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${store.entries.length} GAMES · ${fmtMinutes(store.totalMinutes).toUpperCase()}',
                              style: T.label.copyWith(color: context.accent, letterSpacing: 2),
                            ),
                            const SizedBox(height: 8),
                            Text('Library', style: T.hero.copyWith(fontSize: 38)),
                          ],
                        ),
                      ),
                      CircleBtn(
                        searching ? Icons.close_rounded : Icons.search_rounded,
                        onTap: () => setState(() {
                          searching = !searching;
                          if (!searching) {
                            qc.clear();
                            q = '';
                          }
                        }),
                      ),
                      const SizedBox(width: 8),
                      _SortMenu(value: sort),
                      const SizedBox(width: 8),
                      CircleBtn(
                        grid ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
                        onTap: () {
                          tick();
                          store.setPref('lib_view', grid ? 'list' : 'grid');
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (searching)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: TextField(
                      controller: qc,
                      autofocus: true,
                      onChanged: (v) => setState(() => q = v),
                      decoration: const InputDecoration(
                        hintText: 'Filter by title or #tag',
                        prefixIcon: Icon(Icons.search_rounded, color: C.muted),
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 62,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    children: [
                      _gap(
                        Chip2(
                          'All',
                          count: store.entries.length,
                          selected: status == null && !liked,
                          onTap: () {
                            liked = false;
                            LibraryScreen.filter.value = null;
                            setState(() {});
                          },
                        ),
                      ),
                      for (final s in Status.values)
                        if (counts[s]! > 0)
                          _gap(
                            Chip2(
                              s.label,
                              count: counts[s],
                              color: s.color,
                              selected: status == s,
                              onTap: () => LibraryScreen.filter.value = status == s ? null : s,
                            ),
                          ),
                      _gap(Chip2('Liked', icon: Icons.favorite_rounded, color: C.heart, selected: liked, onTap: () => setState(() => liked = !liked))),
                      _gap(
                        Chip2(filterCount == 0 ? 'Filters' : 'Filters · $filterCount', icon: Icons.tune_rounded, selected: filterCount > 0, onTap: _filters),
                      ),
                    ],
                  ),
                ),
              ),
              if (store.entries.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(
                    title: 'Nothing on the shelf',
                    body: 'Every game you log, rate or wishlist lands here.',
                    action: 'Find a game',
                    onAction: () => push(context, const SearchScreen()),
                  ),
                )
              else if (items.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(title: 'No matches', body: 'Try a different status or clear filters.'),
                )
              else if (grid)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.5,
                    ),
                    delegate: SliverChildBuilderDelegate((_, i) {
                      final e = items[i];
                      final g = store.game(e.gameId)!;
                      return GameTile(g, tagPrefix: 'lib', subtitle: _sub(e, g));
                    }, childCount: items.length),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                  sliver: SliverList.builder(itemCount: items.length, itemBuilder: (_, i) => _LibRow(items[i])),
                ),
              SliverToBoxAdapter(child: SizedBox(height: mq.padding.bottom + 24)),
            ],
          );
        },
      ),
    );
  }

  String _sub(Entry e, Game g) {
    switch (sort) {
      case 'time':
        return fmtMinutes(store.minutesFor(g.id)).toUpperCase();
      case 'finished':
        return e.finishedAt == null ? '—' : fmtMs(e.finishedAt).toUpperCase();
      case 'added':
        return 'ADDED ${fmtMs(e.addedAt, year: false).toUpperCase()}';
      case 'priority':
        return const ['', 'LOW', 'MEDIUM', 'HIGH'][e.priority].ifEmpty(g.year?.toString() ?? 'TBA');
      default:
        return '${g.year ?? 'TBA'}${e.platform != null ? ' · ${e.platform}' : ''}';
    }
  }

  Widget _gap(Widget w) => Padding(padding: const EdgeInsets.only(right: 8), child: w);

  void _filters() {
    final allPlats = <String>{};
    final allGenres = <String>{};
    final allTags = <String>{};
    for (final e in store.entries.values) {
      if (e.platform != null) allPlats.add(e.platform!);
      final g = store.game(e.gameId);
      if (g != null) allGenres.addAll(g.genres);
      allTags.addAll(e.tags);
    }
    if (allPlats.isEmpty) {
      for (final e in store.entries.values) {
        allPlats.addAll(store.game(e.gameId)?.platforms ?? const []);
      }
    }
    sheet(
      context,
      (c) => StatefulBuilder(
        builder: (c, set) {
          void upd(VoidCallback f) {
            set(f);
            setState(() {});
          }

          Widget group(String label, Set<String> all, Set<String> sel) {
            if (all.isEmpty) return const SizedBox();
            final sorted = all.toList()..sort();
            return Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Labeled(
                label,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final p in sorted) Chip2(p, selected: sel.contains(p), onTap: () => upd(() => sel.contains(p) ? sel.remove(p) : sel.add(p)))],
                ),
              ),
            );
          }

          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.8),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.paddingOf(c).bottom),
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Filters', style: T.h2)),
                    TextButton(
                      onPressed: () => upd(() {
                        plats.clear();
                        genres.clear();
                        tags.clear();
                        reviewed = false;
                      }),
                      child: const Text('Clear all', style: TextStyle(color: C.sub)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Chip2('Has a review', icon: Icons.rate_review_outlined, selected: reviewed, onTap: () => upd(() => reviewed = !reviewed)),
                ),
                group('Platform', allPlats, plats),
                group('Genre', allGenres, genres),
                group('Tags', allTags.map((t) => t).toSet(), tags),
                Btn('Show results', expand: true, onTap: () => Navigator.pop(c)),
              ],
            ),
          );
        },
      ),
    );
  }
}

extension on String {
  String ifEmpty(String o) => isEmpty ? o : this;
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.value});
  final String value;
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      onSelected: (v) => store.setPref('lib_sort', v),
      itemBuilder: (_) => [
        for (final s in _sorts)
          PopupMenuItem(
            value: s.$1,
            child: Row(
              children: [
                Expanded(child: Text(s.$2)),
                if (s.$1 == value) Icon(Icons.check_rounded, size: 18, color: context.accent),
              ],
            ),
          ),
      ],
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: C.raised,
          shape: BoxShape.circle,
          border: Border.all(color: C.line),
        ),
        child: const Icon(Icons.swap_vert_rounded, size: 20),
      ),
    );
  }
}

class _LibRow extends StatelessWidget {
  const _LibRow(this.e);
  final Entry e;
  @override
  Widget build(BuildContext context) {
    final g = store.game(e.gameId)!;
    final mins = store.minutesFor(g.id);
    return Pressable(
      scale: 0.98,
      onTap: () => openGame(context, g, heroTag: 'lr-${g.id}'),
      onLongPress: () => showQuickActions(context, g),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 64,
              decoration: BoxDecoration(color: e.status.color, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 10),
            SizedBox(width: 50, child: Cover(g, radius: 7, heroTag: 'lr-${g.id}')),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.title.copyWith(fontSize: 14.5)),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      StatusBadge(e.status),
                      const SizedBox(width: 8),
                      StarRow(e.rating, size: 12),
                      if (e.liked) ...[const SizedBox(width: 6), const Icon(Icons.favorite_rounded, size: 12, color: C.heart)],
                      if (e.review.isNotEmpty) ...[const SizedBox(width: 6), const Icon(Icons.notes_rounded, size: 13, color: C.muted)],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    [
                      g.year?.toString() ?? 'TBA',
                      ?e.platform,
                      if (mins > 0) fmtMinutes(mins),
                      if (e.status.unplayed && g.mainHours != null) '~${g.mainHours!.round()}h to beat',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.small,
                  ),
                ],
              ),
            ),
            if (e.priority > 0 && e.status.unplayed)
              Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Container(
                      margin: const EdgeInsets.only(left: 3),
                      width: 5,
                      height: 14,
                      decoration: BoxDecoration(color: i < e.priority ? context.accent : C.high, borderRadius: BorderRadius.circular(2)),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
