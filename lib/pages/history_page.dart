import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/entry.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  List<Entry> allEntries = [];
  String searchQuery = '';
  String selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _fetchAllEntries();
  }

  Future<void> _fetchAllEntries() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await _db
        .collection('tyre_entries')
        .where('uid', isEqualTo: uid)
        .get();

    final list = snapshot.docs.map((doc) => Entry.fromMap(doc.id, doc.data())).toList();

    setState(() {
      allEntries = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    final keywords = searchQuery.toLowerCase().split(' ');

    final filtered = allEntries.where((entry) {
      final matchDate = entry.date == selectedDate;
      final matchSearch = keywords.every((kw) =>
          entry.brand.toLowerCase().contains(kw) ||
          entry.size.toLowerCase().contains(kw) ||
          entry.model.toLowerCase().contains(kw) ||
          entry.person.toLowerCase().contains(kw) ||
          entry.type.toLowerCase().contains(kw) ||
          entry.date.contains(kw) ||
          entry.time.contains(kw));
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
                  subtitle: Text(
                    "${entry.person} | ${entry.type} | ${entry.date} ${entry.time} | Qty: ${entry.quantity}",
                  ),
                );
              }).toList(),
            ),
          )
        ],
      ),
    );
  }
}
