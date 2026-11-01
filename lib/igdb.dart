import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class IgdbError implements Exception {
  final String message;
  final int? code;
  IgdbError(this.message, [this.code]);
  @override
  String toString() => message;
}

/// IGDB (Twitch) API client. Credentials are your own Twitch app keys —
/// this app is single-user, so they live on-device only.
class Igdb {
  Igdb({required this.read, required this.write});

  final String? Function(String key) read;
  final void Function(String key, String? value) write;
  final _client = http.Client();
  Future<String>? _pendingToken;

  final Map<int, Game> _details = {};
  final Map<String, (DateTime, List<Game>)> _rails = {};

  String get clientId => read('igdb_id') ?? '';
  String get secret => read('igdb_secret') ?? '';
  bool get configured => clientId.isNotEmpty && secret.isNotEmpty;

  static const lite =
      'fields name,cover.image_id,artworks.image_id,screenshots.image_id,first_release_date,'
      'genres.name,themes.name,platforms.abbreviation,platforms.name,total_rating,total_rating_count,'
      'involved_companies.developer,involved_companies.company.name,summary;';

  static const _fullBase =
      'name,cover.image_id,artworks.image_id,screenshots.image_id,first_release_date,'
      'genres.name,themes.name,game_modes.name,player_perspectives.name,platforms.abbreviation,platforms.name,'
      'total_rating,total_rating_count,aggregated_rating,summary,storyline,'
      'involved_companies.developer,involved_companies.publisher,involved_companies.company.name,'
      'franchises.name,collections.name,videos.video_id,websites.url,'
      'release_dates.human,release_dates.platform.abbreviation,release_dates.platform.name,'
      'similar_games.name,similar_games.cover.image_id,similar_games.first_release_date,'
      'dlcs.name,dlcs.cover.image_id,dlcs.first_release_date,'
      'expansions.name,expansions.cover.image_id,expansions.first_release_date,'
      'standalone_expansions.name,standalone_expansions.cover.image_id,standalone_expansions.first_release_date,'
      'remakes.name,remakes.cover.image_id,remakes.first_release_date,'
      'remasters.name,remasters.cover.image_id,remasters.first_release_date,'
      'parent_game.name,parent_game.cover.image_id,parent_game.first_release_date';

  void resetToken() {
    write('igdb_token', null);
    write('igdb_token_exp', null);
    _pendingToken = null;
  }

  Future<String> _token() {
    final t = read('igdb_token');
    final exp = int.tryParse(read('igdb_token_exp') ?? '') ?? 0;
    if (t != null && DateTime.now().millisecondsSinceEpoch < exp) return Future.value(t);
    return _pendingToken ??= _fetchToken().whenComplete(() => _pendingToken = null);
  }

  Future<String> _fetchToken() async {
    if (!configured) throw IgdbError('Add your IGDB keys in Settings to search games.');
    final uri = Uri.https('id.twitch.tv', '/oauth2/token', {'client_id': clientId, 'client_secret': secret, 'grant_type': 'client_credentials'});
    final http.Response r;
    try {
      r = await _client.post(uri).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw IgdbError('Twitch auth timed out — check your connection.');
    } catch (_) {
      throw IgdbError('You seem to be offline.');
    }
    if (r.statusCode != 200) {
      throw IgdbError('Twitch rejected your keys (${r.statusCode}). Double-check Client ID & Secret.', r.statusCode);
    }
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final token = j['access_token'] as String;
    final ttl = (j['expires_in'] as num?)?.toInt() ?? 3600;
    write('igdb_token', token);
    write('igdb_token_exp', '${DateTime.now().millisecondsSinceEpoch + (ttl - 300) * 1000}');
    return token;
  }

  Future<List<Map<String, dynamic>>> q(String endpoint, String body, {bool retry = true}) async {
    final token = await _token();
    final http.Response r;
    try {
      r = await _client
          .post(
            Uri.parse('https://api.igdb.com/v4/$endpoint'),
            headers: {'Client-ID': clientId, 'Authorization': 'Bearer $token', 'Accept': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw IgdbError('IGDB took too long to answer.');
    } catch (_) {
      throw IgdbError('You seem to be offline.');
    }
    if ((r.statusCode == 401 || r.statusCode == 403) && retry) {
      resetToken();
      return q(endpoint, body, retry: false);
    }
    if (r.statusCode == 429) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (retry) return q(endpoint, body, retry: false);
    }
    if (r.statusCode != 200) throw IgdbError('IGDB error ${r.statusCode}', r.statusCode);
    return (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
  }

  Future<bool> test() async {
    resetToken();
    await q('games', 'fields name; limit 1;');
    return true;
  }

  static String _esc(String s) => s.replaceAll('\\', ' ').replaceAll('"', '\\"');
  static int get _now => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  Future<List<Game>> search(String text) async {
    final t = text.trim();
    if (t.isEmpty) return [];
    final rows = await q('games', 'search "${_esc(t)}"; $lite where version_parent = null; limit 40;');
    final games = rows.map((e) => Game.fromIgdb(e)).toList();
    final lower = t.toLowerCase();
    int tier(Game g) {
      final n = g.name.toLowerCase();
      if (n == lower) return 3;
      if (n.startsWith(lower)) return 2;
      if (n.contains(lower)) return 1;
      return 0;
    }

    final idx = {for (var i = 0; i < games.length; i++) games[i].id: i};
    games.sort((a, b) {
      final c = tier(b).compareTo(tier(a));
      if (c != 0) return c;
      final pop = (b.ratingCount ?? 0).compareTo(a.ratingCount ?? 0);
      if ((a.ratingCount ?? 0) > 20 || (b.ratingCount ?? 0) > 20) return pop;
      return idx[a.id]!.compareTo(idx[b.id]!);
    });
    return games;
  }

  static String _norm(String s) => s.toLowerCase().replaceAll('&', 'and').replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Best IGDB match for each name, 10 searches per request via multiquery.
  /// Returns key -> (game, confident) where confident means an exact name match.
  Future<Map<String, (Game, bool)>> matchNames(Map<String, String> names, {void Function(int done)? onProgress}) async {
    final out = <String, (Game, bool)>{};
    final keys = names.keys.toList();
    const xboxish = {'XONE', 'Series X|S', 'X360', 'XBOX', 'PC'};
    for (var i = 0; i < keys.length; i += 10) {
      final chunk = keys.sublist(i, (i + 10).clamp(0, keys.length));
      final body = StringBuffer();
      for (var k = 0; k < chunk.length; k++) {
        body.write('query games "$k" { search "${_esc(names[chunk[k]]!)}"; $lite where version_parent = null; limit 8; };\n');
      }
      final rows = await q('multiquery', body.toString());
      for (final r in rows) {
        final k = int.tryParse('${r['name']}');
        if (k == null || k >= chunk.length) continue;
        final games = (r['result'] as List? ?? const []).whereType<Map<String, dynamic>>().map((e) => Game.fromIgdb(e)).toList();
        if (games.isEmpty) continue;
        final want = _norm(names[chunk[k]]!);
        int tier(Game g) {
          final n = _norm(g.name);
          if (n == want) return 3;
          if (n.startsWith(want) || want.startsWith(n)) return 2;
          return n.contains(want) || want.contains(n) ? 1 : 0;
        }

        int score(Game g) => tier(g) * 100000 + (g.platforms.any(xboxish.contains) ? 50000 : 0) + (g.ratingCount ?? 0).clamp(0, 49999);
        games.sort((a, b) => score(b).compareTo(score(a)));
        out[chunk[k]] = (games.first, tier(games.first) == 3);
      }
      onProgress?.call(i + chunk.length);
      if (i + 10 < keys.length) await Future.delayed(const Duration(milliseconds: 260));
    }
    return out;
  }

  Game? cachedDetail(int id) => _details[id];
  void forget(int id) => _details.remove(id);

  Future<Game> details(int id) async {
    final c = _details[id];
    if (c != null) return c;
    List<Map<String, dynamic>> rows;
    try {
      rows = await q('games', 'fields $_fullBase,game_type.type; where id = $id;');
    } on IgdbError catch (e) {
      if (e.code != 400) rethrow;
      rows = await q('games', 'fields $_fullBase; where id = $id;');
    }
    if (rows.isEmpty) throw IgdbError('Game not found');
    var g = Game.fromIgdb(rows.first, full: true);
    try {
      final t = await ttb(id);
      g = g.withTtb(t.$1, t.$2, t.$3);
    } catch (_) {}
    _details[id] = g;
    return g;
  }

  Future<(int?, int?, int?)> ttb(int id) async {
    final rows = await q('game_time_to_beats', 'fields hastily,normally,completely; where game_id = $id;');
    if (rows.isEmpty) return (null, null, null);
    final r = rows.first;
    int? n(String k) => (r[k] as num?)?.toInt();
    return (n('hastily'), n('normally'), n('completely'));
  }

  Future<List<Game>> byIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final rows = await q('games', '$lite where id = (${ids.join(',')}); limit ${ids.length};');
    final map = {for (final r in rows) (r['id'] as num).toInt(): Game.fromIgdb(r)};
    return [
      for (final i in ids)
        if (map[i] != null) map[i]!,
    ];
  }

  // ───── Discover rails (memoised for 6h in memory; persisted by the store) ─────

  List<Game>? railCache(String key) => _rails[key]?.$2;

  void seedRail(String key, List<Game> games, DateTime at) => _rails[key] = (at, games);

  bool railFresh(String key) {
    final r = _rails[key];
    return r != null && DateTime.now().difference(r.$1) < const Duration(hours: 6);
  }

  Future<List<Game>> rail(String key, {bool force = false}) async {
    if (!force && railFresh(key)) return _rails[key]!.$2;
    final games = await _loadRail(key);
    _rails[key] = (DateTime.now(), games);
    return games;
  }

  Future<List<Game>> _loadRail(String key) async {
    final now = _now;
    switch (key) {
      case 'trending':
        try {
          final pop = await q('popularity_primitives', 'fields game_id,value; sort value desc; limit 30; where popularity_type = 1;');
          final ids = pop.map((e) => (e['game_id'] as num).toInt()).toList();
          final games = await byIds(ids);
          if (games.length >= 6) return games;
        } catch (_) {}
        return _list(
          'where first_release_date > ${now - 86400 * 120} & first_release_date < $now & total_rating_count > 5; sort total_rating_count desc; limit 30;',
        );
      case 'anticipated':
        return _list('where first_release_date > $now & hypes > 3; sort hypes desc; limit 30;');
      case 'fresh':
        return _list('where first_release_date > ${now - 86400 * 60} & first_release_date < $now & hypes > 2; sort hypes desc; limit 30;');
      case 'greats':
        return _list('where total_rating_count > 400 & total_rating > 85; sort total_rating desc; limit 40;');
      case 'hidden':
        return _list(
          'where total_rating > 82 & total_rating_count > 25 & total_rating_count < 120 & first_release_date > ${now - 86400 * 365 * 8}; sort total_rating desc; limit 30;',
        );
    }
    return [];
  }

  Future<List<Game>> _list(String tail) async {
    final rows = await q('games', '$lite $tail');
    return rows.map((e) => Game.fromIgdb(e)).toList();
  }

  Future<List<Game>> browse({required String field, required int id, required String sort, int offset = 0}) {
    final now = _now;
    final filter = '$field = ($id)';
    switch (sort) {
      case 'new':
        return _list('where $filter & first_release_date < $now & version_parent = null; sort first_release_date desc; limit 30; offset $offset;');
      case 'popular':
        return _list('where $filter & version_parent = null; sort total_rating_count desc; limit 30; offset $offset;');
      case 'upcoming':
        return _list('where $filter & first_release_date > $now; sort hypes desc; limit 30; offset $offset;');
      default:
        return _list('where $filter & total_rating_count > 30; sort total_rating desc; limit 30; offset $offset;');
    }
  }
}

class Taxon {
  final String name;
  final String field;
  final int id;
  const Taxon(this.name, this.field, this.id);
}

const taxonomy = <Taxon>[
  Taxon('RPG', 'genres', 12),
  Taxon('Adventure', 'genres', 31),
  Taxon('Shooter', 'genres', 5),
  Taxon('Platformer', 'genres', 8),
  Taxon('Indie', 'genres', 32),
  Taxon('Strategy', 'genres', 15),
  Taxon('Puzzle', 'genres', 9),
  Taxon('Fighting', 'genres', 4),
  Taxon('Racing', 'genres', 10),
  Taxon('Simulator', 'genres', 13),
  Taxon('Sport', 'genres', 14),
  Taxon('Tactical', 'genres', 24),
  Taxon('Hack & Slash', 'genres', 25),
  Taxon('Visual Novel', 'genres', 34),
  Taxon('Card & Board', 'genres', 35),
  Taxon('Point & Click', 'genres', 2),
  Taxon('Music', 'genres', 7),
  Taxon('Arcade', 'genres', 33),
  Taxon('Horror', 'themes', 19),
  Taxon('Open World', 'themes', 38),
  Taxon('Survival', 'themes', 21),
  Taxon('Sci-fi', 'themes', 18),
  Taxon('Fantasy', 'themes', 17),
  Taxon('Stealth', 'themes', 23),
  Taxon('Sandbox', 'themes', 33),
  Taxon('Mystery', 'themes', 43),
];
