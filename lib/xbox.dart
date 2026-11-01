import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class XboxError implements Exception {
  final String message;
  final int? code;
  XboxError(this.message, [this.code]);
  @override
  String toString() => message;
}

class XboxProfile {
  final String xuid;
  final String gamertag;
  final int gamerscore;
  final String? pic;
  const XboxProfile({required this.xuid, required this.gamertag, required this.gamerscore, this.pic});

  Map<String, dynamic> toJson() => {'x': xuid, 'gt': gamertag, 'gs': gamerscore, 'pic': ?pic};
  factory XboxProfile.fromJson(Map<String, dynamic> j) =>
      XboxProfile(xuid: j['x'], gamertag: j['gt'] ?? '', gamerscore: (j['gs'] as num?)?.toInt() ?? 0, pic: j['pic']);
}

/// One game from your Xbox title history, plus what Savepoint linked it to.
class XboxTitle {
  final String id;
  final String name;
  final String? image;
  final List<String> devices;
  final int? lastPlayed; // ms
  final int ach, achTotal, gs, gsTotal;
  final double progress; // 0..100
  int minutes;
  int? gameId; // linked IGDB / manual game

  XboxTitle({
    required this.id,
    required this.name,
    this.image,
    this.devices = const [],
    this.lastPlayed,
    this.ach = 0,
    this.achTotal = 0,
    this.gs = 0,
    this.gsTotal = 0,
    this.progress = 0,
    this.minutes = 0,
    this.gameId,
  });

  bool get mastered => achTotal > 0 && ach >= achTotal;

  factory XboxTitle.fromApi(Map<String, dynamic> j) {
    final a = j['achievement'] is Map ? j['achievement'] as Map : const {};
    final h = j['titleHistory'] is Map ? j['titleHistory'] as Map : const {};
    int n(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
    return XboxTitle(
      id: '${j['titleId']}',
      name: _clean('${j['name'] ?? 'Untitled'}'),
      image: j['displayImage']?.toString(),
      devices: (j['devices'] as List?)?.map((e) => '$e').toList() ?? const [],
      lastPlayed: DateTime.tryParse('${h['lastTimePlayed'] ?? ''}')?.millisecondsSinceEpoch,
      ach: n(a['currentAchievements']),
      achTotal: n(a['totalAchievements']),
      gs: n(a['currentGamerscore']),
      gsTotal: n(a['totalGamerscore']),
      progress: (a['progressPercentage'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'n': name,
    'img': ?image,
    if (devices.isNotEmpty) 'dv': devices,
    'lp': ?lastPlayed,
    'a': ach,
    'at': achTotal,
    'gs': gs,
    'gst': gsTotal,
    'p': progress,
    'm': minutes,
    'g': ?gameId,
  };

  factory XboxTitle.fromJson(Map<String, dynamic> j) => XboxTitle(
    id: j['id'],
    name: j['n'] ?? 'Untitled',
    image: j['img'],
    devices: (j['dv'] as List?)?.map((e) => '$e').toList() ?? const [],
    lastPlayed: (j['lp'] as num?)?.toInt(),
    ach: (j['a'] as num?)?.toInt() ?? 0,
    achTotal: (j['at'] as num?)?.toInt() ?? 0,
    gs: (j['gs'] as num?)?.toInt() ?? 0,
    gsTotal: (j['gst'] as num?)?.toInt() ?? 0,
    progress: (j['p'] as num?)?.toDouble() ?? 0,
    minutes: (j['m'] as num?)?.toInt() ?? 0,
    gameId: (j['g'] as num?)?.toInt(),
  );

  static String _clean(String s) => s.replaceAll(RegExp('[™®©]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Xbox store names carry edition / platform noise; strip it for IGDB search.
  String get searchName {
    var s = name;
    s = s.replaceAll(RegExp(r'\s*[\(\[][^\)\]]*(xbox|windows|pc|edition|game preview)[^\)\]]*[\)\]]', caseSensitive: false), '');
    s = s.replaceAll(
      RegExp(
        r'\s*[-–:]?\s*(for windows( 10)?|windows( 10)? edition|xbox (one|series x\|s|series x|360) edition|xbox (one|series x\|s|series x)|(standard|game of the year|goty|definitive|deluxe|complete) edition|game preview)\s*$',
        caseSensitive: false,
      ),
      '',
    );
    return s.trim().isEmpty ? name : s.trim();
  }
}

/// OpenXBL (xbl.io) client. Microsoft no longer lets personal accounts register
/// their own Xbox Live apps, so this goes through OpenXBL with your own API key.
class Xbox {
  Xbox({required this.read});

  final String? Function(String key) read;
  final _client = http.Client();
  static const _base = 'https://xbl.io/api/v2';

  String get key => read('xbl_key') ?? '';
  bool get configured => key.isNotEmpty;

  Future<dynamic> _req(String path, {Object? body}) async {
    if (!configured) throw XboxError('Add your OpenXBL key in Settings → Xbox.');
    final headers = {
      'X-Authorization': key,
      'Accept': 'application/json',
      // titleHistory rejects requests without a real locale.
      'Accept-Language': 'en-US',
      if (body != null) 'Content-Type': 'application/json',
    };
    final uri = Uri.parse('$_base$path');
    final http.Response r;
    try {
      r = await (body == null ? _client.get(uri, headers: headers) : _client.post(uri, headers: headers, body: jsonEncode(body)))
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw XboxError('Xbox Live took too long to answer.');
    } catch (_) {
      throw XboxError('You seem to be offline.');
    }
    if (r.statusCode == 401 || r.statusCode == 403) throw XboxError('OpenXBL rejected your key (${r.statusCode}). Copy it again from xbl.io.', r.statusCode);
    if (r.statusCode == 429) throw XboxError('OpenXBL rate limit reached. Free keys allow about 150 calls an hour, so try again later.', 429);
    if (r.statusCode != 200) throw XboxError('OpenXBL error ${r.statusCode}', r.statusCode);
    final dynamic j;
    try {
      j = jsonDecode(r.body);
    } catch (_) {
      throw XboxError('OpenXBL sent something unexpected.');
    }
    // Errors sometimes come back as a bare string with a 200.
    if (j is String) throw XboxError('OpenXBL: $j');
    return j is Map && j.containsKey('content') ? j['content'] : j;
  }

  Future<XboxProfile> profile() async {
    final j = await _req('/account');
    final users = j is Map ? j['profileUsers'] as List? : null;
    if (users == null || users.isEmpty) throw XboxError('OpenXBL didn’t return a profile.');
    final u = users.first as Map;
    final s = {for (final e in (u['settings'] as List? ?? const []).whereType<Map>()) '${e['id']}': '${e['value']}'};
    return XboxProfile(
      xuid: '${u['id']}',
      gamertag: s['Gamertag'] ?? s['ModernGamertag'] ?? 'Xbox player',
      gamerscore: int.tryParse(s['Gamerscore'] ?? '') ?? 0,
      pic: s['GameDisplayPicRaw'],
    );
  }

  /// Every game you've played on Xbox / PC Game Pass, newest first.
  Future<List<XboxTitle>> titles() async {
    final j = await _req('/player/titleHistory');
    final list = (j is Map ? j['titles'] as List? : null) ?? const [];
    final out = <XboxTitle>[];
    for (final t in list.whereType<Map<String, dynamic>>()) {
      final type = t['type']?.toString();
      if (type != null && type != 'Game') continue; // skip apps like Netflix
      if (t['titleId'] == null) continue;
      out.add(XboxTitle.fromApi(t));
    }
    out.sort((a, b) => (b.lastPlayed ?? 0).compareTo(a.lastPlayed ?? 0));
    return out;
  }

  /// Minutes played per title id. Titles that don't track it are left out.
  Future<Map<String, int>> minutesPlayed(String xuid, List<String> titleIds) async {
    final out = <String, int>{};
    for (var i = 0; i < titleIds.length; i += 100) {
      final chunk = titleIds.sublist(i, (i + 100).clamp(0, titleIds.length));
      final j = await _req(
        '/player/stats',
        body: {
          'arrangebyfield': 'xuid',
          'xuids': [xuid],
          'stats': [
            for (final t in chunk) {'name': 'MinutesPlayed', 'titleId': t},
          ],
        },
      );
      // Response: statlistscollection[].stats[] {titleid, name, value}. Walk it
      // loosely so small shape changes don't break the sync.
      final stats = <Map>[];
      void walk(Object? v) {
        if (v is Map) {
          if (v['name'] == 'MinutesPlayed' && v.containsKey('value')) {
            stats.add(v);
          } else {
            v.values.forEach(walk);
          }
        } else if (v is List) {
          v.forEach(walk);
        }
      }

      walk(j);
      for (var k = 0; k < stats.length; k++) {
        final s = stats[k];
        final id = (s['titleid'] ?? s['titleId'])?.toString() ?? (k < chunk.length ? chunk[k] : null);
        final m = int.tryParse('${s['value'] ?? ''}');
        if (id != null && m != null && m > 0) out[id] = m;
      }
    }
    return out;
  }
}
