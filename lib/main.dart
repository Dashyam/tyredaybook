import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pages/auth_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const TyreDaybookApp());
}

class TyreDaybookApp extends StatelessWidget {
  const TyreDaybookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tyre Daybook',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AuthPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
