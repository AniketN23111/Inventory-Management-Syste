import 'package:flutter/material.dart';
import 'package:postgres/postgres.dart';

class EditDevicePage extends StatefulWidget {
  final List<List<dynamic>> userData;

  const EditDevicePage({Key? key, required this.userData}) : super(key: key);

  @override
  _EditDevicePageState createState() => _EditDevicePageState();
}

class _EditDevicePageState extends State<EditDevicePage> {
  List<Map<String, dynamic>> _devices = [];
  List<bool> _loadingStates = [];
  bool _isLoading = true; // Track overall loading state

  @override
  void initState() {
    super.initState();
    fetchDevices();
  }

  Future<void> fetchDevices() async {
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

      final results = await connection.execute(
        Sql.named('SELECT device_name, active FROM ai.device_user WHERE username = @username'),
        parameters: {'username': widget.userData[0][0]},
      );

      setState(() {
        _devices = results.map((row) => {'deviceName': row[0], 'active': row[1]}).toList();
        // Initialize loading states for each device to false
        _loadingStates = List.generate(_devices.length, (_) => false);
        _isLoading = false; // Set overall loading state to false when data is loaded
      });

      await connection.close();
    } catch (e) {
      print('Error fetching devices: $e');
    }
  }

  Future<void> toggleDeviceStatus(String deviceName, bool currentStatus, int index) async {
    try {
      // Set loading state for the current device to true
      setState(() {
        _loadingStates[index] = true;
      });

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

      await connection.execute(
        Sql.named('UPDATE ai.device_user SET active = @active WHERE username = @username AND device_name = @deviceName'),
        parameters: {'active': !currentStatus, 'username': widget.userData[0][0], 'deviceName': deviceName},
      );

      await connection.close();

      // Update the device list to reflect the changed status
      setState(() {
        _devices[index]['active'] = !currentStatus;
        // Set loading state for the current device to false
        _loadingStates[index] = false;
      });
    } catch (e) {
      print('Error toggling device status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Devices'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator()) // Show progress indicator while loading data
          : ListView.builder(
        itemCount: _devices.length,
        itemBuilder: (context, index) {
          final deviceName = _devices[index]['deviceName'];
          final isActive = _devices[index]['active'] as bool;

          return ListTile(
            title: Text(deviceName),
            subtitle: Text(isActive ? 'Active' : 'Inactive'),
            trailing: _loadingStates[index]
                ? const SizedBox(
              width: 24, // Set the width of the progress indicator
              height: 24, // Set the height of the progress indicator
              child: CircularProgressIndicator(
                strokeWidth: 2, // Adjust the stroke width of the progress indicator
              ),
            )
                : IconButton(
              icon: Icon(isActive ? Icons.toggle_off : Icons.toggle_on),
              onPressed: () => toggleDeviceStatus(deviceName, isActive, index),
            ),
          );
        },
      ),
    );
  }
}
