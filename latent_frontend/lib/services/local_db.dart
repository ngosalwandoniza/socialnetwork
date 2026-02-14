import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  static Database? _database;

  factory LocalDatabase() => _instance;

  LocalDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'latent_cache.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE posts (
            id INTEGER PRIMARY KEY,
            data TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE conversations (
            partner_id INTEGER PRIMARY KEY,
            data TEXT
          )
        ''');
      },
    );
  }

  // Posts
  Future<void> savePosts(List<dynamic> posts) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('posts');
      for (var post in posts) {
        await txn.insert('posts', {
          'id': post['id'],
          'data': jsonEncode(post),
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> getPosts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('posts', orderBy: 'id DESC');
    return maps.map((m) => jsonDecode(m['data']) as Map<String, dynamic>).toList();
  }

  // Conversations
  Future<void> saveConversations(List<dynamic> conversations) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('conversations');
      for (var conv in conversations) {
        await txn.insert('conversations', {
          'partner_id': conv['partner_id'],
          'data': jsonEncode(conv),
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> getConversations() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('conversations');
    return maps.map((m) => jsonDecode(m['data']) as Map<String, dynamic>).toList();
  }
}
