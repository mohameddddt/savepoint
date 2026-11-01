import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Thin SQLite persistence. Everything is loaded into memory at startup and
/// written through on change, so reads are instant and writes are cheap.
class Db {
  late Database _db;

  Future<void> open() async {
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'savepoint.db'),
      version: 1,
      onCreate: (db, v) async {
        final b = db.batch();
        b.execute('CREATE TABLE games (id INTEGER PRIMARY KEY, j TEXT NOT NULL)');
        b.execute('CREATE TABLE entries (id INTEGER PRIMARY KEY, j TEXT NOT NULL)');
        b.execute('CREATE TABLE logs (id TEXT PRIMARY KEY, g INTEGER, d INTEGER, j TEXT NOT NULL)');
        b.execute('CREATE TABLE lists (id TEXT PRIMARY KEY, j TEXT NOT NULL)');
        b.execute('CREATE TABLE kv (k TEXT PRIMARY KEY, v TEXT NOT NULL)');
        await b.commit(noResult: true);
      },
    );
  }

  Future<List<Map<String, dynamic>>> all(String table) async {
    final rows = await _db.query(table, columns: ['j']);
    return rows.map((r) => jsonDecode(r['j'] as String) as Map<String, dynamic>).toList();
  }

  Future<Map<String, String>> kv() async {
    final rows = await _db.query('kv');
    return {for (final r in rows) r['k'] as String: r['v'] as String};
  }

  // Writes are queued and committed together in one batch shortly after,
  // so bursts of edits cost a single transaction.
  final _ops = <void Function(Batch)>[];
  Timer? _flushTimer;

  void _enqueue(void Function(Batch) op) {
    _ops.add(op);
    _flushTimer ??= Timer(const Duration(milliseconds: 200), flush);
  }

  Future<void> flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_ops.isEmpty) return;
    final b = _db.batch();
    for (final op in _ops) {
      op(b);
    }
    _ops.clear();
    await b.commit(noResult: true);
  }

  void put(String table, Object id, Map<String, dynamic> j, {int? g, int? d}) {
    final row = {'id': id, 'j': jsonEncode(j), 'g': ?g, 'd': ?d};
    _enqueue((b) => b.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace));
  }

  void del(String table, Object id) => _enqueue((b) => b.delete(table, where: 'id = ?', whereArgs: [id]));

  void setKv(String k, String? v) => _enqueue((b) => v == null
      ? b.delete('kv', where: 'k = ?', whereArgs: [k])
      : b.insert('kv', {'k': k, 'v': v}, conflictAlgorithm: ConflictAlgorithm.replace));

  /// Replace everything (used by backup import).
  Future<void> replaceAll({
    required List<Map<String, dynamic>> games,
    required List<Map<String, dynamic>> entries,
    required List<Map<String, dynamic>> logs,
    required List<Map<String, dynamic>> lists,
    required Map<String, String> kv,
  }) async {
    await flush();
    await _db.transaction((t) async {
      final b = t.batch();
      for (final tb in ['games', 'entries', 'logs', 'lists']) {
        b.delete(tb);
      }
      for (final k in kv.keys) {
        b.delete('kv', where: 'k = ?', whereArgs: [k]);
      }
      for (final g in games) {
        b.insert('games', {'id': g['id'], 'j': jsonEncode(g)});
      }
      for (final e in entries) {
        b.insert('entries', {'id': e['g'], 'j': jsonEncode(e)});
      }
      for (final l in logs) {
        b.insert('logs', {'id': l['id'], 'g': l['g'], 'd': l['d'], 'j': jsonEncode(l)});
      }
      for (final l in lists) {
        b.insert('lists', {'id': l['id'], 'j': jsonEncode(l)});
      }
      kv.forEach((k, v) => b.insert('kv', {'k': k, 'v': v}, conflictAlgorithm: ConflictAlgorithm.replace));
      await b.commit(noResult: true);
    });
  }
}
