import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/user_provider.dart';
import '../screens/login_screen.dart';
import '../services/mongo_service.dart';
import 'package:intl/intl.dart';

class UserScreen extends StatelessWidget {
  const UserScreen({Key? key}) : super(key: key);

  Future<void> _logout(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (route) => false,
    );
  }

  void _resetPassword(BuildContext context, String email) {
    TextEditingController newPasswordController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Colors.blue[50],
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 40, color: Colors.blue),
            const SizedBox(height: 10),
            const Text('Reset Password',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue)),
            const SizedBox(height: 10),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.password, color: Colors.blue),
                labelText: 'New Password',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                String newPassword = newPasswordController.text.trim();
                if (newPassword.isEmpty || newPassword.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Password must be at least 6 characters long!')),
                  );
                  return;
                }
                await MongoService().resetPassword(email, newPassword);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Password updated successfully!')),
                );
              },
              icon: const Icon(Icons.check),
              label: const Text('Update Password'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    var user = userProvider.user;

    return Scaffold(
      appBar: AppBar(
        elevation: 6,
        shadowColor: Colors.black.withOpacity(0.5),
        title: const Text(' Dashboard',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 83, 83, 83))),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    color: const Color.fromARGB(255, 225, 240, 253),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text("Balance: \Php ${user['balance']}",
                          style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onLongPress: () => _resetPassword(context, user['email']),
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text("Hello, ${user['name']}",
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue)),
                              const Text("Long press to reset password",
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.blueGrey)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("TRANSACTIONS:",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 0, 0, 0))),
                  const SizedBox(height: 10),
                  Expanded(
                    child: user['transactions'] == null ||
                            user['transactions'].isEmpty
                        ? const Center(
                            child: Text('No transactions yet',
                                style: TextStyle(color: Colors.blueGrey)))
                        : ListView.builder(
                            itemCount: user['transactions'].length,
                            itemBuilder: (ctx, index) {
                              // Sort transactions from latest to oldest
                              var transactions =
                                  List.from(user['transactions']);
                              transactions.sort((a, b) =>
                                  DateTime.parse(b['timestamp']).compareTo(
                                      DateTime.parse(a['timestamp'])));

                              var txn = transactions[index];
                              bool isDeposit =
                                  txn['type'].toString().toLowerCase() ==
                                      'deposit';

                              // Format the timestamp
                              DateTime dateTime =
                                  DateTime.parse(txn['timestamp']);
                              String formattedDate =
                                  DateFormat('MMMM d, y | h:mma')
                                      .format(dateTime);

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 5),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                color: isDeposit
                                    ? Colors.green[100]
                                    : Colors.red[100],
                                child: ListTile(
                                  title: Text(
                                      "${txn['type'].toUpperCase()} - \Php${txn['amount']}",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDeposit
                                              ? Colors.green[900]
                                              : Colors.red[900])),
                                  subtitle: Text(formattedDate,
                                      style: const TextStyle(
                                          color: Colors.blueGrey)),
                                  leading: Icon(
                                    isDeposit
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    color:
                                        isDeposit ? Colors.green : Colors.red,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
