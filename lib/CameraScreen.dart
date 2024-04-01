import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_store/api.dart';
//import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
//import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:postgres/postgres.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

import 'AddDevicePage.dart';
import 'EditDevicePage.dart';
import 'InventoryDetailsPage.dart';
import 'ProductDetailsPage.dart';

class CameraScreen extends StatefulWidget {
  final String deviceName; // Accept device name as a parameter
  final String username;
  final String selectedDevice;
  final String inventoryType;
  final String brandName;
  final List<List<dynamic>> userData;
  const CameraScreen({Key? key, required this.deviceName,required this.username, required this.userData,required this.selectedDevice,required this.inventoryType,required this.brandName}) : super(key: key);
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
 // late String _deviceInfo=widget.selectedDevice.toString();
  Position? _currentPosition;
  late String imagename;
  //late Uint8List _imgebytes;
  late CloudApi api;
  late Connection? conn;
  String _searchQuery = '';
  String _detectedText = '';
  String _expirydate='';
  List<String> _ingrediants=[];
  late String _groupId;
  late String _inventoryType=widget.inventoryType.toString();
  int remaining=0;
  String product_name='';
  List<String> _filteredProducts = [];
  late DateTime _selectedDate;
  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
      _initializeCamera();
    _groupId = '';
    rootBundle.loadString('assets/clean-emblem-394910-905637ad42b3.json').then((json){
      api=CloudApi(json);
    });
    _captureTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      //_takePictureAndUpload();
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
      print(widget.username);
      print(widget.brandName);
    }
    catch(e)
    {
      print(e);
    }
  }
  String generateGroupId() {
    // Generate group id based on device name and timestamp
    return '${widget.username}_${widget.selectedDevice}_${DateTime.now().millisecondsSinceEpoch}';
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
    Uint8List _imgebytes = Uint8List(0);
    try {
      XFile picture = await _controller!.takePicture();
      final File imageFile = File(picture.path);
      img.Image? image = img.decodeImage(imageFile.readAsBytesSync());
      if (image != null) {
        image = img.grayscale(image);
        final grayscaleBytes = img.encodePng(image);
        final grayscaleImageFile = File('${dirPath}/grayscale_${DateTime
            .now()
            .millisecondsSinceEpoch}.png');
        await grayscaleImageFile.writeAsBytes(grayscaleBytes);

        // Use grayscale image for text recognition
        final fileName = grayscaleImageFile.path
            .split('/')
            .last;
        final metadata = <String, String>{
          'timestamp': DateTime
              .now()
              .millisecondsSinceEpoch
              .toString(),
          'device_info': widget.deviceName,
          'location': _currentPosition?.toString() ?? '',
        };
        // Upload the file to the bucket
        final response = await api.save(fileName, _imgebytes, metadata);
        print(response.downloadLink);
        print(metadata.toString());

        final textRecognizer = TextRecognizer();
        final inputImage = InputImage.fromFile(imageFile);
        final recognizedText = await textRecognizer.processImage(inputImage);
        final extractedText = recognizedText.text;
        final latestCaptureResult = await conn?.execute(
            'SELECT image_url, capturetime, location, devicename, groupid, extracted_text, username FROM ai.image_store ORDER BY capturetime DESC LIMIT 1');

        // print(latestCaptureResult);

        if (latestCaptureResult != null && latestCaptureResult.isNotEmpty) {
          final latestCapture = latestCaptureResult[0];
          try {
            final DateTime latestCaptureTime = DateTime.parse(
                latestCapture[1] as String);
            final String latestGroupId = latestCapture[4] as String;

            final currentTime = DateTime.now();
            final timeDifference = currentTime
                .difference(latestCaptureTime)
                .inSeconds;

            if (timeDifference <= 9) {
              // Reuse the group ID if the time difference is within 10 seconds
              _groupId = latestGroupId;
            } else {
              // Generate a new group ID
              _groupId = generateGroupId();
            }
          } catch (e) {
            print('Error parsing data: $e');
            // Handle the error here, such as skipping this data and moving forward
            // You can choose to log the error, skip this data, or take any other appropriate action
            // For example, you can generate a new group ID and continue
            _groupId = generateGroupId();
          }
        } else {
          // No previous captures found, generate a new group ID
          _groupId = generateGroupId();
        }
        print(_groupId);
        // Store username and image details in the database
        await _insertDataIntoPostgreSQL(
            response.downloadLink.toString(),
            DateTime.now().toString(),
            _currentPosition?.toString() ?? '',
            widget.selectedDevice,
            _groupId,
            extractedText,
            widget.username);

        setState(() {
          _imagePaths.add(picture.path);
          _latestImagePath = picture.path;
          _latestImageTimestamp = DateTime.now();
          _detectedText = extractedText;
        });
        print(extractedText);
        _ingrediants = _extractIngredients(extractedText.toString());
        _expirydate = _extractExpiryDate(extractedText.toString());
        final productName = _extractProductName(extractedText);
        print("Ingredients:- $_ingrediants");
        print("Expiry Date:- $_expirydate");
        print('Product Name: $productName');
      }
      //_uploadData();
    } catch (e) {
      print(e);
    }
  }


  Future<void> _insertDataIntoPostgreSQL(String imageUrl, String timestamp, String location, String deviceInfo,String groupid,String extractedText,String username) async {
    try {
      // Execute an insert query to insert data into PostgreSQL table
      await conn?.execute('INSERT INTO ai.image_store (image_url, capturetime, location, devicename,groupid,extracted_text,username)VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7)',
          parameters: [imageUrl, timestamp, location, deviceInfo,groupid,extractedText,username]);

      print('Data inserted into PostgreSQL successfully');
    } catch (e) {
      print('Error inserting data into PostgreSQL: $e');
    }
  }

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

  Future<List<String>> _searchProduct(String query) async {
    final List<String> products = [];
    try {
      final results = await conn?.execute(
        Sql.named('SELECT item_name FROM ai.inventory_inward_outward WHERE item_name ILIKE @query AND username = @username'),
        parameters: {
          'query': '%$query%',
          'username': widget.username,
        },
      );
      for (final row in results!) {
        final productName = row[0] as String;
        products.add(productName);
      }
    } catch (e) {
      print('Error executing query: $e');
    }
    return products;
  }


  void _onProductTap(String productName) async {
    // Fetch product details
    final productDetails = await getProductDetails(productName,widget.username);
    // Navigate to product details page and pass the details
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsPage(
          productDetails: productDetails,
          username: widget.username, // Pass the username
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> getProductDetails(String productName, String username) async {
    try {
      final results = await conn?.execute(
        'SELECT * FROM ai.inventory_inward_outward WHERE item_name = \$1 AND username = \$2',
        parameters:[productName, username],
      );
      if (results != null && results.isNotEmpty) {
        // Return the first row of the query result
        return results.first.toColumnMap();
      } else {
        return {}; // Return an empty map if no results found
      }
    } catch (e) {
      print('Error fetching product details: $e');
      return {}; // Return an empty map in case of error
    }
  }


  Future<void> _searchInventoryByDate(String selectedDate) async {
    print(selectedDate);
    try {
      final results = await conn?.execute(
        'SELECT item_name, inward, outward FROM ai.inventory_inward_outward WHERE date = \$1',
        parameters: [selectedDate],
      );
      print(results);
      List<Map<String, dynamic>> inventoryData = [];
      if (results != null) {
        for (var result in results) {
          inventoryData.add({
            'item_name': result[0],
            'inward': result[1],
            'outward': result[2],
          });
        }
      }
      // Process the results and display them on a new page
      // Navigate to the new page with the inventory data
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InventoryDetailsPage(inventoryData: inventoryData),
        ),
      );
    } catch (e) {
      print('Error searching inventory by date: $e');
    }
  }

  Future<void> _uploadData() async {
    try {
      // Execute a query to retrieve data with similar group IDs
      final results = await conn?.execute(
        'SELECT groupid, extracted_text FROM ai.image_store WHERE groupid = \$1',
        parameters: [_groupId],
      );

      // Combine all extracted texts with the same group ID
      String combinedText = '';
      String groupid = '';
      String brandname = '';
      for (final result in results ?? []) {
        final extractedText = result[1] as String;
        combinedText += '$extractedText ';
        groupid = result[0] as String;
      }

      // Extract product name and expiry date from the combined text
      final productName = _extractProductName(combinedText);
      final expiryDate = _extractExpiryDate(combinedText);
      brandname =widget.brandName;
      print('Combined Text: $combinedText');
      print('Product Name: $productName');
      print('Expiry Date: $expiryDate');
      print('Inventory Type: $_inventoryType');

      // Check if both product name and expiry date are not null
      if (productName.isNotEmpty && expiryDate.isNotEmpty && expiryDate != 'Expiry date not found') {
        // Store the data in the "inventory" table
        await _insertDataIntoInventory(productName,expiryDate,groupid,brandname);
        print('Data stored in inventory table: $productName, $expiryDate');
      } else {
        print('Product name or expiry date is null or invalid, data not stored in inventory table.');
      }

      // Now you can store or further process the productName and expiryDate as needed
    } catch (e) {
      print('Error executing query: $e');
    }
  }

  Future<void> _insertDataIntoInventory(String itemName, String expiryDate,String GroupID, String BrandName) async {
    try {
      final currentDate = DateTime.now().toIso8601String();
      int deviceIndex = widget.userData.indexWhere((row) => row.contains(widget.selectedDevice));
      String username =widget.username;
      String location =widget.userData[deviceIndex][12];
      String device=widget.selectedDevice;
      print(location);
      print(device);
      // Execute an insert query to insert data into the "inventory" table
      await conn?.execute(
        'INSERT INTO ai.inventory (item_name, expiry_date,groupid,brandname,location,device) VALUES (\$1, \$2,\$3, \$4,\$5,\$6)',
        parameters: [itemName, expiryDate,GroupID,BrandName,location,device],
      );
      if (_inventoryType == 'Inward') {
        await _updateOrInsertDataIntoInwardInventory(itemName, expiryDate, username, currentDate,BrandName);
      } else if (_inventoryType == 'Outward') {
        await _updateOrInsertDataIntoOutwardInventory(itemName, expiryDate, username, currentDate,BrandName);
      } else {
        print('Invalid inventory type: $_inventoryType');
      }
      print('Data inserted into inventory table successfully');
    } catch (e) {
      print('Error inserting data into inventory table: $e');
    }
  }
  Future<void> _updateOrInsertDataIntoInwardInventory(String itemName, String expiryDate, String username, String currentDate, String brandname) async {
    try {
      final result = await conn?.execute(
        'SELECT * FROM ai.inventory_inward_outward WHERE item_name = \$1 AND expiry_date = \$2 AND inward_device = \$3 AND username = \$4 AND date = \$5',
        parameters: [itemName, expiryDate, widget.selectedDevice, username, currentDate],
      );
      if (result != null && result.isNotEmpty) {
        // Record exists, update inward device
        await conn?.execute(
          'UPDATE ai.inventory_inward_outward SET inward = inward + 1,inward_device = \$1 WHERE item_name = \$2 AND expiry_date = \$3 AND inward_device = \$4 AND username = \$5 AND date = \$6',
          parameters: [widget.selectedDevice, itemName, expiryDate, widget.selectedDevice, username, currentDate],
        );
        print('Inward record updated for $itemName on $currentDate');
      } else {
        // Record does not exist, insert a new entry with inward
        await conn?.execute(
          'INSERT INTO ai.inventory_inward_outward (inward_device, inward, item_name, expiry_date, username, date, brandname) VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7)',
          parameters: [widget.selectedDevice, 1, itemName, expiryDate, username, currentDate, brandname],
        );
        print('Data inserted into inward inventory table successfully');
      }
    } catch (e) {
      print('Error updating or inserting data into inward inventory table: $e');
    }
  }

  Future<void> _updateOrInsertDataIntoOutwardInventory(String itemName, String expiryDate, String username, String currentDate, String brandname) async {
    try {
      final result = await conn?.execute(
        'SELECT * FROM ai.inventory_inward_outward WHERE item_name = \$1 AND expiry_date = \$2 AND outward_device = \$3 AND username = \$4 AND date = \$5',
        parameters: [itemName, expiryDate, widget.selectedDevice, username, currentDate],
      );
      if (result != null && result.isNotEmpty) {
        // Record exists, update outward device
        await conn?.execute(
          'UPDATE ai.inventory_inward_outward SET outward= outward + 1,outward_device = \$1 WHERE item_name = \$2 AND expiry_date = \$3 AND outward_device = \$4 AND username = \$5 AND date = \$6',
          parameters: [widget.selectedDevice, itemName, expiryDate, widget.selectedDevice, username, currentDate],
        );
        print('Outward record updated for $itemName on $currentDate');
      } else {
        // Record does not exist, insert a new entry with outward
        await conn?.execute(
          'INSERT INTO ai.inventory_inward_outward (outward_device, outward, item_name, expiry_date, username, date, brandname) VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7)',
          parameters: [widget.selectedDevice, 1, itemName, expiryDate, username, currentDate, brandname],
        );
        print('Data inserted into outward inventory table successfully');
      }
    } catch (e) {
      print('Error updating or inserting data into outward inventory table: $e');
    }
  }

  List<String> _extractIngredients(String extractedText) {
    // Define keywords that indicate the start of the ingredients list
    final ingredientKeywords = ['Ingredients:', 'Contains:', 'Ingredients:', 'INGREDIENTS:'];

    // Iterate through each keyword to find ingredients list
    for (final keyword in ingredientKeywords) {
      final startIndex = extractedText.indexOf(keyword);
      if (startIndex != -1) {
        // Extract the text after the keyword
        final textAfterKeyword = extractedText.substring(startIndex + keyword.length);

        // Split the text into lines
        final lines = textAfterKeyword.split('\n');

        // Remove any leading and trailing whitespace from each line
        final trimmedLines = lines.map((line) => line.trim()).toList();

        // Remove empty lines
        final nonEmptyLines = trimmedLines.where((line) => line.isNotEmpty).toList();

        // Return the list of non-empty lines
        return nonEmptyLines;
      }
    }
    return [];
  }

  String _extractExpiryDate(String extractedText) {
    final datePatterns = [
      r'\b(?:Best Before|Exp|Use By)[: ]+(\d{1,2}[./-]\d{1,2}[./-]\d{2,4})\b',
      r'\b(?:MFG|Mfd|Manufactured) Date[: ]+(\d{1,2}[./-]\d{1,2}[./-]\d{2,4})\b',
      r'(\d{1,2}[./-]\d{4})\b',
      r'\bBest\s*Before:\s*([A-Z]+)\s*/\s*(\d{1,2})\b',
      r'(\d{1,2}[./-]\d{1,2}[./-]\d{2,4})\b',// Added pattern for "Best Before:FEB/25"
    ];

    DateTime? firstDate;
    DateTime? secondDate;
    final currentDate = DateTime.now();

    for (final pattern in datePatterns) {
      final RegExp regex = RegExp(pattern);
      final matches = regex.allMatches(extractedText);

      for (final match in matches) {
        if (pattern.contains('Best Before')) {
          final monthString = match.group(1);
          final dayString = match.group(2);

          final currentDate = DateTime.now();
          final currentYear = currentDate.year;

          int month = 1;
          switch (monthString) {
            case 'JAN':
              month = 1;
              break;
            case 'FEB':
              month = 2;
              break;
            case 'MAR':
              month = 3;
              break;
            case 'APR':
              month = 4;
              break;
            case 'MAY':
              month = 5;
              break;
            case 'JUN':
              month = 6;
              break;
            case 'JUL':
              month = 7;
              break;
            case 'AUG':
              month = 8;
              break;
            case 'SEP':
              month = 9;
              break;
            case 'OCT':
              month = 10;
              break;
            case 'NOV':
              month = 11;
              break;
            case 'DEC':
              month = 12;
              break;
            default:
            // Handle unknown month string
              continue; // Skip processing if month is unknown
          }

          final day = int.tryParse(dayString!);

          if (day != null && month != null) {
            final expiryDate = DateTime(currentYear, month, day);
            if (expiryDate.year == currentDate.year && expiryDate.month == currentDate.month) {
              return 'Expires this month';
            } else if (expiryDate.isAfter(currentDate)) {
              return 'Expires on ${expiryDate.toString()}';
            } else {
              return 'Expired';
            }
          }
        } else {
          final dateString = match.group(1)!;
          final parts = dateString.split(RegExp(r'[-/\\]'));
          final month = int.tryParse(parts[0]);
          final year = int.tryParse(parts[1]);
          if (month != null && year != null && year >= 1000) {
            final date = DateTime(year, month);
            if (firstDate == null) {
              firstDate = date;
            } else if (secondDate == null || date.isAfter(secondDate)) {
              secondDate = date;
            }
          }
        }
      }
    }

    if (firstDate != null && secondDate == null) {
      return 'Expires on ${firstDate.toString()}';
    } else if (secondDate != null && (secondDate.isAfter(currentDate) || secondDate.isAtSameMomentAs(currentDate))) {
      return 'Expires on ${secondDate.toString()}';
    } else {
      return 'Expiry date not found';
    }
  }

  List<String> _filteredImages() {
    if (_searchQuery.isEmpty) {
      return _imagePaths;
    } else {
      return _imagePaths.where((path) => path.contains(_searchQuery)).toList();
    }
  }
  String _extractProductName(String extractedText) {
    // Define keywords that indicate the start of the product name
    final productNameKeywords = ['PONDS DREAMFLOWER', 'PRODUCT NAME:', 'Tacrolimus Ointment'];

    // Iterate through each keyword to find the product name
    for (final keyword in productNameKeywords) {
      final startIndex = extractedText.indexOf(keyword);
      if (startIndex != -1) {
        return keyword; // Return the matching keyword as the product name
      }
    }

    return 'Product name not found'; // Return if no keyword is found
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Container(); // Return a placeholder widget if the camera is not initialized
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Auto Capture')),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(widget.username), // Display username in the header
              accountEmail: null, // Set to null or provide user's email if available
              currentAccountPicture: const CircleAvatar(
                child: Icon(Icons.person), // You can replace Icon with user's profile picture
              ),
            ),
            ListTile(
              title: const Text('Edit Devices'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EditDevicePage(userData: widget.userData,)), // Navigate to DeviceEditingPage
                );
              },
            ),
            ListTile(
              title: const Text('Add Device'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddDevicePage(userData: widget.userData)), // Navigate to AddDevicePage
                );
              },
            ),
            // Add more ListTile widgets for other options if needed
          ],
        ),
      ),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search by product name',
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                        _searchProduct(value);
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () async {
                      final products = await _searchProduct(_searchQuery);
                      setState(() {
                        _filteredProducts = products;
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final DateTime? selectedDate = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (selectedDate != null) {
                        setState(() {
                          _selectedDate = selectedDate;
                        });
                        String formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
                        print(formattedDate); // Print formatted date
                        _searchInventoryByDate(formattedDate);
                      }
                    },
                  )
                ],
              ),
            ),
          ),
          // Display filtered products
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                return _filteredProducts.isNotEmpty
                    ? GestureDetector(
                  onTap: () => _onProductTap(_filteredProducts[index]),
                  child: ListTile(
                    title: Text(_filteredProducts[index]),
                  ),
                )
                    : Container();
              },
              childCount: _filteredProducts.length,
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 500, // Adjust the height as needed
              child: CameraPreview(_controller!),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _takePictureAndUpload,
                child: const Text('Take Photo'),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _uploadData,
                child: const Text('Upload Data'),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                return _latestImagePath != null
                    ? Container(
                  padding: const EdgeInsets.all(16.0),
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
                    ? SizedBox(
                  height: 100.0,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: filteredPaths.length,
                    itemBuilder: (context, index) {
                      final imagePath = filteredPaths[index];
                      return Container(
                        margin: const EdgeInsets.all(4.0),
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Detected Text: $_detectedText'),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Ingredients: $_ingrediants'),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Expiry Date: $_expirydate'),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Product Name: $product_name'),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Remaining: $remaining'),
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
