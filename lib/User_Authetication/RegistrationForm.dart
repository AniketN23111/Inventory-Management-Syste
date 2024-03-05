import 'package:flutter/material.dart';
import 'package:postgres/postgres.dart';
import 'package:image_store/User_Authetication/login_page.dart';

class RegistrationForm extends StatefulWidget {
  @override
  _RegistrationFormState createState() => _RegistrationFormState();
}

class _RegistrationFormState extends State<RegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _orgNameController = TextEditingController();
  List<TextEditingController> _cameraControllers = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Registration'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(labelText: 'Username'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your username';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _orgNameController,
                decoration: InputDecoration(labelText: 'Organization Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your organization name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              // Generate camera fields dynamically
              for (int i = 0; i < _cameraControllers.length; i++)
                TextFormField(
                  controller: _cameraControllers[i],
                  decoration: InputDecoration(
                    labelText: 'Camera ${i + 1} Name',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter camera ${i + 1} name';
                    }
                    return null;
                  },
                ),
              SizedBox(height: 20),
              if (_cameraControllers.length < 6)
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _cameraControllers.add(TextEditingController());
                    });
                  },
                  child: Text('Add Camera'),
                ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    bool isRegistered = await registerUser(
                      _usernameController.text,
                      _passwordController.text,
                      _orgNameController.text,
                      _cameraControllers.map((controller) => controller.text).toList(),
                    );
                    if (isRegistered) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => LoginPage()),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Registration failed. Please try again.')),
                      );
                    }
                  }
                },
                child: Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _orgNameController.dispose();
    for (var controller in _cameraControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<bool> registerUser(
      String username,
      String password,
      String orgName,
      List<String> cameraNames,
      ) async {
    try {
      final connection = await Connection.open(
        Endpoint(
          host: '34.71.87.187',
          port: 5432,
          database: 'airegulation_dev',
          username: 'postgres',
          password: 'India@5555',
        ),
        settings: const ConnectionSettings(sslMode: SslMode.disable),
      );

      final result = await connection.execute(
        'INSERT INTO ai.image_user (username, password, orgname, camera1, camera2, camera3, camera4, camera5, camera6) '
            'VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9)',
        parameters: [
          username,
          password,
          orgName,
          for (int i = 0; i < 6; i++)
            cameraNames.length > i ? cameraNames[i] : '',
        ],
      );
      print(result);
      await connection.close();

      return result.affectedRows == 1;
    } catch (e) {
      print('Error registering user: $e');
      return false;
    }
  }
}
