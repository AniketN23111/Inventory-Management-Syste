import 'package:flutter/material.dart';
import 'package:image_store/CameraScreen.dart';

class ChooseCameraPage extends StatelessWidget {
  final List<List<dynamic>> userData;
  final String username;
  final String selectedDevice;

  ChooseCameraPage({
    required this.userData,
    required this.username,
    required this.selectedDevice,
  });

  @override
  Widget build(BuildContext context) {
    // List to store cameras for the selected device
    List<String> cameras = [];

    // Find the index of the row for the selected device
    int deviceIndex = userData.indexWhere((row) => row.contains(selectedDevice));

    // If the device is found, extract camera names from indices 3 to 8
    if (deviceIndex != -1) {
      for (int j = 3; j < 9; j++) {
        String cameraName = userData[deviceIndex][j].toString();
        if (cameraName.isNotEmpty) {
          cameras.add(cameraName);
        }
      }
    }
    // Function to get the inventory type from the selected device
    String getInventoryTypeFromSelectedDevice() {
      String inventoryType = '';
      if (deviceIndex != -1 && userData[deviceIndex].length > 11) {
        inventoryType = userData[deviceIndex][11].toString();
      }
      return inventoryType;
    }
    // Load inventory type at the start
    String inventoryType = getInventoryTypeFromSelectedDevice();
    print(inventoryType);

    return Scaffold(
      appBar: AppBar(
        title: Text('Cameras for $selectedDevice'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Cameras for $selectedDevice:',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 20),
            ListView.builder(
              shrinkWrap: true,
              itemCount: cameras.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(cameras[index]),
                  onTap: () {
                    // Navigate to CameraScreen when a camera is tapped
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CameraScreen(
                          deviceName: cameras[index],
                          username: username,
                          selectedDevice: selectedDevice,
                          inventoryType: inventoryType, // Pass the inventory type to the CameraScreen
                          userData: userData,
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
