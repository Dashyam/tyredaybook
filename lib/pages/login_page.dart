import 'package:flutter/material.dart';
import 'package:tyre_daybook/pages/auth_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints){
          if (constraints.maxWidth>1000){
            return DesktopLoginView();
          }
          else{
            return MobileLoginView();
          }
        },
      ),
    );
  }
}

class DesktopLoginView extends StatelessWidget {
  const DesktopLoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 128),
        child: Row(
          children: [
            Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_shipping, size: 100, color: Colors.blueAccent),
                    SizedBox(height: 24),
                    Text('Track your Tyre Inventory'),
                  ],
                )
            ),
            Expanded(
                child:AuthPage()
            )
          ],
        ),
    );
  }
}

class MobileLoginView extends StatelessWidget {
  const MobileLoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: AuthPage(),
    );
  }
}

