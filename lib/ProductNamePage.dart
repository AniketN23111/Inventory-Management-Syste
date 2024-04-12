import 'package:flutter/material.dart';
class ProductNamePage extends StatelessWidget {
  final String productName;

  const ProductNamePage({Key? key, required this.productName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(productName)),
      body: Center(
        child: Text(
          'This page displays details about the product: $productName',
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}