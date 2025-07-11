import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/entry.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Entry> allEntries = [];
  final _db = FirebaseFirestore.instance;
  String searchQuery = '';
  String selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _fetchAllEntries();
  }

  Future<void> _fetchAllEntries() async {
    final snapshot = await _db.collection('tyre_entries').get();
    final list = snapshot.docs.map((doc) => Entry.fromMap(doc.id, doc.data())).toList();

    setState(() {
      allEntries = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = allEntries.where((entry) {
      final matchDate = entry.date == selectedDate;
      final matchSearch = searchQuery.isEmpty || entry.matches(searchQuery);
      return matchDate && matchSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("History"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(labelText: "Search"),
                    onChanged: (value) => setState(() => searchQuery = value),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.parse(selectedDate),
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => selectedDate = DateFormat('yyyy-MM-dd').format(picked));
                    }
                  },
                  child: const Text("Pick Date"),
                )
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: filtered.map((entry) {
                return ListTile(
                  title: Text("${entry.brand} | ${entry.size} ${entry.model}"),
                  subtitle: Text("${entry.person} | ${entry.type} | ${entry.date} ${entry.time} | Qty: ${entry.quantity}"),
                );
              }).toList(),
            ),
          )
        ],
      ),
    );
  }
}
