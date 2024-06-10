import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../User_Authentication/login_page.dart';

class ProfileDetails extends StatefulWidget {
  final List<List<dynamic>> userData;

  const ProfileDetails({super.key, required this.userData});

  @override
  State<ProfileDetails> createState() => _ProfileDetailsState();
}

class _ProfileDetailsState extends State<ProfileDetails> {
  final _formKey = GlobalKey<FormState>();
  final List<Map<String, dynamic>> _deviceControllers = [];

  String username = '';
  String password = '';
  String orgName = '';
  String brandName = '';

  //final List<String> _inventoryTypes = ['Inward', 'Outward', 'None'];

  @override
  void initState() {
    super.initState();
    // Initialize username, password, orgName, and brandName
    username = widget.userData[0][0];
    password = widget.userData[0][1];
    orgName = widget.userData[0][2];
    brandName = widget.userData[0][9];
  }
  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isLoggedIn', true);
    await prefs.clear(); // Clear all shared preferences

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              // Widgets to display user data
              Text('Username: $username'),
              Text('Password: $password'),
              Text('Organization Name: $orgName'),
              Text('Brand Name: $brandName'),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: (){
                _logout(context);
              }, child: const Text("Logout")),

            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var device in _deviceControllers) {
      for (var controller in device['cameraControllers']) {
        controller.dispose();
      }
    }
    super.dispose();
  }
}
