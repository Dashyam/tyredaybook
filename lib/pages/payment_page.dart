
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tyre_daybook/pages/person_history_page.dart';
import 'package:tyre_daybook/widgets/payment_dialog.dart';
import '../models/payment_entry.dart';
import 'home_page.dart';

class PaymentsHomePage extends StatefulWidget {
  const PaymentsHomePage({super.key});

  @override
  State<PaymentsHomePage> createState() => _PaymentsHomePageState();
}

class _PaymentsHomePageState extends State<PaymentsHomePage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  List<PaymentEntry> allEntries = [];
  String searchQuery = '';
  DateTime? fromDate;
  DateTime? toDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    fromDate = DateTime(now.year, now.month - 1, now.day);
    toDate = now;
    _listenToPayments();
  }

  void _listenToPayments() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    Query query = _db.collection('payments').where('uid', isEqualTo: uid);

    if (fromDate != null && toDate != null) {
      final fromStr = DateFormat('yyyy-MM-dd').format(fromDate!);
      final toStr = DateFormat('yyyy-MM-dd').format(toDate!);
      query = query
          .where('date', isGreaterThanOrEqualTo: fromStr)
          .where('date', isLessThanOrEqualTo: toStr);
    }

    query.snapshots().listen((snapshot) {
      List<PaymentEntry> all = snapshot.docs
          .map(
            (doc) => PaymentEntry.fromMap(
              doc.id,
              doc.data() as Map<String, dynamic>,
            ),
          )
          .toList();

      setState(() => allEntries = all);
    });
  }

  Future<void> _selectDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom
          ? (fromDate ?? DateTime.now())
          : (toDate ?? DateTime.now()),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          fromDate = picked;
        } else {
          toDate = picked;
        }
      });
      _listenToPayments();
    }
  }

  void _goToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => PaymentDialog(onSaved: _listenToPayments),
    );
  }

  void _goToPersonHistory(String person) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PersonPaymentHistoryPage(personName: person),
      ),
    );
  }

  Widget _buildGroupedList() {
    final Map<String, List<PaymentEntry>> groups = {};
    for (var entry in allEntries) {
      groups.putIfAbsent(entry.normalizedName, () => []).add(entry);
    }

    final filtered = groups.entries.where((group) {
      final person = group.value.first.person.toLowerCase();
      final notes = group.value.map((e) => e.notes.toLowerCase()).join(' ');
      final match = searchQuery.toLowerCase();
      return person.contains(match) || notes.contains(match);
    }).toList();

    final toReceiveWidgets = <Widget>[];
    final toPayWidgets = <Widget>[];
    int totalReceive = 0;
    int totalPay = 0;

    for (var group in filtered) {
      final entries = group.value;
      final name = entries.first.person;
      final receive = entries
          .where((e) => e.type == 'to_receive')
          .fold(0, (sum, e) => sum + e.amount);
      final pay = entries
          .where((e) => e.type == 'to_pay')
          .fold(0, (sum, e) => sum + e.amount);
      final balance = receive - pay;
      final allSettled = entries.every((e) => e.isSettled);
      final isSettled = balance == 0 && allSettled;

      final tile = ListTile(
        title: Text(name),
        subtitle: Text("Balance: ₹$balance  ${isSettled ? '(Settled)' : ''}"),
        onTap: () => _goToPersonHistory(name),
      );

      if (balance >= 0) {
        totalReceive += balance;
        toReceiveWidgets.add(tile);
      } else {
        totalPay += -balance;
        toPayWidgets.add(tile);
      }
    }

    return Expanded(
      child: Row(
        children: [
          Expanded(
            child: Card(
              margin: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Text(
                    "🟢 To Receive (₹$totalReceive)",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  Expanded(
                    child: toReceiveWidgets.isEmpty
                        ? const Center(child: Text("No entries"))
                        : ListView(children: toReceiveWidgets),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Card(
              margin: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Text(
                    "🔴 To Pay (₹$totalPay)",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  Expanded(
                    child: toPayWidgets.isEmpty
                        ? const Center(child: Text("No entries"))
                        : ListView(children: toPayWidgets),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = _auth.currentUser?.email ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.directions_car),
            onPressed: _goToHome,
            tooltip: 'Go to Tyre Home Page',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _auth.signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      "From: ${fromDate != null ? DateFormat('dd MMM').format(fromDate!) : 'Select'}",
                    ),
                    onPressed: () => _selectDate(true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      "To: ${toDate != null ? DateFormat('dd MMM').format(toDate!) : 'Select'}",
                    ),
                    onPressed: () => _selectDate(false),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: "Search (name, amount, date, notes)",
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (val) {
                setState(() => searchQuery = val);
              },
            ),
          ),
          _buildGroupedList(),
        ],
      ),
    );
  }
}
