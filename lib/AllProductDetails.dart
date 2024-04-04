import 'package:flutter/material.dart';

class AllProductDetails extends StatefulWidget {
  final List<Map<String, dynamic>> productDetailsList;

  const AllProductDetails({
    Key? key,
    required this.productDetailsList,
  }) : super(key: key);

  @override
  _AllProductDetailsState createState() => _AllProductDetailsState();
}

class _AllProductDetailsState extends State<AllProductDetails> {
  late List<Map<String, dynamic>> _filteredProductDetailsList;
  TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'Alphabetical'; // Default filter

  @override
  void initState() {
    super.initState();
    _filteredProductDetailsList = widget.productDetailsList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('All Product Details'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                _filterList(value);
              },
              decoration: InputDecoration(
                labelText: 'Search',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButton<String>(
              value: _selectedFilter,
              onChanged: (String? value) {
                setState(() {
                  _selectedFilter = value!;
                  _applyFilter();
                });
              },
              items: <String>['Alphabetical', 'Date'].map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columns: [
                    DataColumn(label: Text('Product Name')),
                    DataColumn(label: Text('Device')),
                    DataColumn(label: Text('Expiry Date')),
                    DataColumn(label: Text('Brand')),
                    DataColumn(label: Text('Inward')),
                    DataColumn(label: Text('Outward')),
                  ],
                  rows: _filteredProductDetailsList.map((productDetails) {
                    String device = '';
                    if (productDetails['inward_device'] != null) {
                      device = productDetails['inward_device'];
                    } else if (productDetails['outward_device'] != null) {
                      device = productDetails['outward_device'];
                    }
                    return DataRow(cells: [
                      DataCell(Text(productDetails['item_name'] ?? '')),
                      DataCell(Text(device)),
                      DataCell(Text(productDetails['expiry_date'] ?? '')),
                      DataCell(Text(productDetails['brandname'] ?? '')),
                      DataCell(Text('${productDetails['inward'] ?? 0}')),
                      DataCell(Text('${productDetails['outward'] ?? 0}')),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _filterList(String searchText) {
    setState(() {
      _filteredProductDetailsList = widget.productDetailsList.where((productDetails) {
        final itemName = productDetails['item_name'].toString().toLowerCase();
        final brandName = productDetails['brandname'].toString().toLowerCase();
        final device = productDetails['inward_device'] != null ? productDetails['inward_device'].toString().toLowerCase() : '';
        final outwardDevice = productDetails['outward_device'] != null ? productDetails['outward_device'].toString().toLowerCase() : '';

        return itemName.contains(searchText.toLowerCase()) ||
            brandName.contains(searchText.toLowerCase()) ||
            device.contains(searchText.toLowerCase()) ||
            outwardDevice.contains(searchText.toLowerCase());
      }).toList();
    });
  }


  void _applyFilter() {
    setState(() {
      if (_selectedFilter == 'Alphabetical') {
        _filteredProductDetailsList.sort((a, b) => (a['item_name'] as String).compareTo(b['item_name']));
      } else if (_selectedFilter == 'Date') {
        _filteredProductDetailsList.sort((a, b) => (a['expiry_date'] as String).compareTo(b['expiry_date']));
      }
    });
  }
}
