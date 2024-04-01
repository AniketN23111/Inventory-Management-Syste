import 'package:flutter/material.dart';
import 'package:image_store/CameraScreen.dart';

class ChooseCameraPage extends StatelessWidget {
  final List<List<dynamic>> userData;
  final String username;
  final String selectedDevice;
  final String brandName;

  const ChooseCameraPage({super.key,
    required this.userData,
    required this.username,
    required this.selectedDevice,
    required this.brandName,
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

    // Function to get organization name from the selected device
    String getOrganizationNameFromSelectedDevice() {
      String organizationName = '';
      if (deviceIndex != -1 && userData[deviceIndex].length > 12) {
        organizationName = userData[deviceIndex][2].toString();
      }
      return organizationName;
    }

    String inventoryType = getInventoryTypeFromSelectedDevice();
    String organizationName = getOrganizationNameFromSelectedDevice();

    // Concatenate device name, organization name, and inventory type for the app bar title and text widget
    String appBarTitle = '$selectedDevice - $organizationName - $brandName - $inventoryType';
    String textWidgetText = 'Cameras for $selectedDevice - $inventoryType:';

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Text(
            'Organization Name: $organizationName',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            'Brand Name: $brandName',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Center(
            child: Text(
              textWidgetText,
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(height: 20),
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
                        brandName: brandName,
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
    );
  }
}
