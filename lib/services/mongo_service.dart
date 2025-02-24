import 'dart:async';
import 'dart:convert';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MongoService {
  static final MongoService _instance = MongoService._internal();
  factory MongoService() => _instance;
  MongoService._internal();

  late Db _db;
  late DbCollection _users;
  late StreamController<Map<String, dynamic>> _streamController;

  Stream<Map<String, dynamic>> get userStream => _streamController.stream;

  Future<void> connect() async {
    _db = await Db.create(dotenv.env['MONGO_URI']!);
    await _db.open();
    _users = _db.collection('users');
    _streamController = StreamController.broadcast();
    _watchChanges();
  }

  Future<Map<String, dynamic>?> getUser(String email) async {
    return await _users.findOne(where.eq('email', email));
  }

  Future<void> registerUser(
      String name, String email, String password, String role) async {
    String hashedPassword = sha256.convert(utf8.encode(password)).toString();
    await _users.insertOne({
      "name": name,
      "email": email,
      "password": hashedPassword,
      "role": role,
      "balance": 0,
      "transactions": []
    });
  }

  Future<void> addUser(
      String name, String email, String hashedPassword, String role) async {
    await _users.insertOne({
      "name": name,
      "email": email,
      "password": hashedPassword,
      "role": role,
      "balance": 0,
      "transactions": []
    }); // Implement the logic to add a user to the database
  }

  Future<void> resetPassword(String email, String newPassword) async {
    final collection = _db.collection('users');

    // Hash the new password using SHA-256 (same as registration)
    String hashedPassword = sha256.convert(utf8.encode(newPassword)).toString();

    await collection.updateOne(
      {'email': email},
      {
        '\$set': {'password': hashedPassword} // Updating password in DB
      },
    );
  }

  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    String hashedPassword = sha256.convert(utf8.encode(password)).toString();
    var user = await _users
        .findOne(where.eq('email', email).eq('password', hashedPassword));
    if (user != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('email', user['email']);
      await prefs.setString('role', user['role']);
      return user;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    return await _users.find(where.eq('role', 'user')).toList();
  }

  Future<void> addMoney(String email, double amount) async {
    DateTime now = DateTime.now()
        .add(const Duration(hours: 8)); // Convert to Philippine Time
    await _users.updateOne(
      where.eq('email', email),
      modify.inc('balance', amount).push('transactions', {
        "type": "deposit",
        "amount": amount,
        "timestamp": now.toIso8601String(), // Store as UTC+8 manually
      }),
    );
  }

  Future<void> cashOut(String email, double amount) async {
    var user = await _users.findOne(where.eq('email', email));
    if (user != null && user['balance'] >= amount) {
      DateTime now = DateTime.now()
          .add(const Duration(hours: 8)); // Convert to Philippine Time
      await _users.updateOne(
        where.eq('email', email),
        modify.inc('balance', -amount).push('transactions', {
          "type": "withdraw",
          "amount": amount,
          "timestamp": now.toIso8601String(), // Store as UTC+8 manually
        }),
      );
    } else {
      throw Exception("Insufficient balance");
    }
  }

  void _watchChanges() {
    var pipeline = [
      {
        '\$match': {
          'operationType': {
            '\$in': ['insert', 'update', 'replace']
          }
        }
      }
    ];

    _users.watch(pipeline).listen((change) async {
      if (change.fullDocument != null) {
        var updatedUser = await getUser(change.fullDocument!['email']);
        if (updatedUser != null) {
          _streamController.add(updatedUser);
        }
      }
    }, onError: (error) {
      print("Error watching changes: $error");
    });
  }
}
