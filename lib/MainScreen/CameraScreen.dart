import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_store/AllProductPage//AllProductDetails.dart';
import 'package:image_store/GoogleApi/api.dart';
import 'package:image_store/Profile/ProfileDetails.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:postgres/postgres.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:image_store/AddEditDevices/AddDevicePage.dart';
import 'package:image_store/AddEditDevices/EditDevicePage.dart';
import 'package:image_store/Product/ProductDetailsPage.dart';


class CameraScreen extends StatefulWidget {
  final String deviceName; // Accept device name as a parameter
  final String username;
  final String selectedDevice;
  final String inventoryType;
  final String brandName;
  final List<List<dynamic>> userData;
  const CameraScreen({
    Key? key, required this.deviceName,required this.username, required this.userData,required this.selectedDevice,required this.inventoryType,required this.brandName}) : super(key: key);
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
  Timer? _captureTimer ;

  // late String _deviceInfo=widget.selectedDevice.toString();
  Position? _currentPosition;
  late String imagename;

  //late Uint8List _imgebytes;
  late CloudApi api;
  late Connection? conn;
  String _searchQuery = '';
  String _detectedText = '';
  String _expirydate = '';
  List<String> _ingrediants = [];
  late String _groupId;
  late String _inventoryType = widget.inventoryType.toString();
  int remaining = 0;
  String product_name = '';
  List<String> _filteredProducts = [];
  late DateTime _selectedDate;
  TextEditingController _timerController = TextEditingController();
  int _timerSeconds = 10;
  List<String> _productNames = [];

  bool isexpiry =false;
  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _initializeCamera();
    _groupId = '';
    rootBundle.loadString('assets/clean-emblem-394910-905637ad42b3.json').then((
        json) {
      api = CloudApi(json);
    });
    _postgraseconnection();

    _storeDetailsInPrefs(widget.deviceName, widget.brandName, widget.username, widget.userData,widget.inventoryType,widget.selectedDevice);
  }


  void _startTimer() {
    _captureTimer = Timer.periodic(Duration(seconds: _timerSeconds), (timer) {
      _takePictureAndUpload();
    });
  }
//Postgres Connection
  Future<void> _postgraseconnection() async {
    try {
      conn = await Connection.open(
        Endpoint(
            host: '34.71.87.187',
            port: 5432,
            database: 'airegulation_dev',
            username: 'postgres',
            password: 'India@5555'
        ),
        settings: const ConnectionSettings(sslMode: SslMode.disable),
      );
      print("Connected successfully");
      print(widget.username);
      print(widget.brandName);
      await _retrieveProductNames();
    }
    catch (e) {
      print(e);
    }
  }
//Generate Group ID
  String generateGroupId() {
    // Generate group id based on device name and timestamp
    return '${widget.username}_${widget.selectedDevice}_${DateTime
        .now()
        .millisecondsSinceEpoch}';
  }
//Initialize Camera
  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isNotEmpty) {
      _selectedCamera = _cameras.first;
      _controller = CameraController(
          _selectedCamera, ResolutionPreset.medium, enableAudio: false);
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
//Google Cloud Service Account
  Future<Map<String, dynamic>> loadServiceAccountJson() async {
    String jsonString = await rootBundle.loadString(
        'assets/clean-emblem-394910-905637ad42b3.json');
    return json.decode(jsonString);
  }
//Take Picture And Upload to Google Cloud
  Future<void> _takePictureAndUpload() async {
    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/Pictures/flutter_app';
    await Directory(dirPath).create(recursive: true);
    isexpiry=false;

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
        img.Image adjustimage =img.adjustColor(image,contrast: 1.5);
        final grayscaleBytes = img.encodePng(adjustimage);
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
        final inputImage = InputImage.fromFile(grayscaleImageFile);
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

            if (timeDifference <= _timerSeconds - 3) {
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
        product_name = _extractProductName(extractedText.toString());
        print("Ingredients:- $_ingrediants");
        print("Expiry Date:- $_expirydate");
        print('Product Name: $product_name');
      }
      _uploadData();
    } catch (e) {
      print(e);
    }
  }

  //DATABASE
  //Insert Data To Image store
  Future<void> _insertDataIntoPostgreSQL(String imageUrl, String timestamp,
      String location, String deviceInfo, String groupid, String extractedText,
      String username) async {
    try {
      // Execute an insert query to insert data into PostgreSQL table
      await conn?.execute(
          'INSERT INTO ai.image_store (image_url, capturetime, location, devicename,groupid,extracted_text,username)VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7)',
          parameters: [
            imageUrl,
            timestamp,
            location,
            deviceInfo,
            groupid,
            extractedText,
            username
          ]);

      print('Data inserted into PostgreSQL successfully');
    } catch (e) {
      print('Error inserting data into PostgreSQL: $e');
    }
  }

//Get the Search Products List
  Future<List<String>> _searchProduct(String query) async {
    final Set<String> uniqueProducts = {
    }; // Use a set to store unique product names
    try {
      final results = await conn?.execute(
        Sql.named(
            'SELECT item_name FROM ai.inventory_inward_outward WHERE item_name ILIKE @query AND username = @username'),
        parameters: {
          'query': '%$query%',
          'username': widget.username,
        },
      );
      for (final row in results!) {
        final productName = row[0] as String;
        uniqueProducts.add(productName); // Add product name to the set
      }
    } catch (e) {
      print('Error executing query: $e');
    }
    // Convert set back to list before returning
    return uniqueProducts.toList();
  }
  //Upload Data to the Postgres in Image Store
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
      String productName ='';
      String expiryDate ='';
      for (final result in results ?? []) {
        final extractedText = result[1] as String;
        combinedText += '$extractedText ';
        groupid = result[0] as String;
      }
    // Extract product name and expiry date from the combined text
      if(productName.isEmpty)
        {
          productName = _extractProductName(combinedText.toString());
        }
       if(expiryDate.isEmpty)
         {
           expiryDate = _extractExpiryDate(combinedText);
         }
      brandname = widget.brandName;
      print('Combined Text: $combinedText');
      print('Product Name: $productName');
      print('Expiry Date: $expiryDate');
      print('Inventory Type: $_inventoryType');

      // Check if both product name and expiry date are not null
      if (productName.isNotEmpty && expiryDate.isNotEmpty &&
          expiryDate != 'Expiry date not found' && expiryDate!='Expired product') {
        // Store the data in the "inventory" table
        await _insertDataIntoInventory(
            productName, expiryDate, groupid, brandname);
        print('Data stored in inventory table: $productName, $expiryDate');
      } else {
        print('Product name or expiry date is null or invalid, data not stored in inventory table.');
      }

      // Now you can store or further process the productName and expiryDate as needed
    } catch (e) {
      print('Error executing query: $e');
    }
  }
//Upload data to Inventory Table
  Future<void> _insertDataIntoInventory(String itemName, String expiryDate,
      String GroupID, String BrandName) async {
    try {
      final currentDate = DateTime.now().toIso8601String();
      int deviceIndex = widget.userData.indexWhere((row) =>
          row.contains(widget.selectedDevice));
      String username = widget.username;
      String location = widget.userData[deviceIndex][12];
      String device = widget.selectedDevice;
      print(location);
      print(device);
      // Execute an insert query to insert data into the "inventory" table
      await conn?.execute(
        'INSERT INTO ai.inventory (item_name, expiry_date,groupid,brandname,location,device) VALUES (\$1, \$2,\$3, \$4,\$5,\$6)',
        parameters: [
          itemName,
          expiryDate,
          GroupID,
          BrandName,
          location,
          device
        ],
      );
      if (_inventoryType == 'Inward') {
        await _updateOrInsertDataIntoInwardInventory(
            itemName, expiryDate, username, currentDate, BrandName);
      } else if (_inventoryType == 'Outward') {
        await _updateOrInsertDataIntoOutwardInventory(
            itemName, expiryDate, username, currentDate, BrandName);
      } else {
        print('Invalid inventory type: $_inventoryType');
      }
      print('Data inserted into inventory table successfully');
      const snackBar = SnackBar(
          content: Text('Data stored in inventory table.'),
          backgroundColor: Colors.green);
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    } catch (e) {
      print('Error inserting data into inventory table: $e');
      const snackBar = SnackBar(content: Text(
          'Product name or expiry date is null or invalid, data not stored in inventory table.'),
          backgroundColor: Colors.red);
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
  }
//Insert data to when Inventory is inward
  Future<void> _updateOrInsertDataIntoInwardInventory(String itemName,
      String expiryDate, String username, String currentDate,
      String brandname) async {
    try {
      final result = await conn?.execute(
        'SELECT * FROM ai.inventory_inward_outward WHERE item_name = \$1 AND expiry_date = \$2 AND inward_device = \$3 AND username = \$4 AND date = \$5',
        parameters: [
          itemName,
          expiryDate,
          widget.selectedDevice,
          username,
          currentDate
        ],
      );
      if (result != null && result.isNotEmpty) {
        // Record exists, update inward device
        await conn?.execute(
          'UPDATE ai.inventory_inward_outward SET inward = inward + 1,inward_device = \$1 WHERE item_name = \$2 AND expiry_date = \$3 AND inward_device = \$4 AND username = \$5 AND date = \$6',
          parameters: [
            widget.selectedDevice,
            itemName,
            expiryDate,
            widget.selectedDevice,
            username,
            currentDate
          ],
        );
        print('Inward record updated for $itemName on $currentDate');
      } else {
        // Record does not exist, insert a new entry with inward
        await conn?.execute(
          'INSERT INTO ai.inventory_inward_outward (inward_device, inward, item_name, expiry_date, username, date, brandname) VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7)',
          parameters: [
            widget.selectedDevice,
            1,
            itemName,
            expiryDate,
            username,
            currentDate,
            brandname
          ],
        );
        print('Data inserted into inward inventory table successfully');
        const snackBar = SnackBar(
            content: Text('Data stored in inventory table.'),
            backgroundColor: Colors.green);
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
    } catch (e) {
      print('Error updating or inserting data into inward inventory table: $e');
      const snackBar = SnackBar(content: Text(
          'Product name or expiry date is null or invalid, data not stored in inventory table.'),
          backgroundColor: Colors.red);
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
  }
//Insert data to when Inventory is Outward
  Future<void> _updateOrInsertDataIntoOutwardInventory(String itemName,
      String expiryDate, String username, String currentDate,
      String brandname) async {
    try {
      final result = await conn?.execute(
        'SELECT * FROM ai.inventory_inward_outward WHERE item_name = \$1 AND expiry_date = \$2 AND outward_device = \$3 AND username = \$4 AND date = \$5',
        parameters: [
          itemName,
          expiryDate,
          widget.selectedDevice,
          username,
          currentDate
        ],
      );
      if (result != null && result.isNotEmpty) {
        // Record exists, update outward device
        await conn?.execute(
          'UPDATE ai.inventory_inward_outward SET outward= outward + 1,outward_device = \$1 WHERE item_name = \$2 AND expiry_date = \$3 AND outward_device = \$4 AND username = \$5 AND date = \$6',
          parameters: [
            widget.selectedDevice,
            itemName,
            expiryDate,
            widget.selectedDevice,
            username,
            currentDate
          ],
        );
        if (kDebugMode) {
          print('Outward record updated for $itemName on $currentDate');
        }
      } else {
        // Record does not exist, insert a new entry with outward
        await conn?.execute(
          'INSERT INTO ai.inventory_inward_outward (outward_device, outward, item_name, expiry_date, username, date, brandname) VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7)',
          parameters: [
            widget.selectedDevice,
            1,
            itemName,
            expiryDate,
            username,
            currentDate,
            brandname
          ],
        );
        print('Data inserted into outward inventory table successfully');
      }
    } catch (e) {
      print(
          'Error updating or inserting data into outward inventory table: $e');
    }
  }
//Extract Ingredients
  List<String> _extractIngredients(String extractedText) {
    // Define keywords that indicate the start of the ingredients list
    final ingredientKeywords = [
      'Ingredients:',
      'Contains:',
      'Ingredients:',
      'INGREDIENTS:'
    ];

    // Iterate through each keyword to find ingredients list
    for (final keyword in ingredientKeywords) {
      final startIndex = extractedText.indexOf(keyword);
      if (startIndex != -1) {
        // Extract the text after the keyword
        final textAfterKeyword = extractedText.substring(
            startIndex + keyword.length);

        // Split the text into lines
        final lines = textAfterKeyword.split('\n');

        // Remove any leading and trailing whitespace from each line
        final trimmedLines = lines.map((line) => line.trim()).toList();

        // Remove empty lines
        final nonEmptyLines = trimmedLines.where((line) => line.isNotEmpty)
            .toList();

        // Return the list of non-empty lines
        return nonEmptyLines;
      }
    }
    return [];
  }
  //Get all the Product Details
  Future<void> _getDetails() async {
    try {
      final results = await conn?.execute(
        'SELECT * FROM ai.inventory_inward_outward WHERE username = \$1',
        parameters: [widget.username],
      );
      if (results != null && results.isNotEmpty) {
        // Convert the query results to a list of maps
        List<Map<String, dynamic>> productDetailsList = [];
        for (final result in results) {
          productDetailsList.add(result.toColumnMap());
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                AllProductDetails(
                  productDetailsList: productDetailsList,
                ),
          ),
        );
      } else {
        // No matching records found
        print('No matching records found for username: ${widget.username}');
      }
    } catch (e) {
      print('Error fetching product details: $e');
    }
  }
//After Search when tap on that product it will get the Info of Tapped Product
  void _onProductTap(String productName) async {
    // Fetch product details
    final productDetails = await getProductDetails(
        productName, widget.username);
    // Navigate to product details page and pass the details
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            productDetailsPage(
              productDetailsList: productDetails,
              username: widget.username, // Pass the username
              userData: widget.userData,
            ),
      ),
    );
  }
  // Get the product List
  Future<List<Map<String, dynamic>>> getProductDetails(String productName,
      String username) async {
    try {
      final results = await conn?.execute(
        'SELECT * FROM ai.inventory_inward_outward WHERE item_name = \$1 AND username = \$2',
        parameters: [productName, username],
      );
      if (results != null && results.isNotEmpty) {
        // Convert query results to a list of maps
        List<Map<String, dynamic>> productDetailsList = [];
        for (final result in results) {
          productDetailsList.add(result.toColumnMap());
        }
        return productDetailsList;
      } else {
        return []; // Return an empty list if no results found
      }
    } catch (e) {
      print('Error fetching product details: $e');
      return []; // Return an empty list in case of error
    }
  }


  String _extractExpiryDate(String extractedText) {
    final datePatterns = [
      r'\b(?:Best Before|Exp|Use By)[: ]+(\d{1,2}[./-]\d{1,2}[./-]\d{2,4})\b',
      r'\b(?:MFG|Mfd|Manufactured) Date[: ]+(\d{1,2}[./-]\d{1,2}[./-]\d{2,4})\b',
      r'(\d{1,2}[./-]\d{4})\b',
      r'(\d{1,2}[./-]\d{2})\b',
      r'\bBest\s*Before:\s*([A-Z]+)\s*/\s*(\d{1,2})\b',
      r'(\d{1,2}[./-]\d{1,2}[./-]\d{2,4})\b',
      r'(\d{1,2})(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)(\d{2})\b',
      r'\b(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC) (\d{2})\b', // Pattern for "JAN 24"
      r'(\d{2}[./-]\d{2}[./-]\d{2,4})\b',
      r'(\d{1,2})(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)(\d{4})\b',
    ];

    DateTime? firstDate;
    DateTime? secondDate;
    final currentDate = DateTime.now();

    for (final pattern in datePatterns) {
      final RegExp regex = RegExp(pattern, caseSensitive: false);
      final matches = regex.allMatches(extractedText);

      for (final match in matches) {
        final dateString = match.group(0)!;
        DateTime? date;

        if (pattern.contains(r'\b(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC) (\d{2})\b')) {
          // Handling MMM YY format
          final monthString = match.group(1)!.toUpperCase();
          final year = int.tryParse(match.group(2)!);
          if (year != null) {
            final month = {
              'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
              'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12
            }[monthString];
            if (month != null) {
              date = DateTime(2000 + year, month, 1);
            }
          }
        } else if (pattern.contains(r'(\d{1,2})(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)(\d{2})\b')) {
          // Handling DDMMMYY format
          final day = int.tryParse(dateString.substring(0, 2));
          final monthString = dateString.substring(2, 5).toUpperCase();
          final year = int.tryParse(dateString.substring(5, 7));
          if (day != null && year != null) {
            final month = {
              'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
              'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12
            }[monthString];
            if (month != null) {
              date = DateTime(2000 + year, month, day);
            }
          }
        } else if (dateString.contains(RegExp(r'\d{2}/\d{4}'))) {
          // Handling MM/YYYY format separately
          final parts = dateString.split('/');
          final month = int.tryParse(parts[0]);
          final year = int.tryParse(parts[1]);
          if (month != null && year != null && year >= 0 && year <= 9999) {
            date = DateTime(year, month);
          }
        } else {
          try {
            date = DateTime.parse(dateString.replaceAll(RegExp(r'[./-]'), '-'));
          } catch (e) {
            continue;
          }
        }

        if (date != null) {
          if (firstDate == null || date.isBefore(firstDate)) {
            firstDate = date;
          } else if (secondDate == null || date.isAfter(secondDate)) {
            secondDate = date;
          }
        }
      }
    }

    if (firstDate != null && secondDate == null) {
      if (firstDate.isBefore(currentDate)) {
        return 'Expired product';
      } else {
        return firstDate.toString().split(' ').first; // Return only the date part in yyyy-MM-dd format
      }
    } else if (secondDate != null && (secondDate.isAfter(currentDate) ||
        secondDate.isAtSameMomentAs(currentDate))) {
      return secondDate.toString().split(' ').first; // Return only the date part in yyyy-MM-dd format
    } else {
      isexpiry=true;
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
//Add the Products into database to Scan
  Future<void> _addProductNamesToDatabase(String productName) async {
    try {
      await conn?.execute(Sql.named(
          'INSERT INTO ai.product_names (prodcts) VALUES (@productName)'),
          parameters: {'productName': productName});
      // Optionally, you can update the _productNames list if needed
      setState(() {
        _productNames.add(productName);
      });
      const snackBar = SnackBar(content: Text(
          'Product name added to database'),
          backgroundColor: Colors.green);
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      // Show a success message or perform any other actions upon successful insertion
    } catch (e) {
      const snackBar = SnackBar(content: Text(
          'Error adding product name to database:'),
          backgroundColor: Colors.red);
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      print('Exception $e');
    }
  }

  Future<void> _retrieveProductNames() async {
    final results = await conn?.execute('SELECT prodcts FROM ai.product_names');
    for (final row in results!) {
      final productName = row[0] as String;
      _productNames.add(productName);
    }
    print(results);
  }
  String _extractProductName(String extractedText) {
    // Normalize and split the extracted text by lines
    List<String> lines = extractedText.split('\n').map((line) => line.trim().toLowerCase()).toList();
    print('Extracted Lines: $lines');

    // Check each combination of consecutive lines for a potential product name
    for (int i = 0; i < lines.length; i++) {
      for (int j = i + 1; j <= lines.length; j++) {
        String combinedLines = lines.sublist(i, j).join(' ');
        print('Combined Lines: $combinedLines');

        // Check the combined lines against the product names list
        for (final productName in _productNames) {
          String normalizedProductName = productName.trim().toLowerCase();
          if (combinedLines.contains(normalizedProductName)) {
            print('Matched Product: $productName');
            return productName;
          }
        }
      }
    }
    print('Product Not Found');
    return '';
  }

  void _storeDetailsInPrefs(String deviceName, String brandName, String username, List<List<dynamic>> userData,String inventoryType,String selectDevice) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('deviceName', deviceName);
    prefs.setString('brandName', brandName);
    prefs.setString('username', username);
    // Convert user data to JSON string and store it
    String userDataJson = userData.map((list) => list.join(',')).join('|');
    prefs.setString('userData', userDataJson);
    prefs.setString('inventoryType', inventoryType);
    prefs.setString('selected_device', selectDevice);
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
              accountName: Text(widget.username),
              // Display username in the header
              accountEmail: null,
              // Set to null or provide user's email if available
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
                  MaterialPageRoute(builder: (context) => EditDevicePage(
                    userData: widget.userData,
                  )), // Navigate to DeviceEditingPage
                );
              },
            ),
            ListTile(
              title: const Text('Add Device'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddDevicePage(
                    userData: widget.userData,
                  )), // Navigate to AddDevicePage
                );
              },
            ),
            ListTile(
              title: const Text('Log Out'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfileDetails(
                    userData: widget.userData,
                  )), // Navigate to AddDevicePage
                );
              },
            ),
            // Add more ListTile widgets for other options if needed
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                  icon: const Icon(Icons.timer),
                  onPressed: () {
                    _timerController.text = _timerSeconds.toString();
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Set Timer (seconds)'),
                          content: TextField(
                            controller: _timerController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Timer duration',
                            ),
                          ),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () {
                                final userInput = _timerController.text;
                                setState(() {
                                  _timerSeconds = userInput.isNotEmpty
                                      ? int.parse(userInput)
                                      : 10;
                                    _captureTimer?.cancel(); // Cancel the existing timer
                                  _startTimer();
                                });
                                Navigator.of(context).pop();
                              },
                              child: const Text('Set'),
                            ),
                          ],
                        );
                      },
                    );
                  },
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
              ],
            ),
           const SizedBox(height: 20),
            if (_filteredProducts.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredProducts.length,
                itemBuilder: (BuildContext context, int index) {
                  return GestureDetector(
                    onTap: () => _onProductTap(_filteredProducts[index]),
                    child: ListTile(
                      title: Text(_filteredProducts[index]),
                    ),
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                height: 500, // Adjust the height as needed
                child: CameraPreview(_controller!),
              ),
            ),
            if (_latestImagePath != null)
              Container(
                padding: const EdgeInsets.all(16.0),
              ),
            if (_filteredImages().isNotEmpty)
              SizedBox(
                height: 100.0,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filteredImages().length,
                  itemBuilder: (context, index) {
                    final imagePath = _filteredImages()[index];
                    return Container(
                      margin: const EdgeInsets.all(4.0),
                      child: Image.file(File(imagePath), height: 80.0),
                    );
                  },
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 Padding(
                    padding: const EdgeInsets.all(5.0),
                    child: ElevatedButton(
                      onPressed: _takePictureAndUpload,
                      child: const Text('Take Photo'),
                    ),
                  ),
                const SizedBox(width: 30),
                if (isexpiry)
                  Padding(
                    padding: const EdgeInsets.all(5.0),
                    child: ElevatedButton(
                      onPressed: () async {
                        final DateTime? datetime = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(3000),
                        );
                        if (datetime != null) {
                          setState(() {
                            _expirydate = datetime.toIso8601String().split('T').first;
                            isexpiry = false; // Hide the button after setting the date
                          });
                        }
                      },
                      child: const Text('Set Date'),
                    ),
                  ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: ElevatedButton(
                    onPressed: _getDetails,
                    child: const Text('All Details'),
                  ),
                ),
                const SizedBox(width: 30),
                Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: ElevatedButton(
                    onPressed: (){
                      _showAddProductNameDialog(context);
                    },
                    child: const Text('Add Products'),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Text('Detected Text: $_detectedText'),
                ),
                Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Text('Ingredients: $_ingrediants'),
                ),
                Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Text('Expiry Date: $_expirydate'),
                ),
                Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Text('Product Name: $product_name'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddProductNameDialog(BuildContext context) async {
    String newProductName = '';
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Product Name'),
          content: TextField(
            onChanged: (value) {
              newProductName = value;
            },
            decoration: const InputDecoration(hintText: 'Enter Product Name'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _addProductNamesToDatabase(newProductName);
                print(newProductName);
                Navigator.of(context).pop();
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
  @override
  void dispose() {
    _captureTimer?.cancel();
    _controller!.dispose();
    super.dispose();
  }
}
