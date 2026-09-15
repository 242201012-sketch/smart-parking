import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/parking_location.dart';
import '../models/parking_reservation.dart';

class OfflineAction {
  const OfflineAction({
    required this.id,
    required this.action,
    required this.payload,
    required this.createdAt,
  });

  final int id;
  final String action;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
}

class OfflineStore {
  Database? _database;

  Future<void> initialize() async {
    if (_database != null) return;
    final databasePath = await getDatabasesPath();
    _database = await openDatabase(
      path.join(databasePath, 'smartparking_offline.db'),
      version: 1,
      onConfigure: (database) => database.execute('PRAGMA foreign_keys = ON'),
      onCreate: (database, _) async {
        await database.execute('''
          CREATE TABLE parking_cache (
            id TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE reservation_cache (
            user_key TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_key TEXT NOT NULL,
            action TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        await database.execute(
          'CREATE INDEX IX_sync_queue_user ON sync_queue(user_key, id)',
        );
      },
    );
  }

  Database get _db {
    final database = _database;
    if (database == null) {
      throw StateError('OfflineStore.initialize çağrılmalıdır.');
    }
    return database;
  }

  Future<void> cacheParking(List<ParkingLocation> locations) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.transaction((transaction) async {
      await transaction.delete('parking_cache');
      final batch = transaction.batch();
      for (final location in locations) {
        batch.insert(
          'parking_cache',
          {
            'id': location.id,
            'payload': jsonEncode(location.toJson()),
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<ParkingLocation>> loadParking() async {
    final rows = await _db.query('parking_cache', orderBy: 'id');
    return rows
        .map((row) => jsonDecode(row['payload']! as String))
        .whereType<Map<String, dynamic>>()
        .map(ParkingLocation.fromJson)
        .toList();
  }

  Future<void> cacheReservation(
    String userKey,
    ParkingReservation reservation,
  ) async {
    await _db.insert(
      'reservation_cache',
      {
        'user_key': _normalizeUserKey(userKey),
        'payload': jsonEncode(reservation.toJson()),
        'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ParkingReservation?> loadReservation(String userKey) async {
    final rows = await _db.query(
      'reservation_cache',
      where: 'user_key = ?',
      whereArgs: [_normalizeUserKey(userKey)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final payload = jsonDecode(rows.first['payload']! as String);
    return payload is Map<String, dynamic>
        ? ParkingReservation.fromJson(payload)
        : null;
  }

  Future<void> clearReservation(String userKey) => _db.delete(
        'reservation_cache',
        where: 'user_key = ?',
        whereArgs: [_normalizeUserKey(userKey)],
      );

  Future<int> enqueue(
    String userKey,
    String action,
    Map<String, dynamic> payload,
  ) {
    return _db.insert('sync_queue', {
      'user_key': _normalizeUserKey(userKey),
      'action': action,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toUtc().millisecondsSinceEpoch,
    });
  }

  Future<List<OfflineAction>> pendingActions(String userKey) async {
    final rows = await _db.query(
      'sync_queue',
      where: 'user_key = ?',
      whereArgs: [_normalizeUserKey(userKey)],
      orderBy: 'id',
    );
    return rows.map((row) {
      final payload = jsonDecode(row['payload']! as String);
      return OfflineAction(
        id: row['id']! as int,
        action: row['action']! as String,
        payload: payload is Map<String, dynamic> ? payload : const {},
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row['created_at']! as int,
          isUtc: true,
        ),
      );
    }).toList();
  }

  Future<int> pendingCount(String userKey) => _count(
        'SELECT COUNT(*) AS count FROM sync_queue WHERE user_key = ?',
        [_normalizeUserKey(userKey)],
      );

  Future<void> removeAction(int id) => _db.delete(
        'sync_queue',
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> removePendingCreate(String userKey, String localId) async {
    final actions = await pendingActions(userKey);
    for (final action in actions) {
      if (action.action == 'create_reservation' &&
          action.payload['localId']?.toString() == localId) {
        await removeAction(action.id);
      }
    }
  }

  Future<void> clearUserData(String userKey) async {
    final key = _normalizeUserKey(userKey);
    await _db.transaction((transaction) async {
      await transaction.delete(
        'reservation_cache',
        where: 'user_key = ?',
        whereArgs: [key],
      );
      await transaction.delete(
        'sync_queue',
        where: 'user_key = ?',
        whereArgs: [key],
      );
    });
  }

  Future<int> _count(String sql, List<Object?> arguments) async {
    final rows = await _db.rawQuery(sql, arguments);
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  String _normalizeUserKey(String value) => value.trim().toLowerCase();

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
