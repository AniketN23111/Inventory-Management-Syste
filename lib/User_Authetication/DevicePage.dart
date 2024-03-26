import 'package:flutter/material.dart';
import 'package:image_store/User_Authetication/choosecamerapage.dart';

class DevicePage extends StatelessWidget {
  final List<List<dynamic>> userData;

  DevicePage(this.userData);

  @override
  Widget build(BuildContext context) {
    String username = userData[0][0];
    String password = userData[0][1];
    List<String> devices = [];

    for (int i = 0; i < userData.length; i++) {
      if (userData[i][0] == username && userData[i][1] == password) {
        devices.add(userData[i][10]); // Assuming device names are in the 8th column (index 7)
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Devices for $username'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Devices for $username:',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 20),
            ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(devices[index]),
                  onTap: () {
                    // Navigate to ChooseCameraPage when a device is tapped
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>  ChooseCameraPage(
                        userData: userData,
                        username: username,
                        selectedDevice: devices[index], // Pass the selected device
                        ),
                      ),
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
