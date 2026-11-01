import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'db.dart';
import 'igdb.dart';
import 'models.dart';
import 'theme.dart';
import 'xbox.dart';

late final Store store;

class Store extends ChangeNotifier {
  final db = Db();
  final games = <int, Game>{};
  final entries = <int, Entry>{};
  final logs = <LogItem>[]; // newest first
  final lists = <String, GameList>{};
  final kv = <String, String>{};
  late final Igdb igdb = Igdb(read: (k) => kv[k], write: setKv);
  late final Xbox xbox = Xbox(read: (k) => kv[k]);

  final _rnd = Random();
  Map<int, int>? _sessionMinutes;
  Map<int, int>? _sessionCount;
  final Map<int, (String, int)> _autoLog = {}; // gameId -> (logId, createdAt) for undoable milestones

  int get now => DateTime.now().millisecondsSinceEpoch;
  String newId() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_rnd.nextInt(1 << 20).toRadixString(36)}';

  Future<void> load() async {
    await db.open();
    final r = await Future.wait([db.all('games'), db.all('entries'), db.all('logs'), db.all('lists'), db.kv()]);
    _hydrate(
      r[0] as List<Map<String, dynamic>>,
      r[1] as List<Map<String, dynamic>>,
      r[2] as List<Map<String, dynamic>>,
      r[3] as List<Map<String, dynamic>>,
      r[4] as Map<String, String>,
    );
  }

  void _hydrate(
    List<Map<String, dynamic>> g,
    List<Map<String, dynamic>> e,
    List<Map<String, dynamic>> l,
    List<Map<String, dynamic>> ls,
    Map<String, String> k,
  ) {
    games
      ..clear()
      ..addAll({for (final j in g) (j['id'] as num).toInt(): Game.fromJson(j)});
    entries
      ..clear()
      ..addAll({for (final j in e) (j['g'] as num).toInt(): Entry.fromJson(j)});
    logs
      ..clear()
      ..addAll(l.map(LogItem.fromJson))
      ..sort((a, b) => b.date.compareTo(a.date));
    lists
      ..clear()
      ..addAll({for (final j in ls) j['id'] as String: GameList.fromJson(j)});
    kv
      ..clear()
      ..addAll(k);
    for (final key in kv.keys.where((k) => k.startsWith('rail_')).toList()) {
      try {
        final j = jsonDecode(kv[key]!) as Map<String, dynamic>;
        igdb.seedRail(key.substring(5), (j['g'] as List).map((e) => Game.fromJson(e)).toList(), DateTime.fromMillisecondsSinceEpoch(j['at']));
      } catch (_) {}
    }
    _sessionMinutes = null;
    _sessionCount = null;
    _xboxTitles = null;
  }

  void _changed() {
    _sessionMinutes = null;
    _sessionCount = null;
    notifyListeners();
  }

  // ───────────────────────── settings ─────────────────────────

  void setKv(String k, String? v) {
    if (v == null) {
      kv.remove(k);
    } else {
      kv[k] = v;
    }
    db.setKv(k, v);
  }

  void setPref(String k, String? v) {
    setKv(k, v);
    notifyListeners();
  }

  String get name => kv['name']?.trim().isNotEmpty == true ? kv['name']! : 'Player One';
  Accent get accent => accents[(int.tryParse(kv['accent'] ?? '') ?? 0).clamp(0, accents.length - 1)];
  late final ValueNotifier<Accent> accentVN = ValueNotifier(accent);
  void setAccent(int i) {
    setPref('accent', '$i');
    accentVN.value = accents[i];
  }

  int goalFor(int year) => int.tryParse(kv['goal_$year'] ?? '') ?? 0;
  void setGoal(int year, int goal) => setPref('goal_$year', goal <= 0 ? null : '$goal');
  bool get onboarded => kv['onboarded'] == '1';

  List<int> get favs => (kv['favs'] ?? '').split(',').map(int.tryParse).whereType<int>().toList();
  void setFavs(List<int> ids) => setPref('favs', ids.take(5).join(','));
  void setFav(int slot, Game? g) {
    final f = List<int?>.from(favs);
    while (f.length < 5) {
      f.add(null);
    }
    if (g != null) {
      cacheGame(g);
      f.removeWhere((x) => x == g.id);
      f.insert(slot.clamp(0, f.length), g.id);
    } else if (slot < f.length) {
      f.removeAt(slot);
    }
    setFavs(f.whereType<int>().toList());
  }

  // ───────────────────────── games & entries ─────────────────────────

  Game? game(int id) => games[id];
  Entry? entry(int id) => entries[id];

  void cacheGame(Game g) {
    final old = games[g.id];
    var snap = g.snapshot();
    if (old != null && snap.ttbMain == null && old.ttbMain != null) snap = snap.withTtb(old.ttbQuick, old.ttbMain, old.ttbFull);
    if (old != null && jsonEncode(old.toJson()) == jsonEncode(snap.toJson())) return;
    games[g.id] = snap;
    db.put('games', g.id, snap.toJson());
  }

  /// Refreshes a cached snapshot from a freshly-loaded full game (silent).
  void refreshSnapshot(Game full) {
    if (!games.containsKey(full.id)) return;
    final before = games[full.id];
    cacheGame(full);
    if (before?.hero != games[full.id]?.hero || before?.ttbMain != games[full.id]?.ttbMain) notifyListeners();
  }

  Iterable<Entry> withStatus(Status s) => entries.values.where((e) => e.status == s);
  int count(Status s) => entries.values.where((e) => e.status == s).length;

  Entry setStatus(Game g, Status s) {
    final prev = entries[g.id];
    final e = prev?.copy() ?? Entry(gameId: g.id, status: s);
    final old = prev?.status;
    e.status = s;
    saveEntry(g, e, prev: old, isNew: prev == null);
    return e;
  }

  void rate(Game g, int rating) {
    final e = entries[g.id]?.copy() ?? Entry(gameId: g.id, status: Status.played);
    final isNew = !entries.containsKey(g.id);
    e.rating = rating;
    saveEntry(g, e, prev: e.status, isNew: isNew);
  }

  void toggleLike(Game g) {
    final isNew = !entries.containsKey(g.id);
    final e = entries[g.id]?.copy() ?? Entry(gameId: g.id, status: Status.played);
    e.liked = !e.liked;
    saveEntry(g, e, prev: e.status, isNew: isNew);
  }

  void saveEntry(Game g, Entry e, {Status? prev, bool isNew = false}) {
    cacheGame(g);
    final t = now;
    e.updatedAt = t;
    if (e.review.trim().isNotEmpty) e.reviewedAt ??= t;
    if (prev != e.status) _milestone(g, e, prev, isNew);
    entries[g.id] = e;
    db.put('entries', g.id, e.toJson());
    if (!g.manual && games[g.id]?.ttbMain == null && igdb.configured) _fetchTtb(g.id);
    _changed();
  }

  void _milestone(Game g, Entry e, Status? prev, bool isNew) {
    final t = now;
    // Undo the auto-log from a status picked by mistake a few minutes ago.
    final last = _autoLog.remove(g.id);
    if (last != null && t - last.$2 < 10 * 60 * 1000) _deleteLogRaw(last.$1);

    LogKind? kind;
    int date = t;
    switch (e.status) {
      case Status.playing:
        e.startedAt ??= t;
        kind = prev == null || prev.unplayed || prev == Status.shelved ? LogKind.started : (prev.finished ? LogKind.replay : null);
        break;
      case Status.completed:
      case Status.played:
        e.finishedAt ??= t;
        date = e.finishedAt!;
        kind = LogKind.finished;
        break;
      case Status.mastered:
        e.finishedAt ??= t;
        date = e.finishedAt!;
        kind = LogKind.mastered;
        break;
      case Status.shelved:
        kind = LogKind.shelved;
        break;
      case Status.dropped:
        kind = LogKind.dropped;
        break;
      case Status.backlog:
      case Status.wishlist:
        kind = null;
    }
    if (kind == null) return;
    final l = LogItem(id: newId(), gameId: g.id, date: date, kind: kind, platform: e.platform);
    _insertLog(l);
    _autoLog[g.id] = (l.id, t);
  }

  /// Keep milestone log dates aligned with edited start/finish dates.
  void syncMilestoneDate(int gameId, LogKind kind, int date) {
    final l = logs.where((x) => x.gameId == gameId && x.kind == kind).firstOrNull;
    if (l == null || l.date == date) return;
    l.date = date;
    logs.sort((a, b) => b.date.compareTo(a.date));
    db.put('logs', l.id, l.toJson(), g: l.gameId, d: l.date);
  }

  Future<void> _fetchTtb(int id) async {
    try {
      final t = await igdb.ttb(id);
      final g = games[id];
      if (g == null || (t.$1 == null && t.$2 == null && t.$3 == null)) return;
      final ng = g.withTtb(t.$1, t.$2, t.$3);
      games[id] = ng;
      db.put('games', id, ng.toJson());
      notifyListeners();
    } catch (_) {}
  }

  void removeEntry(int id) {
    entries.remove(id);
    db.del('entries', id);
    final doomed = logs.where((l) => l.gameId == id).map((l) => l.id).toList();
    for (final l in doomed) {
      _deleteLogRaw(l);
    }
    _autoLog.remove(id);
    _changed();
  }

  // ───────────────────────── diary / logs ─────────────────────────

  void _insertLog(LogItem l) {
    logs.add(l);
    logs.sort((a, b) => b.date.compareTo(a.date));
    db.put('logs', l.id, l.toJson(), g: l.gameId, d: l.date);
  }

  void _deleteLogRaw(String id) {
    logs.removeWhere((l) => l.id == id);
    db.del('logs', id);
  }

  LogItem addLog(Game g, LogKind kind, {int? date, int minutes = 0, String note = '', String? platform}) {
    cacheGame(g);
    final l = LogItem(id: newId(), gameId: g.id, date: date ?? now, kind: kind, minutes: minutes, note: note, platform: platform);
    _insertLog(l);
    _changed();
    return l;
  }

  void updateLog(LogItem l) {
    logs.sort((a, b) => b.date.compareTo(a.date));
    db.put('logs', l.id, l.toJson(), g: l.gameId, d: l.date);
    _changed();
  }

  void deleteLog(String id) {
    _deleteLogRaw(id);
    _changed();
  }

  Iterable<LogItem> logsFor(int gameId) => logs.where((l) => l.gameId == gameId);

  void _derive() {
    final m = <int, int>{};
    final c = <int, int>{};
    for (final l in logs) {
      if (l.kind == LogKind.session) {
        m[l.gameId] = (m[l.gameId] ?? 0) + l.minutes;
        c[l.gameId] = (c[l.gameId] ?? 0) + 1;
      }
    }
    _sessionMinutes = m;
    _sessionCount = c;
  }

  int minutesFor(int gameId) {
    if (_sessionMinutes == null) _derive();
    return (_sessionMinutes![gameId] ?? 0) + (entries[gameId]?.baseMinutes ?? 0);
  }

  int sessionsFor(int gameId) {
    if (_sessionCount == null) _derive();
    return _sessionCount![gameId] ?? 0;
  }

  int get totalMinutes {
    if (_sessionMinutes == null) _derive();
    var t = _sessionMinutes!.values.fold<int>(0, (a, b) => a + b);
    for (final e in entries.values) {
      t += e.baseMinutes;
    }
    return t;
  }

  LogItem? lastSession(int gameId) => logs.where((l) => l.gameId == gameId && l.kind == LogKind.session).firstOrNull;

  // ───────────────────────── play sessions ─────────────────────────

  ActiveSession? get session {
    final s = kv['session'];
    if (s == null) return null;
    final p = s.split(':');
    if (p.length != 2) return null;
    final g = int.tryParse(p[0]), t = int.tryParse(p[1]);
    if (g == null || t == null) return null;
    return ActiveSession(g, t);
  }

  void startSession(Game g) {
    cacheGame(g);
    setPref('session', '${g.id}:$now');
  }

  void endSession() => setPref('session', null);

  void saveSession(Game g, {required int start, required int minutes, String note = '', String? platform, Status? newStatus}) {
    endSession();
    addLog(g, LogKind.session, date: start, minutes: minutes, note: note, platform: platform);
    final e = entries[g.id];
    if (newStatus != null && newStatus != e?.status) {
      setStatus(g, newStatus);
    } else if (e == null || e.status.unplayed || e.status == Status.shelved) {
      setStatus(g, Status.playing);
    }
  }

  // ───────────────────────── lists ─────────────────────────

  List<GameList> get sortedLists => lists.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  GameList createList(String title, {String desc = '', bool ranked = false, List<int>? items}) {
    final l = GameList(id: newId(), title: title, desc: desc, ranked: ranked, items: items);
    saveList(l);
    return l;
  }

  void saveList(GameList l) {
    l.updatedAt = now;
    lists[l.id] = l;
    db.put('lists', l.id, l.toJson());
    _changed();
  }

  void deleteList(String id) {
    lists.remove(id);
    db.del('lists', id);
    _changed();
  }

  void toggleInList(GameList l, Game g) {
    cacheGame(g);
    if (l.items.contains(g.id)) {
      l.items.remove(g.id);
    } else {
      l.items.add(g.id);
    }
    saveList(l);
  }

  // ───────────────────────── discover rails ─────────────────────────

  Future<List<Game>> rail(String key, {bool force = false}) async {
    final fresh = igdb.railFresh(key);
    final games = await igdb.rail(key, force: force);
    if (!fresh || force) {
      setKv('rail_$key', jsonEncode({'at': now, 'g': games.map((g) => g.toJson()).toList()}));
    }
    return games;
  }

  // ───────────────────────── manual games ─────────────────────────

  Game createManualGame({required String name, String? coverUrl, int? year, List<String> platforms = const [], List<String> genres = const [], String? dev}) {
    final g = Game(
      id: -now,
      name: name,
      cover: coverUrl?.trim().isEmpty == true ? null : coverUrl?.trim(),
      released: year == null ? null : DateTime(year, 6, 1).millisecondsSinceEpoch ~/ 1000,
      platforms: platforms,
      genres: genres,
      devs: dev == null || dev.isEmpty ? const [] : [dev],
    );
    cacheGame(g);
    return g;
  }

  // ───────────────────────── xbox ─────────────────────────

  Map<String, XboxTitle>? _xboxTitles;

  /// Last synced Xbox title history, by title id.
  Map<String, XboxTitle> get xboxTitles {
    if (_xboxTitles != null) return _xboxTitles!;
    try {
      final l = jsonDecode(kv['xbl_titles'] ?? '[]') as List;
      _xboxTitles = {for (final j in l.cast<Map<String, dynamic>>()) j['id'] as String: XboxTitle.fromJson(j)};
    } catch (_) {
      _xboxTitles = {};
    }
    return _xboxTitles!;
  }

  XboxProfile? get xboxProfile {
    final s = kv['xbl_profile'];
    if (s == null) return null;
    try {
      return XboxProfile.fromJson(jsonDecode(s));
    } catch (_) {
      return null;
    }
  }

  XboxTitle? xboxFor(int gameId) => xboxTitles.values.where((t) => t.gameId == gameId).firstOrNull;

  Set<String> get xboxSkipped => (kv['xbl_skip'] ?? '').split(',').where((s) => s.isNotEmpty).toSet();

  Future<XboxProfile> connectXbox(String key) async {
    final old = kv['xbl_key'];
    setKv('xbl_key', key.trim());
    try {
      final p = await xbox.profile();
      setPref('xbl_profile', jsonEncode(p.toJson()));
      return p;
    } catch (_) {
      setKv('xbl_key', old);
      rethrow;
    }
  }

  void disconnectXbox() {
    for (final k in ['xbl_key', 'xbl_profile']) {
      setKv(k, null);
    }
    notifyListeners();
  }

  /// Pulls profile, title history and playtime. Unlinked titles get an IGDB
  /// suggestion (title id -> (game, confident)) for the review screen.
  Future<(List<XboxTitle>, Map<String, (Game, bool)>)> fetchXbox({void Function(String stage)? onStage}) async {
    onStage?.call('Reading your profile…');
    final p = await xbox.profile();
    setKv('xbl_profile', jsonEncode(p.toJson()));
    onStage?.call('Loading your games…');
    final titles = await xbox.titles();
    onStage?.call('Counting your hours…');
    try {
      final mins = await xbox.minutesPlayed(p.xuid, titles.map((t) => t.id).toList());
      for (final t in titles) {
        t.minutes = mins[t.id] ?? 0;
      }
    } on XboxError catch (e) {
      if (e.code == 429) rethrow; // playtime is optional; anything else just skips it
    }
    final known = xboxTitles;
    for (final t in titles) {
      final g = known[t.id]?.gameId;
      if (g != null && games.containsKey(g)) t.gameId = g;
    }
    final suggestions = <String, (Game, bool)>{};
    final todo = {for (final t in titles.where((t) => t.gameId == null)) t.id: t.searchName};
    if (todo.isNotEmpty && igdb.configured) {
      onStage?.call('Matching ${todo.length} games…');
      suggestions.addAll(await igdb.matchNames(todo, onProgress: (n) => onStage?.call('Matching games… $n/${todo.length}')));
    }
    return (titles, suggestions);
  }

  /// Applies a reviewed import. Existing entries keep their status and rating;
  /// only the Xbox playtime added since the last sync is added to them.
  int applyXbox(List<XboxTitle> all, List<(XboxTitle, Game, Status)> picked) {
    final prev = xboxTitles;
    final pickedIds = picked.map((p) => p.$1.id).toSet();
    var added = 0;
    for (final (t, g, status) in picked) {
      cacheGame(g);
      final before = prev[t.id];
      final already = before?.gameId == g.id ? before!.minutes : 0;
      final platform = _xboxPlatform(t, g);
      final e = entries[g.id];
      if (e == null) {
        added++;
        final ne = Entry(gameId: g.id, status: status, platform: platform, baseMinutes: t.minutes);
        if (status.finished && t.mastered) ne.finishedAt = t.lastPlayed;
        entries[g.id] = ne;
        db.put('entries', g.id, ne.toJson());
      } else {
        e.baseMinutes = (e.baseMinutes + t.minutes - already).clamp(0, 1 << 30);
        e.platform ??= platform;
        e.updatedAt = now;
        db.put('entries', g.id, e.toJson());
      }
      t.gameId = g.id;
    }
    // Keep earlier links for titles not imported this time, but only count
    // minutes we actually added.
    for (final t in all) {
      if (pickedIds.contains(t.id)) continue;
      final before = prev[t.id];
      t.gameId = before?.gameId;
      t.minutes = before?.minutes ?? 0;
    }
    final skipped = all.where((t) => !pickedIds.contains(t.id) && t.gameId == null).map((t) => t.id);
    setKv('xbl_skip', skipped.join(','));
    setKv('xbl_titles', jsonEncode(all.map((t) => t.toJson()).toList()));
    setKv('xbl_synced', '$now');
    _xboxTitles = null;
    _changed();
    return added;
  }

  static String? _xboxPlatform(XboxTitle t, Game g) {
    const map = {
      'XboxSeries': 'Series X|S',
      'Scarlett': 'Series X|S',
      'XboxOne': 'XONE',
      'Xbox360': 'X360',
      'PC': 'PC',
      'Win32': 'PC',
    };
    for (final d in t.devices) {
      final p = map[d];
      if (p != null && (g.platforms.isEmpty || g.platforms.contains(p))) return p;
    }
    final first = t.devices.map((d) => map[d]).whereType<String>().firstOrNull;
    return first;
  }

  // ───────────────────────── backup ─────────────────────────

  Map<String, dynamic> exportData() => {
    'app': 'savepoint',
    'v': 1,
    'at': now,
    'games': games.values.map((g) => g.toJson()).toList(),
    'entries': entries.values.map((e) => e.toJson()).toList(),
    'logs': logs.map((l) => l.toJson()).toList(),
    'lists': lists.values.map((l) => l.toJson()).toList(),
    'kv': {
      for (final e in kv.entries)
        if (!e.key.startsWith('igdb_') && !e.key.startsWith('rail_') && e.key != 'xbl_key') e.key: e.value,
    },
  };

  String exportCsv() {
    String esc(Object? v) {
      final s = (v ?? '').toString();
      return s.contains(RegExp(r'[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
    }

    String d(int? ms) => ms == null ? '' : DateTime.fromMillisecondsSinceEpoch(ms).toIso8601String().substring(0, 10);
    final b = StringBuffer('Title,Status,Rating (0-5),Liked,Platform,Hours,Started,Finished,Released,Developer,Genres,Tags,Review\n');
    for (final e in entries.values) {
      final g = games[e.gameId];
      b.writeln(
        [
          g?.name,
          e.status.label,
          e.rating == 0 ? '' : (e.rating / 2).toString(),
          e.liked ? 'yes' : '',
          e.platform,
          (minutesFor(e.gameId) / 60).toStringAsFixed(1),
          d(e.startedAt),
          d(e.finishedAt),
          g?.year,
          g?.dev,
          g?.genres.join('; '),
          e.tags.join('; '),
          e.review,
        ].map(esc).join(','),
      );
    }
    return b.toString();
  }

  Future<void> importData(Map<String, dynamic> j) async {
    if (j['app'] != 'savepoint') throw const FormatException('Not a Savepoint backup');
    List<Map<String, dynamic>> list(String k) => (j[k] as List? ?? const []).cast<Map<String, dynamic>>();
    final k = (j['kv'] as Map? ?? const {}).map((a, b) => MapEntry(a.toString(), b.toString()));
    await db.replaceAll(games: list('games'), entries: list('entries'), logs: list('logs'), lists: list('lists'), kv: k);
    final merged = {...kv, ...k};
    _hydrate(list('games'), list('entries'), list('logs'), list('lists'), merged);
    _autoLog.clear();
    accentVN.value = accent;
    notifyListeners();
  }
}
