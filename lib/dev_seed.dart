import 'dart:math';

import 'models.dart';
import 'store.dart';

/// Demo data for UI testing. Only runs when built with --dart-define=SEED=true.
const kSeed = bool.fromEnvironment('SEED');

void seedDemo() {
  if (!kSeed || store.entries.isNotEmpty) return;
  final r = Random(7);
  final now = DateTime.now();
  int ts(int y, int m, int d) => DateTime(y, m, d, 20).millisecondsSinceEpoch ~/ 1000;
  int ms(int y, int m, int d) => DateTime(y, m, d, 20).millisecondsSinceEpoch;

  final data = <(String, String, List<String>, List<String>, int, int, Status, int, bool, String?)>[
    // name, dev, genres, platforms, releaseYear, ttbMainH, status, rating(0-10), liked, platformPlayed
    ('Elden Ring', 'FromSoftware', ['RPG', 'Adventure'], ['PS5', 'PC', 'XSX'], 2022, 58, Status.completed, 10, true, 'PS5'),
    ('Hades II', 'Supergiant Games', ['Roguelike', 'Indie', 'RPG'], ['PC', 'Switch'], 2025, 25, Status.playing, 0, false, 'PC'),
    ('Celeste', 'Maddy Makes Games', ['Platform', 'Indie'], ['PC', 'Switch'], 2018, 8, Status.mastered, 9, true, 'Switch'),
    ('Disco Elysium', 'ZA/UM', ['RPG', 'Adventure'], ['PC', 'PS5'], 2019, 22, Status.completed, 10, true, 'PC'),
    ('Baldur\'s Gate 3', 'Larian Studios', ['RPG', 'Strategy'], ['PC', 'PS5'], 2023, 75, Status.playing, 0, false, 'PC'),
    ('Outer Wilds', 'Mobius Digital', ['Adventure', 'Puzzle', 'Indie'], ['PC', 'PS4'], 2019, 17, Status.completed, 9, true, 'PC'),
    ('Persona 5 Royal', 'Atlus', ['RPG', 'Turn-based'], ['PS5', 'Switch'], 2019, 103, Status.shelved, 7, false, 'PS5'),
    ('Balatro', 'LocalThunk', ['Card & Board', 'Indie'], ['PC', 'Switch', 'iOS'], 2024, 12, Status.played, 8, false, 'Steam Deck'),
    ('Metaphor: ReFantazio', 'Studio Zero', ['RPG'], ['PS5', 'PC'], 2024, 70, Status.backlog, 0, false, null),
    ('Astro Bot', 'Team Asobi', ['Platform', 'Adventure'], ['PS5'], 2024, 11, Status.completed, 9, true, 'PS5'),
    ('Cyberpunk 2077', 'CD Projekt RED', ['RPG', 'Shooter'], ['PC', 'PS5'], 2020, 26, Status.dropped, 5, false, 'PC'),
    ('Hollow Knight: Silksong', 'Team Cherry', ['Platform', 'Indie'], ['Switch', 'PC'], 2025, 30, Status.backlog, 0, false, null),
    ('Clair Obscur: Expedition 33', 'Sandfall Interactive', ['RPG', 'Turn-based'], ['PS5', 'PC'], 2025, 30, Status.completed, 9, true, 'PS5'),
    ('Split Fiction', 'Hazelight', ['Adventure', 'Platform'], ['PS5', 'PC'], 2025, 14, Status.completed, 8, false, 'PS5'),
    ('The Witcher 4', 'CD Projekt RED', ['RPG'], ['PC', 'PS6'], 2027, 0, Status.wishlist, 0, false, null),
    ('Grand Theft Auto VI', 'Rockstar Games', ['Shooter', 'Adventure'], ['PS5', 'XSX'], 2026, 0, Status.wishlist, 0, false, null),
    ('Animal Well', 'Shared Memory', ['Puzzle', 'Platform', 'Indie'], ['PC', 'PS5'], 2024, 6, Status.backlog, 0, false, null),
    ('Final Fantasy VII Rebirth', 'Square Enix', ['RPG'], ['PS5', 'PC'], 2024, 45, Status.backlog, 0, false, null),
  ];

  var idx = 0;
  for (final d in data) {
    idx++;
    final rel = d.$1 == 'Grand Theft Auto VI'
        ? ts(now.year, now.month, now.day + 18)
        : d.$1 == 'The Witcher 4'
        ? null
        : ts(d.$5, 1 + r.nextInt(11), 1 + r.nextInt(27));
    final g = Game(
      id: -1000 - idx,
      name: d.$1,
      devs: [d.$2],
      genres: d.$3,
      platforms: d.$4,
      released: rel,
      ttbMain: d.$6 == 0 ? null : d.$6 * 3600,
      ttbQuick: d.$6 == 0 ? null : (d.$6 * 0.7 * 3600).round(),
      ttbFull: d.$6 == 0 ? null : (d.$6 * 1.9 * 3600).round(),
      summary: 'A demo entry used to preview Savepoint’s layout. Connect IGDB and search for the real thing to get box art, screenshots and full details.',
    );
    store.cacheGame(g);
    final e = store.setStatus(g, d.$7);
    e.rating = d.$8;
    e.liked = d.$9;
    e.platform = d.$10;
    if (d.$7 == Status.backlog) e.priority = r.nextInt(4);
    final month = 1 + (idx * 5) % now.month;
    if (d.$7.finished) {
      e.startedAt = ms(now.year - (idx % 5 == 0 ? 1 : 0), max(1, month - 1), 3);
      e.finishedAt = min(ms(now.year - (idx % 5 == 0 ? 1 : 0), month, 10 + idx), now.millisecondsSinceEpoch);
    }
    if (d.$1 == 'Disco Elysium') {
      e.review =
          'The best writing I have ever seen in a game. Every skill check is a little short story, and failing is often more fun than succeeding. Harry is a disaster and I love him.';
      e.tags = ['masterpiece', 'narrative'];
    }
    if (d.$1 == 'Elden Ring') {
      e.review = 'Malenia took me 4 days. Worth it. The moment you leave the first cave and see the Erdtree is pure magic.';
      e.spoiler = true;
      e.tags = ['soulslike', 'masterpiece'];
      e.baseMinutes = 60 * 40;
    }
    if (d.$1 == 'Celeste') e.review = 'A perfect platformer with a heart. The B-sides broke me.';
    store.saveEntry(g, e, prev: e.status);
    if (d.$7.finished) {
      store.syncMilestoneDate(g.id, d.$7 == Status.mastered ? LogKind.mastered : LogKind.finished, e.finishedAt!);
    }
    if (d.$7 == Status.playing || d.$7.finished || d.$7 == Status.shelved || d.$7 == Status.dropped) {
      final n = 3 + r.nextInt(9);
      for (var i = 0; i < n; i++) {
        final day = now.subtract(Duration(days: d.$7 == Status.playing ? r.nextInt(25) : r.nextInt(300)));
        store.addLog(
          g,
          LogKind.session,
          date: DateTime(day.year, day.month, day.day, 19 + r.nextInt(4)).millisecondsSinceEpoch,
          minutes: 30 + r.nextInt(200),
          platform: d.$10,
          note: i == 0 && d.$7 == Status.playing ? 'Finally beat the second boss.' : '',
        );
      }
    }
  }
  final all = store.entries.keys.toList();
  store.createList('Games that changed me', desc: 'The ones I think about on long walks.', ranked: true, items: [all[3], all[0], all[5], all[2], all[12]]);
  store.createList('Cozy weekend picks', items: [all[7], all[2], all[16], all[9]]);
  store.setFavs([all[3], all[0], all[5], all[2], all[12]]);
  store.setGoal(now.year, 24);
  store.setPref('name', 'Alex');
}
