import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_store/api.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info/device_info.dart';
import 'package:geolocator/geolocator.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:postgres/postgres.dart';
import 'api.dart';

class CameraScreen extends StatefulWidget {
  final String deviceName; // Accept device name as a parameter

  const CameraScreen({Key? key, required this.deviceName}) : super(key: key);
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  late List<CameraDescription> _cameras;
  late CameraDescription _selectedCamera;
  List<String> _imagePaths = [];
  String? _latestImagePath;
  late DateTime? _latestImageTimestamp;
  late Timer _captureTimer;
  late String _deviceInfo=widget.deviceName.toString();
  Position? _currentPosition;
  late String imagename;
  late Uint8List _imgebytes;
  late CloudApi api;
  late Connection? conn;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
      _initializeCamera();
    rootBundle.loadString('assets/clean-emblem-394910-905637ad42b3.json').then((json){
      api=CloudApi(json);
    });
    _captureTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      _takePictureAndUpload();
    });
    _getLocation();
    _postgraseconnection();
  }
  Future<void> _postgraseconnection() async {
    try {
       conn = await Connection.open(
        Endpoint(
            host: '34.71.87.187',
            port:5432,
            database: 'airegulation_dev',
            username: 'postgres',
            password: 'India@5555'
        ),
        settings : const ConnectionSettings(sslMode: SslMode.disable),
      );
      print("Connected successfully");
    }
    catch(e)
    {
      print(e);
    }
  }
  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isNotEmpty) {
      _selectedCamera = _cameras.first;
      _controller = CameraController(_selectedCamera, ResolutionPreset.medium, enableAudio: false);
      _controller?.initialize().then((_) {
        if (!mounted) {
          return;
        }
        setState(() {});
      });
    } else {
      print('No camera available');
    }
  }
  Future<void> _insertDataIntoPostgreSQL(String imageUrl, DateTime timestamp, String location, String deviceInfo) async {
    try {
      // Execute an insert query to insert data into PostgreSQL table
      await conn?.execute('INSERT INTO ai.image_store (image_url, capturetime, location, devicename)VALUES (\$1, \$2, \$3, \$4)',
          parameters: [imageUrl, timestamp, location, deviceInfo]);

      print('Data inserted into PostgreSQL successfully');
    } catch (e) {
      print('Error inserting data into PostgreSQL: $e');
    }
  }
  Future<Map<String, dynamic>> loadServiceAccountJson() async {
    String jsonString = await rootBundle.loadString('assets/clean-emblem-394910-905637ad42b3.json');
    return json.decode(jsonString);
  }
  Future<void> _takePictureAndUpload() async {
    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/Pictures/flutter_app';
    await Directory(dirPath).create(recursive: true);

    if (_controller!.value.isTakingPicture) {
      return null;
    }

    try {
      XFile picture = await _controller!.takePicture();
      final File imageFile = File(picture.path);
      _imgebytes =imageFile.readAsBytesSync();
      final fileName = picture.path.split('/').last;

      final metadata = <String, String>{
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        'device_info': widget.deviceName,
        'location': _currentPosition?.toString() ?? '',
      };
      // Upload the file to the bucket
      final response= await api.save(fileName, _imgebytes,metadata);
      print(response.downloadLink);
      print(metadata.toString());

      //await _insertDataIntoPostgreSQL(response.downloadLink.toString(), DateTime.now(), _currentPosition?.toString() ?? '', _deviceInfo);

      setState(() {
        _imagePaths.add(picture.path);
        _latestImagePath = picture.path;
        _latestImageTimestamp = DateTime.now();
      });

    } catch (e) {
      print(e);
    }
  }

 /* Future<void> _getDeviceInfo() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      setState(() {
        _deviceInfo = 'Android - ${androidInfo.model}';
      });
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      setState(() {
        _deviceInfo = 'iOS - ${iosInfo.model}';
      });
    }
  }*/

  Future<void> _getLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  Future<void> _downloadAndUpload() async {
    try {
      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];

      sheet.getRangeByIndex(1, 1).setText("File Name");
      sheet.getRangeByIndex(1, 2).setText("Mobile Name");
      sheet.getRangeByIndex(1, 3).setText("Timestamp");
      sheet.getRangeByIndex(1, 4).setText("Location");

      // Write Mobile info, Timestamp, Location, and File Name for each image
      for (int i = 0; i < _imagePaths.length; i++) {
        sheet.getRangeByIndex(i + 2, 1).setText(_imagePaths[i].split('/').last);
        sheet.getRangeByIndex(i + 2, 2).setText(_deviceInfo); // Mobile info in column A
        sheet.getRangeByIndex(i + 2, 3).setText(_latestImageTimestamp?.toString() ?? ''); // Timestamp in column B
        sheet.getRangeByIndex(i + 2, 4).setText(_currentPosition?.toString() ?? ''); // Location in column C
        // File Name in column D
      }
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      final String path = (await getApplicationSupportDirectory()).path;
      final String fileName = '$path/Output.xlsx';
      final File file = File(fileName);
      await file.writeAsBytes(bytes, flush: true);

      // Upload images to Google Drive
      for (final imagePath in _imagePaths) {
        final imageFile = File(imagePath);
      }

      // Open the downloaded file
      OpenFile.open(fileName);

    } catch (e) {
      print('Error during download and upload: $e');
    }
  }

  Future<Map<String, int>> getPhotoCountsByDevice() async {
    try {
      final results = await conn?.execute('SELECT devicename, COUNT(*) FROM ai.image_store GROUP BY devicename');
      Map<String, int> photoCountsByDevice = {};
      for (final row in results ?? []) {
        photoCountsByDevice[row[0]] = row[1];
      }
      return photoCountsByDevice;
    } catch (e) {
      print('Error fetching photo counts by device: $e');
      return {};
    }
  }

  Future<Map<String, int>> getPhotoCountsByDate() async {
    try {
      final results = await conn?.execute('SELECT DATE(capturetime), COUNT(*) FROM ai.image_store GROUP BY DATE(capturetime)');
      Map<String, int> photoCountsByDate = {};
      for (final row in results ?? []) {
        photoCountsByDate[row[0]] = row[1];
      }
      return photoCountsByDate;
    } catch (e) {
      print('Error fetching photo counts by date: $e');
      return {};
    }
  }

  Future<void> displayStatistics() async {
    try {
      final deviceStats = await getPhotoCountsByDevice();
      final dateStats = await getPhotoCountsByDate();

      // Calculate total number of photos
      int totalPhotos = deviceStats.values.fold(0, (sum, count) => sum + count);

      print('Total number of photos: $totalPhotos');

      print('\nPhoto counts by device:');
      deviceStats.forEach((device, count) {
        print('$device: $count photos');
      });

      print('\nPhoto counts by date:');
      dateStats.forEach((date, count) {
        print('$date: $count photos');
      });
    } catch (e) {
      print('Error fetching and displaying inventory statistics: $e');
    }
  }

  Future<void> _selectquery() async {
    try {
      final results = await conn?.execute('SELECT * FROM ai.image_store WHERE devicename LIKE \$1',
          parameters: ['%$_searchQuery%',] // Search for device names containing the search query
      );
      print(results);
      displayStatistics();
    } catch (e) {
      print(e);
    }
    displayStatistics();
  }
  List<String> _filteredImages() {
    if (_searchQuery.isEmpty) {
      return _imagePaths;
    } else {
      return _imagePaths.where((path) => path.contains(_searchQuery)).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Container(); // Return a placeholder widget if the camera is not initialized
    }
    return Scaffold(
      appBar: AppBar(title: Text('Auto Capture')),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Search by device name',
                  suffixIcon: IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _selectquery();
                      });
                    },
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              height: 500, // Adjust the height as needed
              child: CameraPreview(_controller!),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _downloadAndUpload,
                child: Text('Download Excel & Upload to Drive'),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                return _latestImagePath != null
                    ? Container(
                  padding: EdgeInsets.all(16.0),
                )
                    : Container();
              },
              childCount: 1,
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                final filteredPaths = _filteredImages();
                return filteredPaths.isNotEmpty
                    ? Container(
                  height: 100.0,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: filteredPaths.length,
                    itemBuilder: (context, index) {
                      final imagePath = filteredPaths[index];
                      return Container(
                        margin: EdgeInsets.all(4.0),
                        child: Image.file(File(imagePath), height: 80.0),
                      );
                    },
                  ),
                )
                    : Container();
              },
              childCount: 1,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _captureTimer.cancel();
    _controller!.dispose();
    super.dispose();
  }
}
