import 'package:flutter/material.dart';

class ProductDetailsPage extends StatelessWidget {
  final Map<String, dynamic> productDetails;
  final String username;

  ProductDetailsPage({required this.productDetails, required this.username});

  @override
  Widget build(BuildContext context) {
    // Check if the product belongs to the current user
    if (productDetails['username'] != username) {
      return Scaffold(
        appBar: AppBar(title: Text('Product Details')),
        body: Center(
          child: Text('You are not authorized to view this product details.'),
        ),
      );
    }

    String expiryDate = productDetails['expiry_date'] ?? '';
    String productName = productDetails['item_name'] ?? '';
    String brand = productDetails['brandname'] ?? '';
    int inward = productDetails['inward'] ?? 0;
    int outward = productDetails['outward'] ?? 0;
    String inwardDevice = productDetails['inward_device'] ?? '';
    String outwardDevice = productDetails['outward_device'] ?? '';
    String date = productDetails['date'] ?? '';

    // Determine if inward device is present
    bool isInwardDevicePresent = inwardDevice.isNotEmpty;

    // Determine if outward device is present
    bool isOutwardDevicePresent = outwardDevice.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text('Product Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expiry Date: $expiryDate',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Product Name: $productName',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Table(
              border: TableBorder.all(),
              children: [
                TableRow(
                  children: [
                    TableCell(child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('SrNo'),
                    )),
                    TableCell(child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('Date'),
                    )),
                    TableCell(child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('Device'),
                    )),
                    TableCell(child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('Brand'),
                    )),
                    TableCell(child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('Product'),
                    )),
                    TableCell(child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('Inward'),
                    )),
                    TableCell(child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('Outward'),
                    )),
                  ],
                ),
                if (isInwardDevicePresent) // Add row for inward device
                  TableRow(
                    children: [
                      TableCell(child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text('1'), // Assuming this is for the first row
                      )),
                      TableCell(child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(date),
                      )),
                      TableCell(child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(inwardDevice),
                      )),
                      TableCell(child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(brand),
                      )),
                      TableCell(child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(productName),
                      )),
                      TableCell(child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(inward.toString()),
                      )),
                      TableCell(child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(''),
                      )),
                    ],
                  ),
                if (isOutwardDevicePresent) // Add row for outward device
                  TableRow(
                    children: [
                      TableCell(child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text('2'), // Assuming this is for the second row
                      )),
                      TableCell(child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(outwardDevice),
                      )),
                      TableCell(child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(brand),
                      )),
                      TableCell(child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(productName),
                      )),
                      TableCell(child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(''),
                      )),
                      TableCell(child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(outward.toString()),
                      )),
                    ],
                  ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Remaining Quantity: ${inward - outward}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
