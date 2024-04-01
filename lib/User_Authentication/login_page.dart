import 'package:flutter/material.dart';
import 'package:image_store/User_Authentication/RegistrationForm.dart';
import 'package:postgres/postgres.dart';
import 'DevicePage.dart';
//import 'choosecamerapage.dart'; // Import the page to navigate to after login

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: const LoginForm(), // Display the login form
    );
  }
}

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  _LoginFormState createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Variable to hold user data
  List<List<dynamic>>? userData;

  // Variable to track login state
  bool _isLoggingIn = false;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoggingIn = true; // Set login state to true when login process starts
      });
      try {
        // Fetch user credentials from PostgreSQL
        final isValid = await fetchUserCredentials(
          _usernameController.text.toString(),
          _passwordController.text.toString(),
        );

        if (isValid) {
          // Fetch user data after successful login
          userData = await fetchUserData(_usernameController.text.toString());

          // Navigate to the page where the user can choose a Device
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => DevicePage(userData!)),
          );
        } else {
          // Show error message for invalid credentials
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid username or password')),
          );
        }
      } catch (e) {
        // Handle errors
        print('Login failed: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login failed. Please try again.')),
        );
      } finally {
        setState(() {
          _isLoggingIn = false; // Reset login state to false when login process completes
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your username';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, // Expand the SizedBox to full width
              child: ElevatedButton(
                onPressed: _isLoggingIn ? null : _login,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isLoggingIn) const SizedBox(
                      width: 24, // Set the width of the progress indicator
                      height: 24, // Set the height of the progress indicator
                      child: CircularProgressIndicator(
                        strokeWidth: 2, // Adjust the stroke width of the progress indicator
                      ),
                    ), // Show progress indicator when login is in progress
                    const Text('Login'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, // Expand the SizedBox to full width
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => RegistrationForm()));
                },
                child: const Text('Register'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Method to fetch user credentials from PostgreSQL
  Future<bool> fetchUserCredentials(String username, String password) async {
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
        'SELECT * FROM ai.device_user WHERE username = \$1 AND password = \$2',
        parameters: [username, password],
      );

      await connection.close();
      return result.isNotEmpty;
    } catch (e) {
      print('Error fetching user credentials: $e');
      return false;
    }
  }

  // Method to fetch user data from PostgreSQL
  Future<List<List<dynamic>>> fetchUserData(String username) async {
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
        'SELECT * FROM ai.device_user WHERE username = \$1',
        parameters: [username],
      );

      await connection.close();
      return result;
    } catch (e) {
      print('Error fetching user data: $e');
      return [];
    }
  }
}
