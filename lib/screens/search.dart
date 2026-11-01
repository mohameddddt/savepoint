import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../igdb.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'log_sheet.dart';
import 'settings.dart';

/// Search IGDB + your library. In [pick] mode, returns the tapped [Game].
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.pick = false, this.title});
  final bool pick;
  final String? title;
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final c = TextEditingController();
  Timer? _deb;
  String q = '';
  List<Game>? results;
  bool loading = false;
  String? error;
  int _req = 0;

  List<String> get recent {
    try {
      return (jsonDecode(store.kv['recent_q'] ?? '[]') as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  void _remember(String s) {
    final t = s.trim();
    if (t.length < 2) return;
    final r = recent..remove(t);
    r.insert(0, t);
    store.setKv('recent_q', jsonEncode(r.take(8).toList()));
  }

  @override
  void dispose() {
    _deb?.cancel();
    c.dispose();
    super.dispose();
  }

  void _changed(String v) {
    setState(() => q = v);
    _deb?.cancel();
    if (v.trim().isEmpty) {
      setState(() {
        results = null;
        loading = false;
        error = null;
      });
      return;
    }
    _deb = Timer(const Duration(milliseconds: 350), () => _run(v));
  }

  Future<void> _run(String v) async {
    if (!store.igdb.configured) return;
    final id = ++_req;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await store.igdb.search(v);
      if (id != _req || !mounted) return;
      setState(() {
        results = r;
        loading = false;
      });
    } on IgdbError catch (e) {
      if (id != _req || !mounted) return;
      setState(() {
        error = e.message;
        loading = false;
      });
    } catch (_) {
      if (id != _req || !mounted) return;
      setState(() {
        error = 'Search failed';
        loading = false;
      });
    }
  }

  void _tap(Game g) {
    _remember(q.isEmpty ? g.name : q);
    if (widget.pick) {
      Navigator.pop(context, g);
    } else {
      openGame(context, g, heroTag: 's-${g.id}');
    }
  }

  Future<void> _manual() async {
    final g = await push<Game>(context, ManualGameScreen(initialName: q));
    if (g == null || !mounted) return;
    if (widget.pick) {
      Navigator.pop(context, g);
    } else {
      openGame(context, g);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lq = q.trim().toLowerCase();
    final local = lq.isEmpty ? <Game>[] : store.entries.keys.map(store.game).whereType<Game>().where((g) => g.name.toLowerCase().contains(lq)).take(8).toList();
    final localIds = local.map((g) => g.id).toSet();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 16, 6),
              child: Row(
                children: [
                  CircleBtn(Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: c,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: _changed,
                      onSubmitted: (v) {
                        _deb?.cancel();
                        _remember(v);
                        _run(v);
                      },
                      style: T.title.copyWith(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: widget.title ?? 'Search 300,000+ games',
                        prefixIcon: const Icon(Icons.search_rounded, color: C.muted),
                        suffixIcon: q.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18, color: C.muted),
                                onPressed: () {
                                  c.clear();
                                  _changed('');
                                },
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (loading) const LinearProgressIndicator(minHeight: 2) else const SizedBox(height: 2),
            Expanded(
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.paddingOf(context).bottom + 30),
                children: [
                  if (!store.igdb.configured) _setupBanner(context),
                  if (lq.isEmpty) ..._idle(context),
                  if (local.isNotEmpty) ...[_head('In your library'), for (final g in local) ResultRow(g, onTap: () => _tap(g), pick: widget.pick)],
                  if (lq.isNotEmpty && error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Column(
                        children: [
                          Text(error!, textAlign: TextAlign.center, style: T.small),
                          const SizedBox(height: 10),
                          TextButton(onPressed: () => _run(q), child: const Text('Try again')),
                        ],
                      ),
                    ),
                  if (results != null && results!.isNotEmpty) ...[
                    _head('IGDB'),
                    for (final g in results!.where((g) => !localIds.contains(g.id))) ResultRow(g, onTap: () => _tap(g), pick: widget.pick),
                  ],
                  if (results != null && results!.isEmpty && local.isEmpty && !loading)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Text('No games match “$q”.', textAlign: TextAlign.center, style: T.small),
                    ),
                  if (lq.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Card2(
                      onTap: _manual,
                      child: Row(
                        children: [
                          Icon(Icons.add_box_outlined, color: context.accent),
                          const SizedBox(width: 12),
                          Expanded(child: Text('Can’t find it? Add “${q.trim()}” manually', style: T.title.copyWith(fontSize: 14))),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _head(String t) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 6),
    child: Text(t.toUpperCase(), style: T.label.copyWith(color: context.accent)),
  );

  Widget _setupBanner(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 6),
    child: Card2(
      onTap: () async {
        await push(context, const IgdbSetupScreen());
        if (mounted) setState(() {});
      },
      color: context.accent.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(Icons.key_rounded, color: context.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Connect IGDB to search', style: T.title),
                const SizedBox(height: 3),
                Text('A free 2-minute setup unlocks covers, details and discovery.', style: T.small),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: C.muted),
        ],
      ),
    ),
  );

  List<Widget> _idle(BuildContext context) {
    final r = recent;
    final lib = widget.pick
        ? (store.entries.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)))
              .map((e) => store.game(e.gameId))
              .whereType<Game>()
              .take(30)
              .toList()
        : <Game>[];
    return [
      if (r.isNotEmpty) ...[
        _head('Recent searches'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in r)
              Chip2(
                s,
                icon: Icons.history_rounded,
                onTap: () {
                  c.text = s;
                  c.selection = TextSelection.collapsed(offset: s.length);
                  _changed(s);
                },
              ),
          ],
        ),
      ],
      if (lib.isNotEmpty) ...[_head('From your library'), for (final g in lib) ResultRow(g, onTap: () => _tap(g), pick: true)],
      const SizedBox(height: 18),
      Card2(
        onTap: _manual,
        child: Row(
          children: [
            Icon(Icons.add_box_outlined, color: context.accent),
            const SizedBox(width: 12),
            Expanded(child: Text('Add a game manually', style: T.title.copyWith(fontSize: 14))),
            const Icon(Icons.chevron_right_rounded, color: C.muted),
          ],
        ),
      ),
    ];
  }
}

class ResultRow extends StatelessWidget {
  const ResultRow(this.g, {super.key, required this.onTap, this.pick = false});
  final Game g;
  final VoidCallback onTap;
  final bool pick;
  @override
  Widget build(BuildContext context) {
    final e = store.entry(g.id);
    return Pressable(
      scale: 0.98,
      onTap: onTap,
      onLongPress: pick ? null : () => showQuickActions(context, g),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            SizedBox(width: 50, child: Cover(g, radius: 7, heroTag: pick ? null : 's-${g.id}')),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.title.copyWith(fontSize: 14.5)),
                  const SizedBox(height: 4),
                  Text(
                    [g.year?.toString() ?? 'TBA', if (g.dev.isNotEmpty) g.dev, if (g.platforms.isNotEmpty) g.platforms.take(3).join(', ')].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.small,
                  ),
                  if (e != null) ...[
                    const SizedBox(height: 6),
                    Row(children: [StatusBadge(e.status), const SizedBox(width: 8), StarRow(e.rating, size: 11)]),
                  ],
                ],
              ),
            ),
            if (!pick && e == null)
              IconButton(
                onPressed: () => showQuickActions(context, g),
                icon: const Icon(Icons.bookmark_add_outlined, color: C.sub),
              ),
          ],
        ),
      ),
    );
  }
}

class ManualGameScreen extends StatefulWidget {
  const ManualGameScreen({super.key, this.initialName = ''});
  final String initialName;
  @override
  State<ManualGameScreen> createState() => _ManualGameScreenState();
}

class _ManualGameScreenState extends State<ManualGameScreen> {
  late final name = TextEditingController(text: widget.initialName.trim());
  final cover = TextEditingController();
  final year = TextEditingController();
  final plats = TextEditingController();
  final genres = TextEditingController();
  final dev = TextEditingController();

  @override
  void dispose() {
    for (final c in [name, cover, year, plats, genres, dev]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _split(String s) => s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  @override
  Widget build(BuildContext context) {
    final preview = Game(id: -1, name: name.text.isEmpty ? 'Untitled' : name.text, cover: cover.text.trim().isEmpty ? null : cover.text.trim());
    return Scaffold(
      appBar: AppBar(title: const Text('Add manually')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Center(child: SizedBox(width: 130, child: Cover(preview, radius: 12))),
          const SizedBox(height: 24),
          TextField(
            controller: name,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Title *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: cover,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'Cover image URL (optional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: year,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Release year'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: plats,
            decoration: const InputDecoration(labelText: 'Platforms (comma separated)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: genres,
            decoration: const InputDecoration(labelText: 'Genres (comma separated)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: dev,
            decoration: const InputDecoration(labelText: 'Developer'),
          ),
          const SizedBox(height: 28),
          Btn(
            'Create game',
            expand: true,
            onTap: name.text.trim().isEmpty
                ? null
                : () {
                    final g = store.createManualGame(
                      name: name.text.trim(),
                      coverUrl: cover.text,
                      year: int.tryParse(year.text.trim()),
                      platforms: _split(plats.text),
                      genres: _split(genres.text),
                      dev: dev.text.trim(),
                    );
                    Navigator.pop(context, g);
                  },
          ),
        ],
      ),
    );
  }
}
