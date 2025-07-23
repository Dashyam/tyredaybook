import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'edit_stock_dialog.dart';
import 'tyre_stock_detail_page.dart';

class StockMasterPage extends StatefulWidget {
  const StockMasterPage({super.key});

  @override
  State<StockMasterPage> createState() => _StockMasterPageState();
}

class _StockMasterPageState extends State<StockMasterPage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  List<Map<String, dynamic>> stockItems = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _listenToStockItems();
  }

  void _listenToStockItems() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _db
        .collection('stock_items')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.docs.map((doc) => doc.data()).toList();
      setState(() => stockItems = data);
    });
  }

  List<Map<String, dynamic>> get filteredItems {
    if (searchQuery.isEmpty) return stockItems;
    return stockItems.where((item) {
      final query = searchQuery.toLowerCase();
      return (item['brand']?.toLowerCase().contains(query) ?? false) ||
          (item['size']?.toLowerCase().contains(query) ?? false) ||
          (item['model']?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  void _editStock(Map<String, dynamic> item) async {
    await showDialog(
      context: context,
      builder: (_) => EditStockDialog(item: item),
    );
  }

  void _openDetailPage(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TyreStockDetailPage(
          brand: item['brand'],
          size: item['size'],
          model: item['model'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Stock Master"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by brand, size, or model',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (val) => setState(() => searchQuery = val),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredItems.length,
              itemBuilder: (_, index) {
                final item = filteredItems[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: ListTile(
                    title: Text(
                        "${item['brand']} ${item['size']} ${item['model']}".toUpperCase()),
                    subtitle: Text("Quantity: ${item['quantity']}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editStock(item),
                    ),
                    onTap: () => _openDetailPage(item),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
