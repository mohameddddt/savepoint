import 'package:flutter_test/flutter_test.dart';
import 'package:savepoint/xbox.dart';

void main() {
  test('parses a titlehub entry', () {
    final t = XboxTitle.fromApi({
      'titleId': '1144039928',
      'name': 'Halo: The Master Chief Collection®',
      'type': 'Game',
      'devices': ['XboxOne', 'XboxSeries', 'PC'],
      'displayImage': 'https://example.com/a.png',
      'achievement': {'currentAchievements': 700, 'totalAchievements': 700, 'currentGamerscore': 7000, 'totalGamerscore': 7000, 'progressPercentage': 100},
      'titleHistory': {'lastTimePlayed': '2026-10-20T18:00:00.000Z'},
    });
    expect(t.name, 'Halo: The Master Chief Collection');
    expect(t.mastered, isTrue);
    expect(t.lastPlayed, DateTime.utc(2026, 10, 20, 18).millisecondsSinceEpoch);
    final back = XboxTitle.fromJson(t.toJson());
    expect(back.gs, 7000);
    expect(back.devices, ['XboxOne', 'XboxSeries', 'PC']);
  });

  test('strips platform and edition noise from search names', () {
    String s(String n) => XboxTitle(id: '1', name: n).searchName;
    expect(s('Forza Horizon 4 Standard Edition'), 'Forza Horizon 4');
    expect(s('Sea of Thieves (Windows)'), 'Sea of Thieves');
    expect(s('Gears 5 - Xbox One Edition'), 'Gears 5');
    expect(s('Minecraft for Windows 10'), 'Minecraft');
    expect(s('Ori and the Blind Forest: Definitive Edition'), 'Ori and the Blind Forest');
    expect(s('Hades'), 'Hades');
  });
}
