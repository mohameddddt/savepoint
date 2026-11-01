import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../igdb.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'search.dart';
import 'settings.dart';

const _rails = <(String, String, String)>[
  ('trending', 'Trending now', 'Hot right now'),
  ('anticipated', 'Most anticipated', 'On the horizon'),
  ('fresh', 'Fresh releases', 'Last 60 days'),
  ('greats', 'All-time greats', 'The canon'),
  ('hidden', 'Hidden gems', 'Under the radar'),
];

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final data = <String, List<Game>>{};
  final errors = <String, String>{};
  bool _wasConfigured = false;

  @override
  void initState() {
    super.initState();
    for (final r in _rails) {
      final c = store.igdb.railCache(r.$1);
      if (c != null) data[r.$1] = c;
    }
    _wasConfigured = store.igdb.configured;
    if (_wasConfigured) _loadAll();
  }

  Future<void> _loadAll({bool force = false}) async {
    for (final r in _rails) {
      if (!force && store.igdb.railFresh(r.$1) && data[r.$1] != null) continue;
      try {
        final g = await store.rail(r.$1, force: force);
        if (!mounted) return;
        setState(() {
          data[r.$1] = g;
          errors.remove(r.$1);
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => errors[r.$1] = e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Watch(
      builder: (context) {
        final configured = store.igdb.configured;
        if (configured && !_wasConfigured) {
          _wasConfigured = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
        }
        final featured = (data['trending'] ?? const <Game>[]).where((g) => g.hero != null).take(6).toList();
        return RefreshIndicator(
          onRefresh: () => _loadAll(force: true),
          edgeOffset: mq.padding.top,
          child: ListView(
            padding: EdgeInsets.only(top: mq.padding.top + 18, bottom: mq.padding.bottom + 24),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DISCOVER', style: T.label.copyWith(color: context.accent, letterSpacing: 2.5)),
                    const SizedBox(height: 10),
                    Text('What’s worth\nplaying next.', style: T.hero.copyWith(fontSize: 38)),
                    const SizedBox(height: 20),
                    Pressable(
                      scale: 0.98,
                      onTap: () => push(context, const SearchScreen()),
                      child: Container(
                        height: 54,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: C.raised,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: C.line),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded, color: C.muted),
                            const SizedBox(width: 12),
                            Text('Search games, series, studios…', style: T.small.copyWith(fontSize: 14.5)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!configured)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Card2(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Plug in the world’s game database', style: T.h3),
                        const SizedBox(height: 8),
                        Text(
                          'Discovery runs on IGDB. Add your free Twitch developer keys once and this page fills with trending, upcoming and all-time great games.',
                          style: T.body1,
                        ),
                        const SizedBox(height: 16),
                        Btn('Connect IGDB', icon: Icons.key_rounded, dense: true, onTap: () => push(context, const IgdbSetupScreen())),
                      ],
                    ),
                  ),
                ),
              if (configured && featured.isNotEmpty) ...[const SizedBox(height: 24), _Featured(featured)],
              if (configured)
                for (final r in _rails) ...[
                  SectionHead(r.$2, kicker: r.$3),
                  if (data[r.$1] != null && data[r.$1]!.isNotEmpty)
                    GameRail(data[r.$1]!, tag: r.$1, subtitle: r.$1 == 'anticipated' ? (g) => g.date == null ? 'TBA' : fmtDate(g.date!).toUpperCase() : null)
                  else if (errors[r.$1] != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Card2(
                        child: Row(
                          children: [
                            Expanded(child: Text(errors[r.$1]!, style: T.small)),
                            TextButton(onPressed: () => _loadAll(force: true), child: const Text('Retry')),
                          ],
                        ),
                      ),
                    )
                  else
                    const SkeletonRail(),
                ],
              const SectionHead('Genres & moods', kicker: 'Browse'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.count(
                  padding: EdgeInsets.zero,
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.45,
                  children: [for (final t in taxonomy) _TaxonTile(t, enabled: configured)],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Featured extends StatefulWidget {
  const _Featured(this.games);
  final List<Game> games;
  @override
  State<_Featured> createState() => _FeaturedState();
}

class _FeaturedState extends State<_Featured> {
  final pc = PageController(viewportFraction: 0.88);
  int page = 0;

  @override
  void dispose() {
    pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width * 0.88;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Column(
      children: [
        SizedBox(
          height: 236,
          child: PageView.builder(
            controller: pc,
            padEnds: true,
            itemCount: widget.games.length,
            onPageChanged: (p) => setState(() => page = p),
            itemBuilder: (_, i) {
              final g = widget.games[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Pressable(
                  scale: 0.98,
                  onTap: () => openGame(context, g),
                  onLongPress: () {},
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: img(g.hero, 't_screenshot_big')!,
                          fit: BoxFit.cover,
                          memCacheWidth: (w * dpr).round(),
                          placeholder: (_, _) => const ColoredBox(color: C.raised),
                          errorWidget: (_, _, _) => ColoredBox(color: hueFor(g.id, l: 0.2)),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.3, 1],
                              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9)],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 18,
                          top: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(color: context.accent, borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              '#${i + 1} TRENDING',
                              style: T.label.copyWith(color: context.onAccent, fontWeight: FontWeight.w800, fontSize: 9.5),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 18,
                          right: 18,
                          bottom: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(g.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.h2.copyWith(fontSize: 25)),
                              const SizedBox(height: 6),
                              Text([if (g.year != null) '${g.year}', ...g.genres.take(2)].join(' · ').toUpperCase(), style: T.label.copyWith(color: C.sub)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.games.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(color: i == page ? context.accent : C.faint, borderRadius: BorderRadius.circular(3)),
              ),
          ],
        ),
      ],
    );
  }
}

class _TaxonTile extends StatelessWidget {
  const _TaxonTile(this.t, {required this.enabled});
  final Taxon t;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final c = hueFor(t.id * 7 + t.field.length, s: 0.6, l: 0.36);
    return Pressable(
      onTap: enabled ? () => push(context, BrowseScreen(taxon: t)) : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c, Color.lerp(c, C.bg, 0.7)!]),
          ),
          child: Stack(
            children: [
              Positioned(right: -18, top: -18, child: Gem(size: 54, color: Colors.white.withValues(alpha: 0.1), filled: true)),
              Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  t.name,
                  maxLines: 2,
                  style: T.title.copyWith(fontFamily: T.display, fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white, height: 1.05),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key, required this.taxon});
  final Taxon taxon;
  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  String sort = 'top';
  final games = <Game>[];
  bool loading = false;
  bool done = false;
  String? error;
  final sc = ScrollController();
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _more();
    sc.addListener(() {
      if (sc.position.pixels > sc.position.maxScrollExtent - 600) _more();
    });
  }

  @override
  void dispose() {
    sc.dispose();
    super.dispose();
  }

  Future<void> _more() async {
    if (loading || done) return;
    final gen = _gen;
    setState(() => loading = true);
    try {
      final r = await store.igdb.browse(field: widget.taxon.field, id: widget.taxon.id, sort: sort, offset: games.length);
      if (!mounted || gen != _gen) return;
      setState(() {
        final ids = games.map((g) => g.id).toSet();
        games.addAll(r.where((g) => !ids.contains(g.id)));
        done = r.length < 30;
        error = null;
      });
    } catch (e) {
      if (mounted && gen == _gen) setState(() => error = e.toString());
    } finally {
      if (mounted && gen == _gen) setState(() => loading = false);
    }
  }

  void _setSort(String s) {
    if (s == sort) return;
    tick();
    setState(() {
      _gen++;
      sort = s;
      games.clear();
      done = false;
      loading = false;
      error = null;
    });
    _more();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.taxon.name)),
      body: CustomScrollView(
        controller: sc,
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                children: [
                  for (final s in const [('top', 'Top rated'), ('popular', 'Most popular'), ('new', 'Newest'), ('upcoming', 'Upcoming')])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip2(s.$2, selected: sort == s.$1, onTap: () => _setSort(s.$1)),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 18,
                crossAxisSpacing: 12,
                childAspectRatio: 0.5,
              ),
              delegate: SliverChildBuilderDelegate((_, i) => GameTile(games[i], tagPrefix: 'br'), childCount: games.length),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 30, top: 10),
              child: Center(
                child: error != null
                    ? TextButton(
                        onPressed: _more,
                        child: Text('Couldn’t load — retry', style: TextStyle(color: context.accent)),
                      )
                    : loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2))
                    : games.isEmpty
                    ? Text('Nothing here.', style: T.small)
                    : const SizedBox(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
