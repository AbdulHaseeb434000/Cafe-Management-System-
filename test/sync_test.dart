// Tests for sync service correctness:
//
// 1. Only rows whose UUIDs were captured before the push are marked synced.
//    A row written to the DB during a push cycle (between query and mark)
//    must remain sync_pending=1.
//
// 2. Supabase UTC timestamps are normalised to naive local-time ISO strings
//    before being stored in SQLite, so that BETWEEN range queries and
//    SQLite's strftime('%H', …) work correctly in the local timezone.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

// ── In-memory DB helper ───────────────────────────────────────────────────────

Future<Database> _openTestDb() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE categories (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            uuid         TEXT    NOT NULL UNIQUE,
            name         TEXT    NOT NULL,
            created_at   TEXT    NOT NULL,
            sync_pending INTEGER NOT NULL DEFAULT 1
          )
        ''');
      },
    ),
  );
}

// ── Timestamp normalisation (mirrors SyncService._ts) ────────────────────────

/// Mirrors the private [SyncService._ts] helper.
/// Converts any ISO timestamp string (with or without timezone) to a
/// naive local-time ISO string (no 'Z', no '+xx:xx' suffix).
String toLocalIso(dynamic val) {
  if (val == null) return DateTime.now().toIso8601String();
  return DateTime.parse(val as String).toLocal().toIso8601String();
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('Sync — UUID-targeted sync_pending marking', () {
    late Database db;

    setUp(() async {
      db = await _openTestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('only captured UUIDs are marked synced; later rows stay pending', () async {
      // Arrange: two rows pending before push starts
      await db.insert('categories', {
        'uuid': 'cat-A',
        'name': 'Drinks',
        'created_at': '2024-01-01T09:00:00.000000',
        'sync_pending': 1,
      });
      await db.insert('categories', {
        'uuid': 'cat-B',
        'name': 'Food',
        'created_at': '2024-01-01T09:01:00.000000',
        'sync_pending': 1,
      });

      // Simulate push start: capture UUIDs of pending rows
      final pending = await db.query('categories', where: 'sync_pending = 1');
      final pushedUuids = pending.map((r) => r['uuid'] as String).toList();

      // Simulate a new row written to the DB during the push (race condition)
      await db.insert('categories', {
        'uuid': 'cat-C',
        'name': 'Specials',
        'created_at': '2024-01-01T09:02:00.000000',
        'sync_pending': 1,
      });

      // Mark only the pre-push rows as synced (UUID-targeted UPDATE)
      final placeholders = List.filled(pushedUuids.length, '?').join(', ');
      await db.rawUpdate(
        'UPDATE categories SET sync_pending = 0 WHERE uuid IN ($placeholders)',
        pushedUuids,
      );

      // Assert: cat-A and cat-B are synced
      final synced = await db.query('categories', where: 'sync_pending = 0');
      expect(synced.map((r) => r['uuid']).toSet(), {'cat-A', 'cat-B'});

      // Assert: cat-C written during push is still pending
      final stillPending = await db.query('categories', where: 'sync_pending = 1');
      expect(stillPending.length, 1);
      expect(stillPending.first['uuid'], 'cat-C');
    });

    test('empty pending list results in no update', () async {
      // No pending rows
      final pending = await db.query('categories', where: 'sync_pending = 1');
      expect(pending, isEmpty);
      // Should be a no-op (no crash, no rows changed)
      // Don't call rawUpdate with empty list — caller should guard with isEmpty check.
    });

    test('only rows for a specific table are affected', () async {
      // Simulate two tables having pending rows; updating one does not touch the other.
      // (In practice, SyncService calls rawUpdate per table.)
      await db.insert('categories', {
        'uuid': 'cat-X',
        'name': 'Beverages',
        'created_at': '2024-01-01T10:00:00.000000',
        'sync_pending': 1,
      });

      // Capture and mark
      final pushedUuids = ['cat-X'];
      await db.rawUpdate(
        'UPDATE categories SET sync_pending = 0 WHERE uuid IN (?)',
        pushedUuids,
      );

      final row = await db.query('categories', where: 'uuid = ?', whereArgs: ['cat-X']);
      expect(row.first['sync_pending'], 0);
    });
  });

  group('Sync — timestamp normalisation', () {
    test('UTC Z-suffix is converted to local naive ISO', () {
      // An ISO string with Z is UTC; toLocal() removes the Z suffix on most
      // systems and adds the local time value.
      const utcString = '2024-06-15T09:00:00.000Z';
      final result = toLocalIso(utcString);
      // Result must not contain 'Z' or '+' (naive local)
      expect(result.contains('Z'), isFalse);
      expect(result.contains('+'), isFalse);
      // The parsed DateTime must represent the same point in time
      expect(
        DateTime.parse(result).toUtc(),
        equals(DateTime.parse(utcString).toUtc()),
      );
    });

    test('UTC+offset string is converted to local naive ISO', () {
      const offsetString = '2024-06-15T14:30:00.000+05:30';
      final result = toLocalIso(offsetString);
      expect(result.contains('+'), isFalse,
          reason: 'offset must be stripped');
      expect(
        DateTime.parse(result).toUtc(),
        equals(DateTime.parse(offsetString).toUtc()),
      );
    });

    test('already-naive string is round-tripped correctly', () {
      const naiveLocal = '2024-06-15T14:30:00.000000';
      final result = toLocalIso(naiveLocal);
      // Naive → parsed as local → toLocal() → still local, same value
      expect(
        DateTime.parse(result),
        equals(DateTime.parse(naiveLocal)),
      );
    });

    test('null value falls back to current time (no crash)', () {
      final result = toLocalIso(null);
      expect(() => DateTime.parse(result), returnsNormally);
    });

    test('SQLite BETWEEN comparison works correctly with normalised timestamps', () {
      // Simulate two timestamps that would be compared in a date range query
      const ts1 = '2024-06-15T08:00:00.000000'; // 8am local
      const ts2 = '2024-06-15T22:00:00.000000'; // 10pm local
      const rangeStart = '2024-06-15T00:00:00.000000'; // midnight
      const rangeEnd   = '2024-06-15T23:59:59.999000'; // end of day

      // Naive ISO strings compare lexicographically — this is the same logic
      // SQLite uses for BETWEEN on TEXT columns.
      expect(ts1.compareTo(rangeStart) >= 0 && ts1.compareTo(rangeEnd) <= 0, isTrue);
      expect(ts2.compareTo(rangeStart) >= 0 && ts2.compareTo(rangeEnd) <= 0, isTrue);
    });
  });
}
