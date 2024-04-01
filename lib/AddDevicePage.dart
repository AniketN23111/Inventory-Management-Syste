import 'package:flutter/material.dart';
import 'package:postgres/postgres.dart';
import 'package:image_store/User_Authentication/login_page.dart';

class AddDevicePage extends StatefulWidget {
  final List<List<dynamic>> userData;

  const AddDevicePage({Key? key, required this.userData}) : super(key: key);

  @override
  _AddDevicePageState createState() => _AddDevicePageState();
}

class _AddDevicePageState extends State<AddDevicePage> {
  final _formKey = GlobalKey<FormState>();
  final List<Map<String, dynamic>> _deviceControllers = [];

  String username = '';
  String password = '';
  String orgName = '';
  String brandName = '';

  final List<String> _inventoryTypes = ['Inward', 'Outward', 'None'];

  @override
  void initState() {
    super.initState();
    // Initialize username, password, orgName, and brandName
    username = widget.userData[0][0];
    password = widget.userData[0][1];
    orgName = widget.userData[0][2];
    brandName = widget.userData[0][9];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Device'),
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
              for (int i = 0; i < _deviceControllers.length; i++)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _deviceControllers[i]['deviceName'],
                      decoration: const InputDecoration(labelText: 'Device Name'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter device name';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _deviceControllers[i]['deviceLocation'],
                      decoration: const InputDecoration(labelText: 'Device Location'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter device location';
                        }
                        return null;
                      },
                    ),
                    DropdownButtonFormField(
                      value: _deviceControllers[i]['inventoryType'],
                      items: _inventoryTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _deviceControllers[i]['inventoryType'] = value.toString();
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Inventory Type'),
                    ),
                    const SizedBox(height: 20),
                    // Generate camera fields dynamically
                    for (int j = 0; j < _deviceControllers[i]['cameraControllers'].length; j++)
                      TextFormField(
                        controller: _deviceControllers[i]['cameraControllers'][j],
                        decoration: InputDecoration(
                          labelText: 'Camera ${j + 1} Name',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter camera ${j + 1} name';
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 20),
                    if (_deviceControllers[i]['cameraControllers'].length < 6)
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _deviceControllers[i]['cameraControllers'].add(TextEditingController());
                          });
                        },
                        child: const Text('Add Camera'),
                      ),
                  ],
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _deviceControllers.add({
                      'deviceName': TextEditingController(),
                      'deviceLocation': TextEditingController(),
                      'inventoryType': 'None',
                      'cameraControllers': <TextEditingController>[],
                    });
                  });
                },
                child: const Text('Add Device'),
              ),
              const SizedBox(height: 20),
              // Button to submit data
              ElevatedButton(
                onPressed: () async {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const AlertDialog(
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 20),
                          Text('Adding device...'),
                        ],
                      ),
                    ),
                  );
                  bool isRegistered = await registerUser(_deviceControllers);
                  Navigator.pop(context); // Close the dialog
                  if (isRegistered) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Device added successfully!')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to add device. Please try again.')),
                    );
                  }
                },
                child: const Text('Submit'),
              ),
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

  Future<bool> registerUser(
      List<Map<String, dynamic>> devices,
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

      for (var device in devices) {
        List<String> cameraNames = [];
        for (var controller in device['cameraControllers']) {
          cameraNames.add(controller.text);
        }
        // Here you can get device name, location, and inventory type
        String deviceName = device['deviceName'].text;
        String deviceLocation = device['deviceLocation'].text;
        String inventoryType = device['inventoryType'];

        // Perform insertion for each device
        final result = await connection.execute(
          'INSERT INTO ai.device_user (username, password, orgname, brandname, device_name, device_location, inventory_type, camera1, camera2, camera3, camera4, camera5, camera6) '
              'VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9, \$10, \$11, \$12, \$13)',
          parameters: [
            username,
            password,
            orgName,
            brandName,
            deviceName,
            deviceLocation,
            inventoryType,
            for (int i = 0; i < 6; i++)
              cameraNames.length > i ? cameraNames[i] : '',
          ],
        );
        print(result);
      }

      await connection.close();

      return true;
    } catch (e) {
      print('Error registering user: $e');
      return false;
    }
  }
}
