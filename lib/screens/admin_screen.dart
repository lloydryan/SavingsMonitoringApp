import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/mongo_service.dart';
import '../screens/login_screen.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      var users = await MongoService().getAllUsers();
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading users: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear saved login details
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (route) => false, // Removes all previous routes (prevents going back)
    );
  }

  void _showAmountDialog({required String email, required bool isAdd}) {
    final TextEditingController amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAdd ? 'Add Money' : 'Deduct Money'),
        content: TextField(
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: "Enter amount"),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              double amount = double.tryParse(amountController.text) ?? 0;
              if (amount > 0) {
                if (isAdd) {
                  await MongoService().addMoney(email, amount);
                } else {
                  try {
                    await MongoService().cashOut(email, amount);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
                Navigator.of(ctx).pop();
                _loadUsers(); // Refresh the list after update
              }
            },
            child: const Text('Submit'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          )
        ],
      ),
    );
  }

  void _showTransactions(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Transactions for ${user['name']}'),
        content: SizedBox(
          width: double.maxFinite,
          child: user['transactions'] == null || user['transactions'].isEmpty
              ? const Text('No transactions yet.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: user['transactions'].length,
                  itemBuilder: (ctx, index) {
                    var txn = user['transactions'][index];
                    return ListTile(
                      title: Text(
                          "${txn['type'].toUpperCase()} - \$${txn['amount']}"),
                      subtitle: Text(txn['timestamp']),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close')),
        ],
      ),
    );
  }

  void _showAddUserDialog(BuildContext context) {
    TextEditingController nameController = TextEditingController();
    TextEditingController emailController = TextEditingController();
    String selectedRole = 'user'; // Default role, but not shown in UI

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add New User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: "Enter name"),
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(hintText: "Enter email"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                String name = nameController.text.trim();
                String email = emailController.text.trim();
                if (name.isNotEmpty && email.isNotEmpty) {
                  String password = '123456';
                  String hashedPassword =
                      sha256.convert(utf8.encode(password)).toString();

                  await MongoService()
                      .addUser(name, email, hashedPassword, selectedRole);

                  Navigator.of(ctx).pop();
                  _loadUsers();
                }
              },
              child: const Text('Add'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUsers,
              child: ListView.builder(
                itemCount: _users.length,
                itemBuilder: (ctx, index) {
                  var user = _users[index];
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: ListTile(
                      title: Text(user['name'] ?? ''),
                      subtitle: Text(
                          "Email: ${user['email']}\nBalance: \$${user['balance']}"),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.green),
                            onPressed: () => _showAmountDialog(
                                email: user['email'], isAdd: true),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove, color: Colors.red),
                            onPressed: () => _showAmountDialog(
                                email: user['email'], isAdd: false),
                          ),
                          IconButton(
                            icon: const Icon(Icons.receipt_long),
                            onPressed: () => _showTransactions(user),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            _showAddUserDialog(context), // Call the function to show dialog
        child: const Icon(Icons.person_add),
        tooltip: 'Add New User',
      ),
    );
  }
}
