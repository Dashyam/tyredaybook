import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tyre_daybook/models/entry.dart';

class StockReportPage extends StatefulWidget {
  const StockReportPage({super.key});

  @override
  State<StockReportPage> createState() => _StockReportPageState();
}

class _StockReportPageState extends State<StockReportPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DateTime fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime toDate = DateTime.now();
  String searchQuery = '';
  String selectedType = 'IN';

  List<Entry> entries = [];
  int totalQuantity = 0;

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? fromDate : toDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          fromDate = picked;
        } else {
          toDate = picked;
        }
      });
    }
  }

  Future<void> _loadReport() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final fromStr = DateFormat('yyyy-MM-dd').format(fromDate);
    final toStr = DateFormat('yyyy-MM-dd').format(toDate);
    final keywords = searchQuery.toLowerCase().split(' ');

    final querySnapshot = await _db
        .collection('tyre_entries')
        .where('uid', isEqualTo: uid)
        .where('date', isGreaterThanOrEqualTo: fromStr)
        .where('date', isLessThanOrEqualTo: toStr)
        .get();

    final results = querySnapshot.docs
        .map((doc) => Entry.fromMap(doc.id, doc.data()))
        .where((e) =>
            e.type == selectedType &&
            (searchQuery.isEmpty ||
                keywords.every((kw) =>
                    e.brand.toLowerCase().contains(kw) ||
                    e.model.toLowerCase().contains(kw) ||
                    e.size.toLowerCase().contains(kw) ||
                    e.person.toLowerCase().contains(kw) ||
                    e.date.toLowerCase().contains(kw) ||
                    e.time.toLowerCase().contains(kw) ||
                    e.type.toLowerCase().contains(kw))))
        .toList();

    final quantitySum = results.fold(0, (sum, e) => sum + e.quantity);

    setState(() {
      entries = results;
      totalQuantity = quantitySum;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fromStr = DateFormat('dd MMM yyyy').format(fromDate);
    final toStr = DateFormat('dd MMM yyyy').format(toDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Stock Report"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: "Search by any keyword",
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => searchQuery = value),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text("From: $fromStr"),
                    onPressed: () => _selectDate(context, true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    label: Text("To: $toStr"),
                    onPressed: () => _selectDate(context, false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => selectedType = 'IN');
                      _loadReport();
                    },
                    child: const Text("Stock IN Report"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => selectedType = 'OUT');
                      _loadReport();
                    },
                    child: const Text("Stock OUT Report"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (entries.isNotEmpty)
              Card(
                color: Colors.grey[200],
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("🧾 Total Entries: ${entries.length}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text("📦 Total Quantity: $totalQuantity", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: entries.isEmpty
                  ? const Center(child: Text("No entries found."))
                  : ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (_, index) {
                        final e = entries[index];
                        return ListTile(
                          title: Text("${e.brand} – ${e.size} ${e.model}"),
                          subtitle: Text(
                            "Qty: ${e.quantity} | Date: ${e.date} | "
                            "${e.type == 'IN' ? 'Supplier' : 'Buyer'}: ${e.person}",
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
