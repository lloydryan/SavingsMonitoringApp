import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'screens/admin_screen.dart';
import 'screens/user_screen.dart';
import 'screens/login_screen.dart';
import 'services/mongo_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  await dotenv.load();

  WidgetsFlutterBinding.ensureInitialized();
  await MongoService().connect();

  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? email = prefs.getString('email');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider(email ?? "")),
      ],
      child: MyApp(email: email),
    ),
  );
}

class MyApp extends StatelessWidget {
  final String? email;
  const MyApp({Key? key, this.email}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: email == null || email!.isEmpty
          ? LoginScreen() // Show login if no saved email
          : userProvider.role == 'admin'
              ? const AdminScreen()
              : const UserScreen(),
    );
  }
}
