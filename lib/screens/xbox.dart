import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../xbox.dart';
import 'log_sheet.dart';
import 'search.dart';
import 'settings.dart';

const xboxGreen = Color(0xFF5DD36A);

class XboxScreen extends StatefulWidget {
  const XboxScreen({super.key});
  @override
  State<XboxScreen> createState() => _XboxScreenState();
}

class _XboxScreenState extends State<XboxScreen> {
  final key = TextEditingController();
  bool hide = true;
  bool busy = false;
  String? stage;
  String? error;

  @override
  void dispose() {
    key.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    FocusScope.of(context).unfocus();
    if (key.text.trim().isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await store.connectXbox(key.text);
      key.clear();
    } on XboxError catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Something went wrong: $e';
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _sync() async {
    setState(() {
      busy = true;
      error = null;
      stage = 'Connecting…';
    });
    try {
      final (titles, suggestions) = await store.fetchXbox(onStage: (s) {
        if (mounted) setState(() => stage = s);
      });
      if (!mounted) return;
      setState(() {
        busy = false;
        stage = null;
      });
      if (titles.isEmpty) {
        toast(context, 'No games in your Xbox history yet.');
        return;
      }
      final added = await push<int>(context, XboxReviewScreen(titles: titles, suggestions: suggestions));
      if (added != null && mounted) toast(context, added == 0 ? 'Xbox data updated' : 'Added $added games from Xbox');
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          stage = null;
          error = e is XboxError ? e.message : 'Sync failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Xbox')),
      body: Watch(
        builder: (context) {
          final connected = store.xbox.configured;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 60),
            children: [
              if (connected) ..._connected(context) else ..._setup(context),
              if (error != null) ...[
                const SizedBox(height: 16),
                Card2(
                  color: const Color(0xFFFF5D5D).withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFFF5D5D)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(error!, style: T.title.copyWith(fontSize: 13.5))),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  List<Widget> _setup(BuildContext context) => [
    Text(
      'Pull your Xbox history into Savepoint: every game you’ve played on Xbox or PC, with your hours, achievements and gamerscore.',
      style: T.body1,
    ),
    const SizedBox(height: 10),
    Text(
      'Microsoft no longer lets personal accounts make their own Xbox Live apps, so this goes through OpenXBL, a free service that reads your Xbox data with your permission.',
      style: T.small.copyWith(fontSize: 13, height: 1.5),
    ),
    const SizedBox(height: 22),
    const SetupStep(1, 'Sign in at xbl.io', 'Use the Microsoft account linked to your Xbox profile.'),
    Padding(
      padding: const EdgeInsets.only(left: 44, bottom: 18),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Btn(
          'xbl.io',
          icon: Icons.north_east_rounded,
          dense: true,
          ghost: true,
          onTap: () => launchUrl(Uri.parse('https://xbl.io'), mode: LaunchMode.externalApplication),
        ),
      ),
    ),
    const SetupStep(2, 'Create an API key', 'On your xbl.io profile page, create a personal API key and copy it.'),
    const SetupStep(3, 'Paste it below', 'Savepoint checks the key by loading your gamertag.'),
    const SizedBox(height: 8),
    TextField(
      controller: key,
      autocorrect: false,
      obscureText: hide,
      decoration: InputDecoration(
        labelText: 'OpenXBL API key',
        suffixIcon: IconButton(
          icon: Icon(hide ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: C.muted),
          onPressed: () => setState(() => hide = !hide),
        ),
      ),
    ),
    const SizedBox(height: 20),
    Btn(busy ? 'Connecting…' : 'Connect', icon: Icons.link_rounded, expand: true, onTap: busy ? null : _connect),
    const SizedBox(height: 18),
    Text(
      'Your key stays on this device and is never put in backups. Anyone with the key can read your Xbox data, so keep it private. You can delete it on xbl.io at any time.',
      style: T.small,
    ),
  ];

  List<Widget> _connected(BuildContext context) {
    final p = store.xboxProfile;
    final titles = store.xboxTitles.values;
    final linked = titles.where((t) => t.gameId != null).length;
    final synced = int.tryParse(store.kv['xbl_synced'] ?? '');
    return [
      XboxProfileCard(p),
      const SizedBox(height: 12),
      Card2(
        child: Row(
          children: [
            for (final w in [
              StatBlock('$linked', 'linked games'),
              StatBlock(fmtMinutes(titles.where((t) => t.gameId != null).fold(0, (a, t) => a + t.minutes)), 'xbox time'),
              StatBlock(synced == null ? '—' : ago(synced), 'last sync'),
            ])
              Expanded(
                child: FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: w),
              ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Btn(busy ? (stage ?? 'Syncing…') : 'Sync my Xbox games', icon: Icons.sync_rounded, expand: true, onTap: busy ? null : _sync),
      const SizedBox(height: 10),
      Text(
        'You review everything before it’s added. Games already in your library keep their status and rating. Only new Xbox playtime is added to them.',
        style: T.small,
      ),
      if (!store.igdb.configured) ...[
        const SizedBox(height: 14),
        Card2(
          color: C.gold.withValues(alpha: 0.08),
          onTap: () => push(context, const IgdbSetupScreen()),
          child: Row(
            children: [
              const Icon(Icons.key_rounded, color: C.gold),
              const SizedBox(width: 12),
              Expanded(child: Text('Connect IGDB first so your Xbox games can be matched to covers and details.', style: T.title.copyWith(fontSize: 13.5))),
            ],
          ),
        ),
      ],
      const SizedBox(height: 30),
      Center(
        child: TextButton(
          onPressed: busy
              ? null
              : () async {
                  if (await confirm(context, 'Disconnect Xbox?', 'This removes your key from this phone. Games you imported stay in your library.', yes: 'Disconnect')) {
                    store.disconnectXbox();
                  }
                },
          child: const Text('Disconnect', style: TextStyle(color: Color(0xFFFF5D5D), fontWeight: FontWeight.w700)),
        ),
      ),
    ];
  }
}

class XboxProfileCard extends StatelessWidget {
  const XboxProfileCard(this.p, {super.key, this.onTap});
  final XboxProfile? p;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Card2(
      onTap: onTap,
      color: xboxGreen.withValues(alpha: 0.07),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 52,
              height: 52,
              child: p?.pic == null
                  ? const ColoredBox(color: C.raised, child: Icon(Icons.sports_esports_rounded, color: xboxGreen))
                  : CachedNetworkImage(
                      imageUrl: p!.pic!,
                      fit: BoxFit.cover,
                      memCacheWidth: 160,
                      errorWidget: (_, _, _) => const ColoredBox(color: C.raised, child: Icon(Icons.sports_esports_rounded, color: xboxGreen)),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('XBOX', style: T.label.copyWith(color: xboxGreen)),
                const SizedBox(height: 4),
                Text(p?.gamertag ?? 'Connected', style: T.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (p != null) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${p!.gamerscore}', style: T.h3.copyWith(color: xboxGreen)),
                const SizedBox(height: 2),
                Text('GAMERSCORE', style: T.label.copyWith(fontSize: 9)),
              ],
            ),
          ],
          if (onTap != null) ...[const SizedBox(width: 6), const Icon(Icons.chevron_right_rounded, color: C.faint, size: 20)],
        ],
      ),
    );
  }
}

/// Achievements and playtime for a game linked to an Xbox title.
class XboxGameCard extends StatelessWidget {
  const XboxGameCard(this.t, {super.key});
  final XboxTitle t;
  @override
  Widget build(BuildContext context) {
    return Card2(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sports_esports_rounded, size: 16, color: xboxGreen),
              const SizedBox(width: 8),
              Text('ON XBOX', style: T.label.copyWith(color: xboxGreen)),
              const Spacer(),
              if (t.lastPlayed != null) Text('PLAYED ${ago(t.lastPlayed!).toUpperCase()}', style: T.label.copyWith(fontSize: 9.5)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final w in [
                if (t.achTotal > 0) StatBlock('${t.ach}/${t.achTotal}', 'achievements', color: t.mastered ? C.gold : null),
                if (t.gsTotal > 0) StatBlock('${t.gs}', 'of ${t.gsTotal} G'),
                if (t.minutes > 0) StatBlock(fmtMinutes(t.minutes), 'xbox time'),
              ])
                Expanded(
                  child: FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: w),
                ),
            ],
          ),
          if (t.achTotal > 0) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (t.progress / 100).clamp(0, 1).toDouble(),
                minHeight: 6,
                color: t.mastered ? C.gold : xboxGreen,
                backgroundColor: C.raised,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────── review ─────────────────────────

class _Pick {
  _Pick(this.t, this.game, this.confident, this.status, this.include);
  final XboxTitle t;
  Game? game;
  bool confident;
  Status status;
  bool include;
}

enum _Filter { all, fresh, check, unmatched }

class XboxReviewScreen extends StatefulWidget {
  const XboxReviewScreen({super.key, required this.titles, required this.suggestions});
  final List<XboxTitle> titles;
  final Map<String, (Game, bool)> suggestions;
  @override
  State<XboxReviewScreen> createState() => _XboxReviewScreenState();
}

class _XboxReviewScreenState extends State<XboxReviewScreen> {
  late final List<_Pick> picks;
  _Filter filter = _Filter.all;

  static Status suggest(XboxTitle t) {
    if (t.mastered) return Status.mastered;
    final recent = t.lastPlayed != null && DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(t.lastPlayed!)).inDays <= 30;
    return recent ? Status.playing : Status.played;
  }

  @override
  void initState() {
    super.initState();
    final skipped = store.xboxSkipped;
    picks = [
      for (final t in widget.titles)
        if (t.gameId != null)
          _Pick(t, store.game(t.gameId!), true, suggest(t), true)
        else
          _Pick(t, widget.suggestions[t.id]?.$1, widget.suggestions[t.id]?.$2 ?? false, suggest(t), widget.suggestions[t.id] != null && !skipped.contains(t.id)),
    ];
  }

  bool _isNew(_Pick p) => p.game != null && store.entry(p.game!.id) == null;
  bool _needsCheck(_Pick p) => p.game != null && !p.confident;

  Iterable<_Pick> get _shown => switch (filter) {
    _Filter.all => picks,
    _Filter.fresh => picks.where(_isNew),
    _Filter.check => picks.where(_needsCheck),
    _Filter.unmatched => picks.where((p) => p.game == null),
  };

  Future<void> _rematch(_Pick p) async {
    final g = await push<Game>(context, SearchScreen(pick: true, title: 'Match “${p.t.name}”', initial: p.t.searchName));
    if (g == null || !mounted) return;
    setState(() {
      p.game = g;
      p.confident = true;
      p.include = true;
    });
  }

  Future<void> _pickStatus(_Pick p) async {
    final s = await sheet<Status>(
      context,
      (c) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.t.name, style: T.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 14),
            StatusGrid(value: p.status, onChanged: (s) => Navigator.pop(c, s)),
          ],
        ),
      ),
    );
    if (s != null) setState(() => p.status = s);
  }

  void _import() {
    final chosen = [
      for (final p in picks)
        if (p.include && p.game != null) (p.t, p.game!, p.status),
    ];
    final added = store.applyXbox(widget.titles, chosen);
    Navigator.pop(context, added);
  }

  @override
  Widget build(BuildContext context) {
    final count = picks.where((p) => p.include && p.game != null).length;
    final shown = _shown.toList();
    final mq = MediaQuery.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('${widget.titles.length} Xbox games')),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              children: [
                for (final (f, label, n) in [
                  (_Filter.all, 'All', picks.length),
                  (_Filter.fresh, 'New', picks.where(_isNew).length),
                  (_Filter.check, 'Check match', picks.where(_needsCheck).length),
                  (_Filter.unmatched, 'No match', picks.where((p) => p.game == null).length),
                ]) ...[
                  Chip2(label, count: n, selected: filter == f, color: f == _Filter.check ? C.gold : null, onTap: () => setState(() => filter = f)),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(child: Text('Nothing here.', style: T.small))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _row(shown[i]),
                  ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, mq.padding.bottom + 12),
            decoration: const BoxDecoration(
              color: C.bg,
              border: Border(top: BorderSide(color: C.line)),
            ),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    final on = shown.any((p) => !p.include && p.game != null);
                    for (final p in shown) {
                      if (p.game != null) p.include = on;
                    }
                  }),
                  child: Text(shown.any((p) => !p.include && p.game != null) ? 'Select all' : 'Select none', style: const TextStyle(color: C.sub)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Btn(count == 0 ? 'Nothing selected' : 'Import $count', icon: Icons.download_rounded, expand: true, onTap: count == 0 ? null : _import),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(_Pick p) {
    final t = p.t;
    final g = p.game;
    final existing = g == null ? null : store.entry(g.id);
    final meta = [
      if (t.minutes > 0) fmtMinutes(t.minutes),
      if (t.achTotal > 0) '${t.ach}/${t.achTotal} achievements',
      if (t.lastPlayed != null) ago(t.lastPlayed!),
    ].join(' · ');
    return Opacity(
      opacity: p.include || g == null ? 1 : 0.55,
      child: Card2(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        radius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: t.image == null
                        ? const ColoredBox(color: C.raised)
                        : CachedNetworkImage(
                            imageUrl: t.image!,
                            fit: BoxFit.cover,
                            memCacheWidth: 126,
                            placeholder: (_, _) => const ColoredBox(color: C.raised),
                            errorWidget: (_, _, _) => const ColoredBox(color: C.raised),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.title.copyWith(fontSize: 14)),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small.copyWith(fontSize: 11.5)),
                      ],
                    ],
                  ),
                ),
                Checkbox(
                  value: p.include && g != null,
                  onChanged: g == null ? null : (v) => setState(() => p.include = v ?? false),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.subdirectory_arrow_right_rounded, size: 16, color: C.faint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Pressable(
                      scale: 0.98,
                      onTap: () => _rematch(p),
                      child: Row(
                        children: [
                          if (g != null) SizedBox(width: 26, child: Cover(g, radius: 4, size: 't_cover_small')),
                          if (g != null) const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              g == null ? 'No match. Tap to find it' : '${g.name}${g.year == null ? '' : ' (${g.year})'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: T.small.copyWith(color: g == null ? C.gold : C.sub, fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (_needsCheck(p)) ...[
                            const SizedBox(width: 6),
                            Text('CHECK', style: T.label.copyWith(fontSize: 9, color: C.gold)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (existing != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [Text('IN LIBRARY ', style: T.label.copyWith(fontSize: 8.5)), StatusBadge(existing.status)],
                    )
                  else if (g != null)
                    Pressable(onTap: () => _pickStatus(p), child: StatusBadge(p.status)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
