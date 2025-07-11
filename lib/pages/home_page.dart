// lib/home.dart

import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'entry_dialog.dart';
import 'package:tyre_daybook/models/entry.dart'; 

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime selectedDate = DateTime.now();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<Entry> inEntries = [];
  List<Entry> outEntries = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchEntries();
  }

  void _fetchEntries() {
    final String dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    _db.collection('tyre_entries').where('date', isEqualTo: dateStr).snapshots().listen((snapshot) {
      List<Entry> inList = [];
      List<Entry> outList = [];

      for (var doc in snapshot.docs) {
        final entry = Entry.fromMap(doc.id ,doc.data());
        if (searchQuery.isEmpty || entry.matches(searchQuery)) {
          if (entry.type == 'IN') {
            inList.add(entry);
          } else {
            outList.add(entry);
          }
        }
      }

      setState(() {
        inEntries = inList;
        outEntries = outList;
      });
    });
  }

  void _changeDay(int days) {
    setState(() {
      selectedDate = selectedDate.add(Duration(days: days));
    });
    _fetchEntries();
  }

  int _getTotal(List<Entry> list) {
    return list.fold(0, (sum, e) => sum + e.quantity);
  }

  @override
  Widget build(BuildContext context) {
    String dateStr = DateFormat('EEEE, dd MMMM yyyy').format(selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: Text('Tyre Daybook – $dateStr'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => html.window.print(),
            tooltip: "Print today's data",
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEntryDialog(),
        child: const Icon(Icons.add),
        tooltip: "Add Tyre Entry",
      ),
      body: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton(onPressed: () => _changeDay(-1), child: const Text("⬅️ Yesterday")),
            TextButton(onPressed: () {
              setState(() => selectedDate = DateTime.now());
              _fetchEntries();
            }, child: const Text("📅 Today")),
            TextButton(onPressed: () => _changeDay(1), child: const Text("➡️ Tomorrow")),
          ]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: TextField(
              decoration: const InputDecoration(labelText: "Search by any field", prefixIcon: Icon(Icons.search)),
              onChanged: (value) {
                setState(() => searchQuery = value.toLowerCase());
                _fetchEntries();
              },
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildTable("🟢 IN", inEntries)),
                Expanded(child: _buildTable("🔴 OUT", outEntries)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(String title, List<Entry> entries) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text("$title (Total: ${_getTotal(entries)})", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
          Expanded(
            child: entries.isEmpty
                ? const Center(child: Text("No entries"))
                : ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (_, index) {
                      final e = entries[index];
                      return ListTile(
                        title: Text("${e.brand} – ${e.size} ${e.model}"),
                        subtitle: Text(
                          "${e.quantity} pcs | ${e.type == 'IN' ? 'Supplier' : 'Buyer'}: ${e.person}\nDate: ${e.date} | Time: ${e.time}",
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showEntryDialog() {
    showDialog(
      context: context,
      builder: (_) => EntryDialog(onSaved: _fetchEntries),
    );
  }
}
