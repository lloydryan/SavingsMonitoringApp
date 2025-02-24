import 'package:flutter/material.dart';
import '../services/mongo_service.dart';

class UserProvider with ChangeNotifier {
  final MongoService _mongoService = MongoService();
  Map<String, dynamic>? user;
  String? role;

  UserProvider(String email) {
    _mongoService.userStream.listen((updatedUser) {
      if (user != null && updatedUser['email'] == user!['email']) {
        user = updatedUser;
        notifyListeners();
      }
    });
    fetchUser(email);
  }

  Future<void> fetchUser(String email) async {
    user = await _mongoService.getUser(email);
    print("Fetched user: $user");
    role = user?['role'];
    notifyListeners();
  }

  Future<void> addMoney(double amount) async {
    if (user != null) {
      await _mongoService.addMoney(user!['email'], amount);
    }
  }

  Future<void> cashOut(double amount) async {
    if (user != null) {
      await _mongoService.cashOut(user!['email'], amount);
    }
  }
}
