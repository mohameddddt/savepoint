import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../igdb.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/rating.dart';
import 'gallery.dart';
import 'log_sheet.dart';

class GameDetailScreen extends StatefulWidget {
  const GameDetailScreen({super.key, required this.game, this.heroTag});
  final Game game;
  final Object? heroTag;
  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  late Game g = store.igdb.cachedDetail(widget.game.id) ?? store.game(widget.game.id) ?? widget.game;
  bool loading = false;
  String? error;
  bool expanded = false;
  final scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    if (!g.full && !g.manual && store.igdb.configured) _load();
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final full = await store.igdb.details(widget.game.id);
      if (!mounted) return;
      store.refreshSnapshot(full);
      setState(() => g = full);
    } on IgdbError catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (e) {
      if (mounted) setState(() => error = 'Could not load details');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Scaffold(
      body: Watch(
        builder: (context) {
          final e = store.entry(g.id);
          return Stack(
            children: [
              CustomScrollView(
                controller: scroll,
                slivers: [
                  SliverToBoxAdapter(child: _header(context, mq)),
                  SliverToBoxAdapter(child: _actions(context, e)),
                  if (e != null) SliverToBoxAdapter(child: _yourLog(context, e)),
                  ..._body(context, e),
                  SliverToBoxAdapter(child: SizedBox(height: mq.padding.bottom + 40)),
                ],
              ),
              _TopBar(
                scroll: scroll,
                game: g,
                onRefresh: g.manual
                    ? null
                    : () {
                        store.igdb.forget(g.id);
                        _load();
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, MediaQueryData mq) {
    final hero = g.arts.isNotEmpty ? img(g.arts.first, 't_screenshot_huge') : (g.shots.isNotEmpty ? img(g.shots.first, 't_screenshot_huge') : g.heroUrl);
    const h = 300.0;
    return SizedBox(
      height: h + 150,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: h,
            child: AnimatedBuilder(
              animation: scroll,
              builder: (_, child) {
                final o = scroll.hasClients ? scroll.offset : 0.0;
                return Transform.translate(offset: Offset(0, o < 0 ? o : o * 0.45), child: child);
              },
              child: hero == null
                  ? DecoratedBox(
                      decoration: BoxDecoration(gradient: LinearGradient(colors: [hueFor(g.id), C.bg])),
                    )
                  : CachedNetworkImage(
                      imageUrl: hero,
                      fit: BoxFit.cover,
                      memCacheWidth: (mq.size.width * mq.devicePixelRatio).round(),
                      fadeInDuration: const Duration(milliseconds: 250),
                      placeholder: (_, _) => const ColoredBox(color: C.surface),
                      errorWidget: (_, _, _) => const ColoredBox(color: C.surface),
                    ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.25, 0.62, 0.78],
                  colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent, C.bg.withValues(alpha: 0.85), C.bg],
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 4,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 116,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 24, offset: const Offset(0, 10))],
                    ),
                    child: Cover(g, heroTag: widget.heroTag, radius: 12, size: 't_cover_big_2x'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (g.type != null && g.type != 'Main Game') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            border: Border.all(color: C.sub),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(g.type!.toUpperCase(), style: T.label.copyWith(fontSize: 9, color: C.sub)),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        g.name,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: T.h1.copyWith(fontSize: g.name.length > 28 ? 24 : 29),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        [if (g.year != null) '${g.year}' else 'TBA', if (g.dev.isNotEmpty) g.dev].join('  ·  ').toUpperCase(),
                        maxLines: 2,
                        style: T.label.copyWith(color: C.sub),
                      ),
                      if (g.score != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _ScorePill(g.score!),
                            if (g.ratingCount != null) ...[const SizedBox(width: 8), Text('${g.ratingCount} ratings', style: T.small.copyWith(fontSize: 11.5))],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, Entry? e) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final s in Status.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _StatusPill(
                      s,
                      selected: e?.status == s,
                      onTap: () {
                        tick();
                        if (e?.status == s) {
                          showLogEditor(context, g);
                          return;
                        }
                        store.setStatus(g, s);
                        if (s.finished) {
                          toast(
                            context,
                            s == Status.mastered ? '100% — legendary.' : 'Logged as ${s.label.toLowerCase()}.',
                            action: 'REVIEW',
                            onAction: () => showLogEditor(context, g),
                          );
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Card2(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  RatingBar(value: e?.rating ?? 0, size: 34, onChanged: (v) => store.rate(g, v)),
                  const Spacer(),
                  _LikeButton(liked: e?.liked ?? false, onTap: () => store.toggleLike(g)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Btn(
                    store.session?.gameId == g.id ? 'Session running' : 'Play session',
                    icon: Icons.timer_outlined,
                    dense: true,
                    expand: true,
                    onTap: store.session?.gameId == g.id ? () => showSessionStop(context) : () => startSessionFlow(context, g),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Btn('Review & log', icon: Icons.edit_note_rounded, ghost: true, dense: true, expand: true, onTap: () => showLogEditor(context, g)),
                ),
                const SizedBox(width: 10),
                CircleBtn(Icons.playlist_add_rounded, size: 42, tooltip: 'Add to list', onTap: () => showAddToList(context, g)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _yourLog(BuildContext context, Entry e) {
    final mins = store.minutesFor(g.id);
    final sessions = store.sessionsFor(g.id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Card2(
        onTap: () => showLogEditor(context, g),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusBadge(e.status, solid: true),
                const SizedBox(width: 8),
                if (e.platform != null) Text(e.platform!.toUpperCase(), style: T.label),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded, color: C.muted, size: 20),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final w in [
                  StatBlock(fmtMinutes(mins), 'played'),
                  StatBlock('$sessions', sessions == 1 ? 'session' : 'sessions'),
                  StatBlock(e.startedAt == null ? '—' : fmtMs(e.startedAt, year: false), 'started'),
                  if (e.status.finished) StatBlock(fmtMs(e.finishedAt, year: false), 'finished'),
                ])
                  Expanded(
                    child: FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: w),
                  ),
              ],
            ),
            if (g.ttbMain != null && mins > 0 && !e.status.finished) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: (mins * 60 / g.ttbMain!).clamp(0, 1).toDouble(), minHeight: 6),
              ),
              const SizedBox(height: 6),
              Text('~${(mins * 60 / g.ttbMain! * 100).clamp(0, 100).round()}% of a typical main-story run', style: T.small),
            ],
            if (e.review.isNotEmpty) ...[const SizedBox(height: 16), const Divider(), const SizedBox(height: 14), ReviewText(e.review, spoiler: e.spoiler)],
            if (e.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final t in e.tags) _Tag('#$t')]),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, Entry? e) {
    final out = <Widget>[];
    void add(Widget w) => out.add(SliverToBoxAdapter(child: w));

    if (loading && !g.full) {
      add(
        const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))),
        ),
      );
    }
    if (error != null) {
      add(
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Card2(
            child: Row(
              children: [
                const Icon(Icons.wifi_off_rounded, color: C.muted),
                const SizedBox(width: 12),
                Expanded(child: Text(error!, style: T.small)),
                TextButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final summary = g.summary ?? '';
    if (summary.isNotEmpty) {
      add(const SectionHead('The story', kicker: 'About'));
      add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GestureDetector(
            onTap: () => setState(() => expanded = !expanded),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expanded && (g.storyline?.isNotEmpty ?? false) ? '$summary\n\n${g.storyline}' : summary,
                    maxLines: expanded ? null : 5,
                    overflow: expanded ? null : TextOverflow.fade,
                    style: T.body1,
                  ),
                  const SizedBox(height: 6),
                  Text(expanded ? 'LESS' : 'MORE', style: T.label.copyWith(color: context.accent)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (g.ttbMain != null || g.ttbQuick != null || g.ttbFull != null) {
      add(const SectionHead('Time to beat', kicker: 'Length'));
      add(Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _Ttb(g, store.minutesFor(g.id))));
    }

    final facts = <(String, List<String>)>[
      ('Genres', g.genres),
      ('Themes', g.themes),
      ('Modes', g.modes),
      ('Perspective', g.perspectives),
      ('Developer', g.devs),
      ('Publisher', g.publishers),
      ('Series', g.franchises),
      ('Platforms', g.platformsFull.isNotEmpty ? g.platformsFull : g.platforms),
    ].where((f) => f.$2.isNotEmpty).toList();
    if (facts.isNotEmpty) {
      add(const SectionHead('The details', kicker: 'Info'));
      add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              for (final f in facts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 96,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(f.$1.toUpperCase(), style: T.label),
                        ),
                      ),
                      Expanded(child: Wrap(spacing: 6, runSpacing: 6, children: [for (final s in f.$2.take(12)) _Tag(s)])),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (g.critic != null || g.score != null) {
      add(
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Row(
            children: [
              if (g.score != null) Expanded(child: _ScoreCard('IGDB score', g.score!, '${g.ratingCount ?? 0} ratings')),
              if (g.score != null && g.critic != null) const SizedBox(width: 12),
              if (g.critic != null) Expanded(child: _ScoreCard('Critics', g.critic!, 'aggregated')),
            ],
          ),
        ),
      );
    }

    final media = [...g.shots, ...g.arts];
    if (media.isNotEmpty || g.videos.isNotEmpty) {
      add(
        SectionHead(
          'Screens',
          kicker: 'Media',
          action: media.isNotEmpty ? '${media.length}' : null,
          onAction: () => push(context, Gallery(images: media)),
        ),
      );
      add(
        SizedBox(
          height: 160,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              for (final v in g.videos.take(3))
                _MediaThumb(
                  url: 'https://img.youtube.com/vi/$v/hqdefault.jpg',
                  video: true,
                  onTap: () => launchUrl(Uri.parse('https://www.youtube.com/watch?v=$v'), mode: LaunchMode.externalApplication),
                ),
              for (var i = 0; i < media.length; i++)
                _MediaThumb(
                  url: img(media[i], 't_screenshot_med')!,
                  onTap: () => push(context, Gallery(images: media, initial: i)),
                ),
            ],
          ),
        ),
      );
    }

    if (g.releases.length > 1) {
      add(const SectionHead('Release dates', kicker: 'Launch'));
      add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Card2(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                for (final r in g.releases.take(10))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      children: [
                        Expanded(child: Text(r.$1, style: T.title.copyWith(fontSize: 13.5))),
                        Text(r.$2.toUpperCase(), style: T.label.copyWith(color: C.sub)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    if (g.dlcs.isNotEmpty) {
      add(const SectionHead('DLC & expansions', kicker: 'More to play'));
      add(GameRail(g.dlcs, tag: 'dlc', width: 104));
    }
    if (g.family.isNotEmpty) {
      add(const SectionHead('Related versions', kicker: 'Family'));
      add(GameRail(g.family, tag: 'fam', width: 104));
    }
    if (g.similar.isNotEmpty) {
      add(const SectionHead('If you like this', kicker: 'Similar'));
      add(GameRail(g.similar, tag: 'sim', width: 104));
    }

    final myLogs = store.logsFor(g.id).toList();
    if (myLogs.isNotEmpty) {
      add(SectionHead('Your diary', kicker: '${myLogs.length} entries', action: 'Add', onAction: () => showDiaryEntryEditor(context, g)));
      add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [for (final l in myLogs.take(12)) LogRow(l, showGame: false, monthLabel: true)]),
        ),
      );
    }

    if (g.links.isNotEmpty) {
      add(const SectionHead('Elsewhere', kicker: 'Links'));
      add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final l in g.links)
                Chip2(
                  l.$1,
                  icon: Icons.north_east_rounded,
                  onTap: () => launchUrl(Uri.parse(l.$2), mode: LaunchMode.externalApplication),
                ),
            ],
          ),
        ),
      );
    }
    return out;
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.scroll, required this.game, this.onRefresh});
  final ScrollController scroll;
  final Game game;
  final VoidCallback? onRefresh;
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnimatedBuilder(
      animation: scroll,
      builder: (context, _) {
        final o = scroll.hasClients ? scroll.offset : 0.0;
        final t = ((o - 190) / 50).clamp(0.0, 1.0);
        return Container(
          height: top + 60,
          padding: EdgeInsets.fromLTRB(12, top + 8, 12, 8),
          decoration: BoxDecoration(
            color: C.bg.withValues(alpha: t),
            border: Border(
              bottom: BorderSide(color: C.line.withValues(alpha: t)),
            ),
          ),
          child: Row(
            children: [
              CircleBtn(Icons.arrow_back_rounded, size: 42, bg: C.bg.withValues(alpha: 0.6), onTap: () => Navigator.pop(context)),
              const SizedBox(width: 12),
              Expanded(
                child: Opacity(
                  opacity: t,
                  child: Text(game.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.h3),
                ),
              ),
              const SizedBox(width: 8),
              _MoreMenu(game: game, onRefresh: onRefresh),
            ],
          ),
        );
      },
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.game, this.onRefresh});
  final Game game;
  final VoidCallback? onRefresh;
  @override
  Widget build(BuildContext context) {
    final inLib = store.entry(game.id) != null;
    return PopupMenuButton<String>(
      offset: const Offset(0, 50),
      onSelected: (v) async {
        switch (v) {
          case 'log':
            showLogEditor(context, game);
          case 'diary':
            showDiaryEntryEditor(context, game);
          case 'list':
            showAddToList(context, game);
          case 'fav':
            final f = store.favs;
            if (f.contains(game.id)) {
              store.setFavs(f..remove(game.id));
              toast(context, 'Removed from favourites');
            } else if (f.length >= 5) {
              toast(context, 'Your top 5 is full — swap one from your profile.');
            } else {
              store.setFav(f.length, game);
              toast(context, 'Pinned to your top 5');
            }
          case 'igdb':
            launchUrl(Uri.parse('https://www.igdb.com/search?type=1&q=${Uri.encodeComponent(game.name)}'), mode: LaunchMode.externalApplication);
          case 'refresh':
            onRefresh?.call();
          case 'remove':
            final n = store.logsFor(game.id).length;
            if (await confirm(
              context,
              'Remove from library?',
              n == 0
                  ? 'Your rating and review for ${game.name} will be deleted.'
                  : 'This also deletes $n diary ${n == 1 ? 'entry' : 'entries'} for ${game.name}.',
            )) {
              store.removeEntry(game.id);
            }
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'log', child: Text('Edit log & review')),
        const PopupMenuItem(value: 'diary', child: Text('Add diary entry')),
        const PopupMenuItem(value: 'list', child: Text('Add to list')),
        PopupMenuItem(value: 'fav', child: Text(store.favs.contains(game.id) ? 'Unpin from top 5' : 'Pin to top 5')),
        if (!game.manual) const PopupMenuItem(value: 'igdb', child: Text('Open on IGDB')),
        if (onRefresh != null) const PopupMenuItem(value: 'refresh', child: Text('Refresh details')),
        if (inLib)
          const PopupMenuItem(
            value: 'remove',
            child: Text('Remove from library', style: TextStyle(color: Color(0xFFFF5D5D))),
          ),
      ],
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: C.bg.withValues(alpha: 0.6),
          shape: BoxShape.circle,
          border: Border.all(color: C.line),
        ),
        child: const Icon(Icons.more_horiz_rounded, size: 20),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.s, {required this.selected, required this.onTap});
  final Status s;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? s.color : C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? s.color : C.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(s.icon, size: 17, color: selected ? C.bg : s.color),
            const SizedBox(width: 7),
            Text(
              s.label,
              style: TextStyle(fontFamily: T.display, fontWeight: FontWeight.w700, fontSize: 14, color: selected ? C.bg : C.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({required this.liked, required this.onTap});
  final bool liked;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.85,
      onTap: () {
        thud();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: liked ? C.heart.withValues(alpha: 0.16) : C.raised,
          shape: BoxShape.circle,
          border: Border.all(color: liked ? C.heart : C.line),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (c, a) => ScaleTransition(
            scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
            child: c,
          ),
          child: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, key: ValueKey(liked), color: liked ? C.heart : C.sub, size: 22),
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill(this.score);
  final double score;
  @override
  Widget build(BuildContext context) {
    final c = score >= 85 ? const Color(0xFFB4F25A) : (score >= 70 ? C.gold : const Color(0xFFFF8A5B));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.6)),
      ),
      child: Text(
        score.round().toString(),
        style: TextStyle(fontFamily: T.mono, fontWeight: FontWeight.w800, fontSize: 13, color: c),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard(this.label, this.score, this.sub);
  final String label;
  final double score;
  final String sub;
  @override
  Widget build(BuildContext context) {
    final c = score >= 85 ? const Color(0xFFB4F25A) : (score >= 70 ? C.gold : const Color(0xFFFF8A5B));
    return Card2(
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(value: score / 100, strokeWidth: 5, color: c, backgroundColor: C.high, strokeCap: StrokeCap.round),
                Text(score.round().toString(), style: T.h3.copyWith(fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: T.label.copyWith(color: C.text)),
                const SizedBox(height: 4),
                Text(sub, style: T.small.copyWith(fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Ttb extends StatelessWidget {
  const _Ttb(this.g, this.myMinutes);
  final Game g;
  final int myMinutes;
  @override
  Widget build(BuildContext context) {
    final rows = <(String, int?, Color)>[
      ('Rushed', g.ttbQuick, const Color(0xFF4FD8E8)),
      ('Main story', g.ttbMain, context.accent),
      ('Completionist', g.ttbFull, C.gold),
    ];
    final mx = rows.map((r) => r.$2 ?? 0).fold<int>(0, (a, b) => a > b ? a : b);
    return Card2(
      child: Column(
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(width: 104, child: Text(r.$1.toUpperCase(), style: T.label)),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: r.$2 == null || mx == 0 ? 0 : r.$2! / mx, minHeight: 8, color: r.$3, backgroundColor: C.high),
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(fmtSecondsAsHours(r.$2), textAlign: TextAlign.right, style: T.title.copyWith(fontSize: 13.5)),
                  ),
                ],
              ),
            ),
          if (myMinutes > 0) ...[
            const SizedBox(height: 6),
            const Divider(),
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(
                  width: 104,
                  child: Text('YOUR TIME', style: T.label.copyWith(color: C.text)),
                ),
                Expanded(
                  child: Text(fmtMinutes(myMinutes, long: true), style: T.title.copyWith(color: context.accent)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MediaThumb extends StatelessWidget {
  const _MediaThumb({required this.url, required this.onTap, this.video = false});
  final String url;
  final VoidCallback onTap;
  final bool video;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Pressable(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 268,
            height: 160,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  memCacheWidth: 600,
                  placeholder: (_, _) => const ColoredBox(color: C.raised),
                  errorWidget: (_, _, _) => const ColoredBox(color: C.raised),
                ),
                if (video)
                  Center(
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white54),
                      ),
                      child: const Icon(Icons.play_arrow_rounded, size: 30),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: C.surface,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: C.line),
    ),
    child: Text(
      text,
      style: const TextStyle(fontFamily: T.body, fontWeight: FontWeight.w600, fontSize: 12.5, color: C.sub),
    ),
  );
}

/// Review body with tap-to-reveal spoiler veil.
class ReviewText extends StatefulWidget {
  const ReviewText(this.text, {super.key, this.spoiler = false, this.maxLines});
  final String text;
  final bool spoiler;
  final int? maxLines;
  @override
  State<ReviewText> createState() => _ReviewTextState();
}

class _ReviewTextState extends State<ReviewText> {
  bool shown = false;
  @override
  Widget build(BuildContext context) {
    final t = Text(
      widget.text,
      maxLines: widget.maxLines,
      overflow: widget.maxLines == null ? null : TextOverflow.ellipsis,
      style: T.body1.copyWith(color: C.text, fontSize: 14),
    );
    if (!widget.spoiler || shown) return t;
    return GestureDetector(
      onTap: () => setState(() => shown = true),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.raised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.line),
        ),
        child: Row(
          children: [
            const Icon(Icons.visibility_off_rounded, size: 18, color: C.muted),
            const SizedBox(width: 10),
            Text('Contains spoilers — tap to reveal', style: T.small.copyWith(color: C.sub)),
          ],
        ),
      ),
    );
  }
}
