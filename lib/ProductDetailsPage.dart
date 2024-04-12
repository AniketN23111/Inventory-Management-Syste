import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:postgres/postgres.dart';

import 'ProductNamePage.dart';

// ignore: camel_case_types
class productDetailsPage extends StatelessWidget {
  final List<Map<String, dynamic>> productDetailsList;
  final String username;
  final List<List<dynamic>> userData;

  const productDetailsPage({
    Key? key,
    required this.productDetailsList,
    required this.username,
    required this.userData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product Details')),
      body: FutureBuilder<void>(
        future: fetchProductDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            return buildProductDetails(context);
          }
        },
      ),
    );
  }

  Future<void> fetchProductDetails() async {
    // Simulate fetching product details asynchronously
    await Future.delayed(const Duration(seconds: 2));
  }

  Widget buildProductDetails(BuildContext context) {
    int totalInward = productDetailsList
        .map<int>((productDetails) => productDetails['inward'] ?? 0)
        .reduce((sum, inward) => sum + inward);

    int totalOutward = productDetailsList
        .map<int>((productDetails) => productDetails['outward'] ?? 0)
        .reduce((sum, outward) => sum + outward);

    int remaining = totalInward - totalOutward;
    String organizationName = userData[0][2];
    String userName = username;

    // List to store futures of location fetching
    List<Future<String>> locationFutures = [];

    // List to store product names
    List<String> productNames = [];

    // Build location futures for each device concurrently
    for (final productDetails in productDetailsList) {
      String device = productDetails['inward_device'] ??
          productDetails['outward_device'] ?? '';
      locationFutures.add(getLocationByDeviceName(device));
      productNames.add(productDetails['item_name'] ?? '');
    }

    return FutureBuilder<List<String>>(
      future: Future.wait(locationFutures),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    'User Name: $userName',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Organization Name: $organizationName',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('SrNo')),
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Device')),
                      DataColumn(label: Text('Location')),
                      DataColumn(label: Text('Brand')),
                      DataColumn(label: Text('Product')),
                      DataColumn(label: Text('Inward')),
                      DataColumn(label: Text('Outward')),
                    ],
                    rows: buildDataRows(context, snapshot.data!, productNames),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    // Handle onTap event
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => ProductNamePage(productName: productNames[0])));
                  },
                  child: Text(
                    'Remaining Quantity: $remaining',
                    style: const TextStyle(fontSize: 18,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  List<DataRow> buildDataRows(BuildContext context, List<String> locations, List<String> productNames) {
    List<DataRow> rows = [];

    for (int i = 0; i < productDetailsList.length; i++) {
      final productDetails = productDetailsList[i];
      String productName = productNames[i];
      String brand = productDetails['brandname'] ?? '';
      int inward = productDetails['inward'] ?? 0;
      int outward = productDetails['outward'] ?? 0;
      String device = productDetails['inward_device'] ??
          productDetails['outward_device'] ?? '';
      String location = locations[i]; // Get location for the current device
      DateTime date = productDetails['date'] ?? DateTime.now();

      rows.add(
        DataRow(cells: [
          DataCell(Text((i + 1).toString())),
          DataCell(Text(DateFormat('yyyy-MM-dd').format(date))),
          DataCell(Text(device)),
          DataCell(Text(location)), // Display location
          DataCell(Text(brand)),
          DataCell(Text(productName)),
          DataCell(Text(inward.toString())),
          DataCell(Text(outward.toString())),
        ]),
      );
    }
    return rows;
  }

  Future<String> getLocationByDeviceName(String deviceName) async {
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
        Sql.named('SELECT device_location FROM ai.device_user WHERE device_name = @deviceName'),
        parameters: {'deviceName': deviceName},
      );

      await connection.close();

      if (results.isNotEmpty) {
        // Extract the location from the query results
        final location = results.first.first;
        return location.toString();
      } else {
        return 'Location not found';
      }
    } catch (e) {
      return 'Error fetching location';
    }
  }
}