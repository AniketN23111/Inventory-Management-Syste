import 'package:flutter/material.dart';

import '../CameraScreen.dart';

class ChooseCameraPage extends StatelessWidget {
  final List<List<dynamic>> userData;
  final String username;

  ChooseCameraPage(this.userData,this.username);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Choose Camera'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Welcome ${userData[0][0]}, choose a camera:',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 20),
            // Display the list of available cameras for the logged-in user
            ListView.builder(
              shrinkWrap: true,
              itemCount: userData[0].length - 2, // Exclude non-camera columns
              itemBuilder: (context, index) {
                // Skip the first two columns (username, password)
                if (index < 2) {
                  return SizedBox.shrink();
                }
                return ListTile(
                  title: Text(userData[0][index + 1]), // Add 1 to skip the first column (username)
                  // Add onTap callback to handle camera selection
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CameraScreen(deviceName: userData[0][index + 1],username: username,)),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
