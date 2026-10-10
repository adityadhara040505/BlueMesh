import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import '../../core/logger.dart';
import 'migrations.dart';

void _linuxFfiInit() {
  if (Platform.isLinux) {
    open.overrideFor(OperatingSystem.linux, () {
      for (final name in [
        'libsqlite3.so',
        'libsqlite3.so.0',
        '/lib/x86_64-linux-gnu/libsqlite3.so.0',
        '/usr/lib/x86_64-linux-gnu/libsqlite3.so.0',
        '/usr/lib/libsqlite3.so.0',
      ]) {
        try {
          return DynamicLibrary.open(name);
        } catch (_) {}
      }
      return DynamicLibrary.process();
    });
  }
}

/// SQLite Database manager providing persistent storage and FTS5 search for chat messages.
class AppDatabase {
  AppDatabase._();

  static Database? _database;
  static const String _dbName = 'bluemesh_chat.db';
  static const int _dbVersion = 1;

  /// Retrieve active database handle or initialize it if uninitialized.
  static Future<Database> get instance async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    // If running on desktop platforms, initialize sqflite_common_ffi factory
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      _linuxFfiInit();
      databaseFactory = createDatabaseFactoryFfi(
        ffiInit: _linuxFfiInit,
        noIsolate: Platform.isLinux,
      );
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    AppLogger.i('Opening SQLite database at: $path');

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await DatabaseMigrations.onUpgrade(db, 0, version);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await DatabaseMigrations.onUpgrade(db, oldVersion, newVersion);
      },
    );
  }

  /// Close and purge database (e.g., reset application).
  static Future<void> closeAndClear() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    await deleteDatabase(path);
    AppLogger.i('SQLite database deleted.');
  }
}
