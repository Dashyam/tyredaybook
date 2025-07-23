import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TyreStockDetailPage extends StatefulWidget {
  final String brand;
  final String size;
  final String model;

  const TyreStockDetailPage({
    super.key,
    required this.brand,
    required this.size,
    required this.model,
  });

  @override
  State<TyreStockDetailPage> createState() => _TyreStockDetailPageState();
}

class _TyreStockDetailPageState extends State<TyreStockDetailPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  int currentBalance = 0;
  List<Map<String, dynamic>> inEntries = [];
  List<Map<String, dynamic>> outEntries = [];

  @override
  void initState() {
    super.initState();
    _loadStockData();
  }

  void _loadStockData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final safeSize = widget.size.replaceAll('/', '_');
    final docId = "${widget.brand}|$safeSize|${widget.model}";

    // Fetch current balance
    final doc = await _db.collection('stock_items').doc(docId).get();
    if (doc.exists) {
      setState(() {
        currentBalance = doc.data()?['quantity'] ?? 0;
      });
    }

    // Fetch IN entries
    final inSnapshot = await _db
        .collection('stock_entries')
        .where('uid', isEqualTo: uid)
        .where('type', isEqualTo: 'in')
        .where('brand', isEqualTo: widget.brand)
        .where('size', isEqualTo: widget.size)
        .where('model', isEqualTo: widget.model)
        .orderBy('date', descending: true)
        .get();

    // Fetch OUT entries
    final outSnapshot = await _db
        .collection('stock_entries')
        .where('uid', isEqualTo: uid)
        .where('type', isEqualTo: 'out')
        .where('brand', isEqualTo: widget.brand)
        .where('size', isEqualTo: widget.size)
        .where('model', isEqualTo: widget.model)
        .orderBy('date', descending: true)
        .get();

    setState(() {
      inEntries = inSnapshot.docs.map((doc) => doc.data()).toList();
      outEntries = outSnapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  String _formatDate(Timestamp timestamp) {
    final dt = timestamp.toDate();
    return DateFormat('dd-MM-yyyy').format(dt);
  }

  Widget _buildEntryCard(Map<String, dynamic> entry, bool isIn) {
    return ListTile(
      title: Text(
        "${isIn ? 'Supplier' : 'Buyer'}: ${entry[isIn ? 'supplier' : 'buyer']}",
      ),
      subtitle: Text("Date: ${_formatDate(entry['date'])}"),
      trailing: Text("Qty: ${entry['quantity']}"),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = "${widget.brand} ${widget.size} ${widget.model}"
        .toUpperCase();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Current Balance: $currentBalance",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              "Stock In History",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            ...inEntries.map((e) => _buildEntryCard(e, true)).toList(),
            const SizedBox(height: 16),
            const Text(
              "Stock Out History",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            ...outEntries.map((e) => _buildEntryCard(e, false)).toList(),
          ],
        ),
      ),
    );
  }
}
