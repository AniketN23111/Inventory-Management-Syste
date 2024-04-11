import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

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
  TextEditingController _startDateController = TextEditingController();
  TextEditingController _endDateController = TextEditingController();
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
            child: Row(
              children: [
                Expanded(
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
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    _filterByDate();
                  },
                  child: Text('Filter by Date'),
                ),
              ],
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
              items: <String>['Alphabetical', 'Date'].map<
                  DropdownMenuItem<String>>((String value) {
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
                    DataColumn(label: Text('Date')),
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
                      DataCell(Text(DateFormat('yyyy-MM-dd').format(
                          productDetails['date']))),
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
          SizedBox(height: 20),
          _buildBarGraph(),
        ],
      ),
    );
  }

  Widget _buildBarGraph() {
    // Create a map to store aggregated totals for each month
    Map<String, int> inwardTotals = {};
    Map<String, int> outwardTotals = {};

    // Aggregate inward and outward quantities for each month
    _filteredProductDetailsList.forEach((productDetails) {
      String month = DateFormat('yyyy-MM').format(productDetails['date']);
      int inward = productDetails['inward'] ?? 0;
      int outward = productDetails['outward'] ?? 0;

      // Increment the inward and outward totals for the month
      inwardTotals.update(month, (value) => value + inward, ifAbsent: () => inward);
      outwardTotals.update(month, (value) => value + outward, ifAbsent: () => outward);
    });

    // Prepare the data for the bar graph
    List<String> months = inwardTotals.keys.toList();

    return Container(
      height: 300,
      padding: EdgeInsets.all(10),
      child: SfCartesianChart(
        primaryXAxis: CategoryAxis(),
        primaryYAxis: NumericAxis(
          title: AxisTitle(text: 'Quantity'),
        ),
        series: <CartesianSeries>[
          ColumnSeries<String, String>(
            dataSource: months,
            xValueMapper: (String month, _) => month,
            yValueMapper: (String month, _) => inwardTotals[month]!, // Use inward totals as y-values
            name: 'Inward',
          ),
          ColumnSeries<String, String>(
            dataSource: months,
            xValueMapper: (String month, _) => month,
            yValueMapper: (String month, _) => outwardTotals[month]!, // Use outward totals as y-values
            name: 'Outward',
          ),
        ],
      ),
    );
  }

  void _filterList(String searchText) {
    setState(() {
      _filteredProductDetailsList =
          widget.productDetailsList.where((productDetails) {
            final itemName = productDetails['item_name']
                .toString()
                .toLowerCase();
            final brandName = productDetails['brandname']
                .toString()
                .toLowerCase();
            final device = productDetails['inward_device'] != null
                ? productDetails['inward_device'].toString().toLowerCase()
                : '';
            final outwardDevice = productDetails['outward_device'] != null
                ? productDetails['outward_device'].toString().toLowerCase()
                : '';

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
        _filteredProductDetailsList.sort((a, b) =>
            (a['item_name'] as String).compareTo(b['item_name']));
      } else if (_selectedFilter == 'Date') {
        _filteredProductDetailsList.sort((a, b) =>
            (a['expiry_date'] as String).compareTo(b['expiry_date']));
      }
    });
  }

  void _filterByDate() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Filter by Date'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _startDateController,
                decoration: InputDecoration(labelText: 'Start Date'),
                keyboardType: TextInputType.datetime,
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                    initialDatePickerMode: DatePickerMode.day,
                  );
                  if (pickedDate != null) {
                    setState(() {
                      _startDateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
                    });
                  }
                },
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _endDateController,
                decoration: InputDecoration(labelText: 'End Date'),
                keyboardType: TextInputType.datetime,
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                    initialDatePickerMode: DatePickerMode.day,
                  );
                  if (pickedDate != null) {
                    setState(() {
                      _endDateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _applyDateFilter();
                Navigator.of(context).pop();
              },
              child: Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  void _applyDateFilter() {
    DateTime? startDate = DateTime.tryParse(_startDateController.text);
    DateTime? endDate = DateTime.tryParse(_endDateController.text);

    setState(() {
      if (startDate != null && endDate != null) {
        _filteredProductDetailsList = widget.productDetailsList.where((productDetails) {
          DateTime? date = productDetails['date']; // Assuming 'date' is already a DateTime object
          return date != null && date.isAfter(startDate) && date.isBefore(endDate);
        }).toList();
      }
    });
  }
}