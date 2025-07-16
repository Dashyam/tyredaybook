import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'entry_dialog.dart';
import 'stock_report_page.dart';
import 'package:tyre_daybook/models/entry.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DateTime selectedDate = DateTime.now();
  DateTime? fromDate;
  DateTime? toDate;

  List<Entry> inEntries = [];
  List<Entry> outEntries = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now(); // Ensure today is selected
    _fetchEntries();
  }

  void _fetchEntries() {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    final isRangeSelected = fromDate != null && toDate != null;
    final from = isRangeSelected ? fromDate! : selectedDate;
    final to = isRangeSelected ? toDate! : selectedDate;

    final fromStr = DateFormat('yyyy-MM-dd').format(from);
    final toStr = DateFormat('yyyy-MM-dd').format(to);

    Query query = _db
        .collection('tyre_entries')
        .where('uid', isEqualTo: currentUid);

    if (isRangeSelected) {
      query = query
          .where('date', isGreaterThanOrEqualTo: fromStr)
          .where('date', isLessThanOrEqualTo: toStr);
    } else {
      query = query.where('date', isEqualTo: fromStr);
    }

    query.snapshots().listen((snapshot) {
      List<Entry> inList = [];
      List<Entry> outList = [];

      final keywords = searchQuery.toLowerCase().split(' ');

      for (var doc in snapshot.docs) {
        final entry = Entry.fromMap(doc.id, doc.data() as Map<String, dynamic>);

        if (searchQuery.isEmpty ||
            keywords.every(
              (kw) =>
                  entry.brand.toLowerCase().contains(kw) ||
                  entry.model.toLowerCase().contains(kw) ||
                  entry.size.toLowerCase().contains(kw) ||
                  entry.person.toLowerCase().contains(kw) ||
                  entry.date.toLowerCase().contains(kw) ||
                  entry.time.toLowerCase().contains(kw) ||
                  entry.type.toLowerCase().contains(kw),
            )) {
          if (entry.type == 'IN') {
            inList.add(entry);
          } else {
            outList.add(entry);
          }
        }
      }

      if (mounted) {
        setState(() {
          inEntries = inList;
          outEntries = outList;
        });
      }
    });
  }

  Future<void> _selectDateRange(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom
          ? (fromDate ?? selectedDate)
          : (toDate ?? selectedDate),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          fromDate = picked;
          if (toDate != null && picked.isAfter(toDate!)) {
            toDate = picked;
          }
        } else {
          toDate = picked;
          if (fromDate != null && picked.isBefore(fromDate!)) {
            fromDate = picked;
          }
        }
        _fetchEntries();
      });
    }
  }

  Future<void> _selectSingleDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
        fromDate = null;
        toDate = null;
      });
      _fetchEntries();
    }
  }

  void _changeDay(int days) {
    setState(() {
      selectedDate = selectedDate.add(Duration(days: days));
      fromDate = null;
      toDate = null;
    });
    _fetchEntries();
  }

  int _getTotal(List<Entry> list) {
    return list.fold(0, (sum, e) => sum + e.quantity);
  }

  Future<void> _confirmLogout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (result == true) {
      await _auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = _auth.currentUser?.email ?? 'No user';
    final isRange = fromDate != null && toDate != null;
    final titleDate = isRange
        ? "From ${DateFormat('dd MMM yyyy').format(fromDate!)} to ${DateFormat('dd MMM yyyy').format(toDate!)}"
        : DateFormat('EEEE, dd MMMM yyyy').format(selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(child: Text('Tyre Daybook – $titleDate')),
            IconButton(
              icon: const Icon(Icons.calendar_today),
              tooltip: "Pick a date",
              onPressed: _selectSingleDate,
            ),
            IconButton(
              icon: const Icon(Icons.payments),
              tooltip: "Go to Payments",
              onPressed: () {
                Navigator.pushNamed(context, '/payments');
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _confirmLogout,
              tooltip: "Logout",
            ),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text("Logged in user"),
              accountEmail: Text(userEmail),
              currentAccountPicture: const CircleAvatar(
                child: Icon(Icons.person),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.assessment),
              title: const Text("Stock Report"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StockReportPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.payments),
              title: const Text("Payments"),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/payments');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: _confirmLogout,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showEntryDialog,
        child: const Icon(Icons.add),
        tooltip: "Add Tyre Entry",
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => _changeDay(-1),
                child: const Text("⬅️ Previous"),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    selectedDate = DateTime.now();
                    fromDate = null;
                    toDate = null;
                  });
                  _fetchEntries();
                },
                child: const Text("📅 Today"),
              ),
              TextButton(
                onPressed: () => _changeDay(1),
                child: const Text("➡️ Next"),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      "From: ${fromDate != null ? DateFormat('dd MMM').format(fromDate!) : 'Select'}",
                    ),
                    onPressed: () => _selectDateRange(true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      "To: ${toDate != null ? DateFormat('dd MMM').format(toDate!) : 'Select'}",
                    ),
                    onPressed: () => _selectDateRange(false),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: "Search by any field",
                prefixIcon: Icon(Icons.search),
              ),
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
          Text(
            "$title (Total: ${_getTotal(entries)})",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
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
