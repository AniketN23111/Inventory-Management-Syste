import 'package:flutter/material.dart';

// ignore: camel_case_types
class inventoryDetailsPage extends StatelessWidget {
  final List<dynamic>? inventoryData;

  const inventoryDetailsPage({Key? key, required this.inventoryData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Details'),
      ),
      body: ListView.builder(
        itemCount: inventoryData?.length ?? 0,
        itemBuilder: (context, index) {
          final item = inventoryData![index];

          // Check if item is null or not in the expected format
          if (item == null || item is! Map<String, dynamic>) {
            // Handle invalid or unexpected data
            return const ListTile(
              title: Text('Invalid Data'),
            );
          }

          // Access item properties safely
          final itemName = item['item_name'];
          final inward = item['inward'];
          final outward = item['outward'];

          // Check if itemName, inward, and outward are null or not in the expected format
          if (itemName == null || inward == null || outward == null) {
            // Handle invalid or unexpected data
            return const ListTile(
              title: Text('Invalid Data'),
            );
          }
          return null;

          // Navigate to ProductDetailsPage when tapping on ListTile
        /*  return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailsPage(productDetails: item),
                ),
              );
            },
            child: ListTile(
              title: Text(itemName),
              subtitle: Text('Inward: $inward, Outward: $outward'),
            ),
          );*/
        },
      ),
    );
  }
}
