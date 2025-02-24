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
      setState(() => _isLoading = false);
    }
  }

  double _calculateTotalBalance() {
    return _users.fold(0, (sum, user) => sum + (user['balance'] ?? 0));
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (route) => false,
    );
  }

  void _showAddUserDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController emailController = TextEditingController();

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
                decoration: const InputDecoration(labelText: "Name"),
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: "Email"),
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
                      .addUser(name, email, hashedPassword, 'user');

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
                  await MongoService().cashOut(email, amount);
                }
                Navigator.of(ctx).pop();
                _loadUsers();
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

  Future<bool?> _confirmDeleteUser(
      BuildContext context, Map<String, dynamic> user) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalBalance = _calculateTotalBalance();

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
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        spreadRadius: 2,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Total Balance",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "\$${totalBalance.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddUserDialog,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 24),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadUsers,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: _users.length,
                      itemBuilder: (ctx, index) {
                        var user = _users[index];

                        return Dismissible(
                          key: Key(user['_id'].toString()), // Unique identifier
                          direction: DismissDirection
                              .endToStart, // Swipe left to delete
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            color: Colors.red,
                            child:
                                const Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: (direction) async {
                            return await _confirmDeleteUser(context, user);
                          },
                          onDismissed: (direction) async {
                            await MongoService()
                                .deleteUser(user['_id']); // Delete from DB
                            setState(() {
                              _users.removeAt(index); // Remove from UI
                            });
                          },
                          child: Card(
                            margin: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade600,
                                child: Text(
                                  user['name'][0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(user['name'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                "Email: ${user['email']}\nBalance: \$${user['balance']}",
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                              isThreeLine: true,
                              trailing: Wrap(
                                spacing: 8,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.add,
                                        color: Colors.green),
                                    onPressed: () => _showAmountDialog(
                                        email: user['email'], isAdd: true),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.remove,
                                        color: Colors.red),
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
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
