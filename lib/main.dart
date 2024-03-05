import 'package:flutter/material.dart';
import 'package:image_store/User_Authetication/RegistrationForm.dart';
import 'CameraScreen.dart';
import 'User_Authetication/login_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: LoginPage(),
    );
  }
}
