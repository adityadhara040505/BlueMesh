import 'package:sqflite/sqflite.dart';
import '../../core/logger.dart';

/// Database schema migration runner for SQLite.
class DatabaseMigrations {
  DatabaseMigrations._();

  /// Executes DDL updates on database creation or upgrades.
  static Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogger.i('Upgrading database schema from v$oldVersion to v$newVersion');

    for (int v = oldVersion + 1; v <= newVersion; v++) {
      switch (v) {
        case 1:
          await _createV1Schema(db);
          break;
        default:
          break;
      }
    }
  }

  /// Initial V1 Schema Creation:
  /// - `messages` table
  /// - Index on `(chat_id, timestamp DESC)`
  /// - FTS5 full-text search table & triggers
  static Future<void> _createV1Schema(Database db) async {
    // 1. Messages table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id INTEGER PRIMARY KEY,
        chat_id TEXT NOT NULL,
        sender_id INTEGER NOT NULL,
        recipient_id INTEGER NOT NULL,
        text TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        status TEXT NOT NULL,
        is_encrypted INTEGER NOT NULL DEFAULT 0,
        hop_count INTEGER NOT NULL DEFAULT 0,
        synced INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 2. Index for quick conversation timeline queries
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_messages_chat_time 
      ON messages(chat_id, timestamp DESC)
    ''');

    // 3. FTS5 Virtual Table for offline full-text search across all conversations
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(
          text,
          content='messages',
          content_rowid='id'
        )
      ''');

      // Keep FTS5 in sync with main table
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS messages_ai AFTER INSERT ON messages BEGIN
          INSERT INTO messages_fts(rowid, text) VALUES (new.id, new.text);
        END;
      ''');

      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS messages_ad AFTER DELETE ON messages BEGIN
          INSERT INTO messages_fts(messages_fts, rowid, text) VALUES('delete', old.id, old.text);
        END;
      ''');

      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS messages_au AFTER UPDATE ON messages BEGIN
          INSERT INTO messages_fts(messages_fts, rowid, text) VALUES('delete', old.id, old.text);
          INSERT INTO messages_fts(rowid, text) VALUES (new.id, new.text);
        END;
      ''');
    } catch (e) {
      // In rare environments where SQLite FTS5 extension is omitted, fallback gracefully
      AppLogger.w('FTS5 virtual table initialization skipped or not supported: $e');
    }
  }
}
