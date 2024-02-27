import 'package:flutter/material.dart';
import '../CameraScreen.dart'; // Page to access the camera

class AddDevicePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Device'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Simulating adding a device action
            // In a real app, you would implement device addition logic here
            // Once a device is added, navigate to the camera screen
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CameraScreen()),
            );
          },
          child: Text('Add Mobile Device'),
        ),
      ),
    );
  }
}
