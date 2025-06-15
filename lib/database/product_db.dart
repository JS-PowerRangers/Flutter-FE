import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/product.dart';

class ProductDB {
  ProductDB._();
  static final ProductDB instance = ProductDB._();
  static Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await _initDB('products.db');
    return _db!;
  }

  Future<Database> _initDB(String filename) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filename);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL
      )
    ''');
  }

  // -------------------------- CRUD --------------------------
  Future<void> insertProduct(Product p) async {
    final db = await _database;
    await db.insert(
      'products',
      p.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Product>> fetchAll() async {
    final db = await _database;
    final maps = await db.query('products');
    return maps.map((e) => Product.fromMap(e)).toList();
  }

  Future<void> deleteProduct(String name) async {
    final db = await _database;
    await db.delete('products', where: 'name = ?', whereArgs: [name]);
  }

  Future<void> updateQuantity(String name, int qty) async {
    final db = await _database;
    await db.update('products', {'quantity': qty},
        where: 'name = ?', whereArgs: [name]);
  }

  Future<void> clear() async {
    final db = await _database;
    await db.delete('products');
  }
}
