import 'package:flutter/material.dart';

enum Status {
  playing('Playing', 'PLAYING', Color(0xFF4FD8E8), Icons.play_arrow_rounded),
  completed('Completed', 'BEATEN', Color(0xFFB4F25A), Icons.flag_rounded),
  mastered('100%', 'MASTERED', Color(0xFFFFC53D), Icons.workspace_premium_rounded),
  played('Played', 'PLAYED', Color(0xFF6FE3B4), Icons.check_rounded),
  shelved('Shelved', 'SHELVED', Color(0xFFFFA24C), Icons.pause_rounded),
  dropped('Abandoned', 'DROPPED', Color(0xFFFF5D5D), Icons.close_rounded),
  backlog('Backlog', 'BACKLOG', Color(0xFFA48BFF), Icons.inventory_2_rounded),
  wishlist('Wishlist', 'WISHLIST', Color(0xFFFF7EB9), Icons.bookmark_rounded);

  const Status(this.label, this.tag, this.color, this.icon);
  final String label;
  final String tag;
  final Color color;
  final IconData icon;

  bool get finished => this == completed || this == mastered || this == played;
  bool get unplayed => this == backlog || this == wishlist;

  static Status parse(String? s) => Status.values.firstWhere((e) => e.name == s, orElse: () => Status.backlog);
}

String? img(String? id, [String size = 't_cover_big']) {
  if (id == null || id.isEmpty) return null;
  if (id.startsWith('http')) return id;
  return 'https://images.igdb.com/igdb/image/upload/$size/$id.jpg';
}

List<String> _strs(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : const [];

class Game {
  final int id;
  final String name;
  final String? cover;
  final String? hero;
  final int? released; // unix seconds
  final List<String> genres;
  final List<String> platforms;
  final List<String> devs;
  final double? score;
  final int? ratingCount;
  final String? summary;
  final int? ttbQuick, ttbMain, ttbFull; // seconds
  final String? type;

  // detail-only fields (not persisted in the library snapshot)
  final String? storyline;
  final double? critic;
  final List<String> themes, modes, perspectives, publishers, platformsFull, shots, arts, videos, franchises;
  final List<Game> similar, dlcs, family;
  final List<(String, String)> links;
  final List<(String, String)> releases;
  final bool full;

  const Game({
    required this.id,
    required this.name,
    this.cover,
    this.hero,
    this.released,
    this.genres = const [],
    this.platforms = const [],
    this.devs = const [],
    this.score,
    this.ratingCount,
    this.summary,
    this.ttbQuick,
    this.ttbMain,
    this.ttbFull,
    this.type,
    this.storyline,
    this.critic,
    this.themes = const [],
    this.modes = const [],
    this.perspectives = const [],
    this.publishers = const [],
    this.platformsFull = const [],
    this.shots = const [],
    this.arts = const [],
    this.videos = const [],
    this.franchises = const [],
    this.similar = const [],
    this.dlcs = const [],
    this.family = const [],
    this.links = const [],
    this.releases = const [],
    this.full = false,
  });

  bool get manual => id < 0;
  DateTime? get date => released == null ? null : DateTime.fromMillisecondsSinceEpoch(released! * 1000);
  int? get year => date?.year;
  bool get upcoming => released == null ? false : date!.isAfter(DateTime.now());
  String? get coverUrl => img(cover);
  String? get heroUrl => img(hero ?? cover, hero == null ? 't_cover_big_2x' : 't_screenshot_huge');
  String get dev => devs.isEmpty ? '' : devs.first;
  double? get mainHours => ttbMain == null ? null : ttbMain! / 3600;

  factory Game.fromIgdb(Map<String, dynamic> j, {bool full = false}) {
    List<String> names(String k) => (j[k] as List?)?.map((e) => (e is Map ? e['name'] : e).toString()).toList() ?? const [];
    List<String> ids(String k) => (j[k] as List?)?.whereType<Map>().map((e) => e['image_id']?.toString()).whereType<String>().toList() ?? const [];

    final companies = (j['involved_companies'] as List?)?.whereType<Map>() ?? const [];
    final devs = companies.where((c) => c['developer'] == true).map((c) => c['company']?['name']).whereType<String>().toList();
    final pubs = companies.where((c) => c['publisher'] == true).map((c) => c['company']?['name']).whereType<String>().toList();
    final plats = (j['platforms'] as List?)?.whereType<Map>() ?? const [];
    final arts = ids('artworks');
    final shots = ids('screenshots');

    List<Game> sub(String k) =>
        (j[k] as List?)?.whereType<Map<String, dynamic>>().where((e) => e['name'] != null).map((e) => Game.fromIgdb(e)).toList() ?? const [];

    final links = <(String, String)>[];
    for (final w in (j['websites'] as List?)?.whereType<Map>() ?? const <Map>[]) {
      final url = w['url']?.toString();
      if (url == null) continue;
      final label = _siteLabel(url);
      if (label != null && !links.any((l) => l.$1 == label)) links.add((label, url));
    }
    final rel = <(String, String)>[];
    for (final r in (j['release_dates'] as List?)?.whereType<Map>() ?? const <Map>[]) {
      final p = r['platform'];
      final pn = p is Map ? (p['abbreviation'] ?? p['name'])?.toString() : null;
      final h = r['human']?.toString();
      if (pn != null && h != null && !rel.any((x) => x.$1 == pn)) rel.add((pn, h));
    }
    final gt = j['game_type'];
    final type = gt is Map ? gt['type']?.toString() : null;

    return Game(
      id: (j['id'] as num).toInt(),
      name: (j['name'] ?? 'Untitled').toString(),
      cover: (j['cover'] is Map) ? j['cover']['image_id']?.toString() : null,
      hero: arts.isNotEmpty ? arts.first : (shots.isNotEmpty ? shots.first : null),
      released: (j['first_release_date'] as num?)?.toInt(),
      genres: names('genres'),
      platforms: plats.map((p) => (p['abbreviation'] ?? p['name'] ?? '').toString()).where((s) => s.isNotEmpty).toList(),
      platformsFull: plats.map((p) => (p['name'] ?? '').toString()).where((s) => s.isNotEmpty).toList(),
      devs: devs,
      publishers: pubs,
      score: (j['total_rating'] as num?)?.toDouble(),
      ratingCount: (j['total_rating_count'] as num?)?.toInt(),
      critic: (j['aggregated_rating'] as num?)?.toDouble(),
      summary: j['summary']?.toString(),
      storyline: j['storyline']?.toString(),
      themes: names('themes'),
      modes: names('game_modes'),
      perspectives: names('player_perspectives'),
      franchises: {...names('franchises'), ...names('collections')}.toList(),
      shots: shots,
      arts: arts,
      videos: (j['videos'] as List?)?.whereType<Map>().map((v) => v['video_id']?.toString()).whereType<String>().toList() ?? const [],
      similar: sub('similar_games'),
      dlcs: [...sub('dlcs'), ...sub('expansions'), ...sub('standalone_expansions')],
      family: [...sub('remakes'), ...sub('remasters'), if (j['parent_game'] is Map) Game.fromIgdb(j['parent_game'])],
      links: links,
      releases: rel,
      type: type,
      full: full,
    );
  }

  static String? _siteLabel(String url) {
    final u = url.toLowerCase();
    if (u.contains('store.steampowered')) return 'Steam';
    if (u.contains('gog.com')) return 'GOG';
    if (u.contains('epicgames')) return 'Epic';
    if (u.contains('playstation.com')) return 'PlayStation';
    if (u.contains('xbox.com') || u.contains('microsoft.com')) return 'Xbox';
    if (u.contains('nintendo.')) return 'Nintendo';
    if (u.contains('wikipedia')) return 'Wikipedia';
    if (u.contains('fandom.com') || u.contains('wiki')) return 'Wiki';
    if (u.contains('itch.io')) return 'itch.io';
    if (u.contains('reddit')) return 'Reddit';
    if (u.contains('youtube') ||
        u.contains('twitter') ||
        u.contains('x.com') ||
        u.contains('facebook') ||
        u.contains('instagram') ||
        u.contains('twitch') ||
        u.contains('discord')) {
      return null;
    }
    return 'Website';
  }

  /// Compact snapshot persisted with the library.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (cover != null) 'cover': cover,
    if (hero != null) 'hero': hero,
    if (released != null) 'rel': released,
    if (genres.isNotEmpty) 'genres': genres,
    if (platforms.isNotEmpty) 'plat': platforms,
    if (devs.isNotEmpty) 'devs': devs,
    if (score != null) 'score': score,
    if (ratingCount != null) 'rc': ratingCount,
    if (summary != null) 'sum': summary,
    if (ttbQuick != null) 'tq': ttbQuick,
    if (ttbMain != null) 'tm': ttbMain,
    if (ttbFull != null) 'tf': ttbFull,
    if (type != null) 'type': type,
    if (themes.isNotEmpty) 'themes': themes,
  };

  factory Game.fromJson(Map<String, dynamic> j) => Game(
    id: (j['id'] as num).toInt(),
    name: j['name'] ?? 'Untitled',
    cover: j['cover'],
    hero: j['hero'],
    released: (j['rel'] as num?)?.toInt(),
    genres: _strs(j['genres']),
    platforms: _strs(j['plat']),
    devs: _strs(j['devs']),
    score: (j['score'] as num?)?.toDouble(),
    ratingCount: (j['rc'] as num?)?.toInt(),
    summary: j['sum'],
    ttbQuick: (j['tq'] as num?)?.toInt(),
    ttbMain: (j['tm'] as num?)?.toInt(),
    ttbFull: (j['tf'] as num?)?.toInt(),
    type: j['type'],
    themes: _strs(j['themes']),
  );

  Game snapshot() => Game.fromJson(toJson());

  Game withTtb(int? q, int? m, int? f) => Game(
    id: id,
    name: name,
    cover: cover,
    hero: hero,
    released: released,
    genres: genres,
    platforms: platforms,
    devs: devs,
    score: score,
    ratingCount: ratingCount,
    summary: summary,
    type: type,
    themes: themes,
    ttbQuick: q ?? ttbQuick,
    ttbMain: m ?? ttbMain,
    ttbFull: f ?? ttbFull,
    storyline: storyline,
    critic: critic,
    modes: modes,
    perspectives: perspectives,
    publishers: publishers,
    platformsFull: platformsFull,
    shots: shots,
    arts: arts,
    videos: videos,
    franchises: franchises,
    similar: similar,
    dlcs: dlcs,
    family: family,
    links: links,
    releases: releases,
    full: full,
  );
}

class Entry {
  final int gameId;
  Status status;
  int rating; // 0..10 (half stars), 0 = unrated
  bool liked;
  String review;
  bool spoiler;
  String? platform;
  List<String> tags;
  int? startedAt; // ms
  int? finishedAt; // ms
  int addedAt;
  int updatedAt;
  int priority; // 0 none, 1 low, 2 med, 3 high
  int baseMinutes; // playtime logged before/outside sessions
  String notes;
  int? reviewedAt;

  Entry({
    required this.gameId,
    this.status = Status.backlog,
    this.rating = 0,
    this.liked = false,
    this.review = '',
    this.spoiler = false,
    this.platform,
    List<String>? tags,
    this.startedAt,
    this.finishedAt,
    int? addedAt,
    int? updatedAt,
    this.priority = 0,
    this.baseMinutes = 0,
    this.notes = '',
    this.reviewedAt,
  }) : tags = tags ?? [],
       addedAt = addedAt ?? DateTime.now().millisecondsSinceEpoch,
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  Entry copy() => Entry.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    'g': gameId,
    's': status.name,
    'r': rating,
    'l': liked,
    if (review.isNotEmpty) 'rv': review,
    if (spoiler) 'sp': true,
    if (platform != null) 'pf': platform,
    if (tags.isNotEmpty) 'tg': tags,
    if (startedAt != null) 'st': startedAt,
    if (finishedAt != null) 'fi': finishedAt,
    'ad': addedAt,
    'up': updatedAt,
    if (priority != 0) 'pr': priority,
    if (baseMinutes != 0) 'bm': baseMinutes,
    if (notes.isNotEmpty) 'nt': notes,
    if (reviewedAt != null) 'ra': reviewedAt,
  };

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
    gameId: (j['g'] as num).toInt(),
    status: Status.parse(j['s']),
    rating: (j['r'] as num?)?.toInt() ?? 0,
    liked: j['l'] == true,
    review: j['rv'] ?? '',
    spoiler: j['sp'] == true,
    platform: j['pf'],
    tags: _strs(j['tg']),
    startedAt: (j['st'] as num?)?.toInt(),
    finishedAt: (j['fi'] as num?)?.toInt(),
    addedAt: (j['ad'] as num?)?.toInt(),
    updatedAt: (j['up'] as num?)?.toInt(),
    priority: (j['pr'] as num?)?.toInt() ?? 0,
    baseMinutes: (j['bm'] as num?)?.toInt() ?? 0,
    notes: j['nt'] ?? '',
    reviewedAt: (j['ra'] as num?)?.toInt(),
  );
}

enum LogKind {
  session('Session', Icons.sports_esports_rounded),
  started('Started', Icons.play_arrow_rounded),
  finished('Beaten', Icons.flag_rounded),
  mastered('100% complete', Icons.workspace_premium_rounded),
  shelved('Shelved', Icons.pause_rounded),
  dropped('Abandoned', Icons.close_rounded),
  replay('Replay', Icons.replay_rounded);

  const LogKind(this.label, this.icon);
  final String label;
  final IconData icon;
  static LogKind parse(String? s) => LogKind.values.firstWhere((e) => e.name == s, orElse: () => LogKind.session);
}

class LogItem {
  final String id;
  final int gameId;
  int date; // ms
  LogKind kind;
  int minutes;
  String note;
  String? platform;

  LogItem({required this.id, required this.gameId, required this.date, required this.kind, this.minutes = 0, this.note = '', this.platform});

  Map<String, dynamic> toJson() => {
    'id': id,
    'g': gameId,
    'd': date,
    'k': kind.name,
    if (minutes != 0) 'm': minutes,
    if (note.isNotEmpty) 'n': note,
    if (platform != null) 'p': platform,
  };

  factory LogItem.fromJson(Map<String, dynamic> j) => LogItem(
    id: j['id'],
    gameId: (j['g'] as num).toInt(),
    date: (j['d'] as num).toInt(),
    kind: LogKind.parse(j['k']),
    minutes: (j['m'] as num?)?.toInt() ?? 0,
    note: j['n'] ?? '',
    platform: j['p'],
  );

  DateTime get when => DateTime.fromMillisecondsSinceEpoch(date);
}

class GameList {
  final String id;
  String title;
  String desc;
  bool ranked;
  List<int> items;
  int createdAt;
  int updatedAt;

  GameList({required this.id, required this.title, this.desc = '', this.ranked = false, List<int>? items, int? createdAt, int? updatedAt})
    : items = items ?? [],
      createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {'id': id, 't': title, 'd': desc, 'r': ranked, 'i': items, 'c': createdAt, 'u': updatedAt};

  factory GameList.fromJson(Map<String, dynamic> j) => GameList(
    id: j['id'],
    title: j['t'] ?? 'List',
    desc: j['d'] ?? '',
    ranked: j['r'] == true,
    items: (j['i'] as List?)?.map((e) => (e as num).toInt()).toList(),
    createdAt: (j['c'] as num?)?.toInt(),
    updatedAt: (j['u'] as num?)?.toInt(),
  );
}

/// A running play session (the "check-in").
class ActiveSession {
  final int gameId;
  final int start; // ms
  const ActiveSession(this.gameId, this.start);
  Duration get elapsed => DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(start));
}
