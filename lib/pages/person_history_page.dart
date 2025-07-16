import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tyre_daybook/widgets/payment_dialog.dart';
import '../models/payment_entry.dart';

class PersonPaymentHistoryPage extends StatefulWidget {
  final String personName;

  const PersonPaymentHistoryPage({super.key, required this.personName});

  @override
  State<PersonPaymentHistoryPage> createState() =>
      _PersonPaymentHistoryPageState();
}

class _PersonPaymentHistoryPageState extends State<PersonPaymentHistoryPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DateTime? fromDate;
  DateTime? toDate;
  List<PaymentEntry> allEntries = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    fromDate = DateTime(now.year, now.month - 1, now.day);
    toDate = now;
    _fetchPayments();
  }

  Future<void> _fetchPayments() async {
    setState(() => isLoading = true);
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final fromStr = DateFormat('yyyy-MM-dd').format(fromDate!);
    final toStr = DateFormat('yyyy-MM-dd').format(toDate!);

    final snapshot = await _db
        .collection('payments')
        .where('uid', isEqualTo: uid)
        .where('normalizedName', isEqualTo: widget.personName.toUpperCase())
        .where('date', isGreaterThanOrEqualTo: fromStr)
        .where('date', isLessThanOrEqualTo: toStr)
        .get();

    final list = snapshot.docs
        .map((doc) => PaymentEntry.fromMap(doc.id, doc.data()))
        .toList();

    setState(() {
      allEntries = list;
      isLoading = false;
    });
  }

  int get totalReceive => allEntries
      .where((e) => e.type == 'to_receive')
      .fold(0, (sum, e) => sum + e.amount);

  int get totalPay => allEntries
      .where((e) => e.type == 'to_pay')
      .fold(0, (sum, e) => sum + e.amount);

  String get balanceLabel {
    final net = totalReceive - totalPay;
    if (net > 0) return 'BALANCE: ₹$net TO RECEIVE';
    if (net < 0) return 'BALANCE: ₹${net.abs()} TO PAY';
    return 'BALANCE: SETTLED';
  }

  Future<void> _selectDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? fromDate! : toDate!,
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
        _fetchPayments();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.personName;
    final fromText = DateFormat('dd MMM').format(fromDate!);
    final toText = DateFormat('dd MMM yyyy').format(toDate!);

    final receiveList = allEntries
        .where((e) => e.type == 'to_receive')
        .toList();
    final payList = allEntries.where((e) => e.type == 'to_pay').toList();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPaymentDialog(),
        tooltip: "Add Payment",
        child: const Icon(Icons.add),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 8),
                Text(
                  balanceLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: Text("From: $fromText"),
                        onPressed: () => _selectDate(true),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_month),
                        label: Text("To: $toText"),
                        onPressed: () => _selectDate(false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildColumn("🟢 TO RECEIVE", receiveList),
                      ),
                      Expanded(child: _buildColumn("🔴 TO PAY", payList)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildColumn(String title, List<PaymentEntry> entries) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(
            "$title (\${entries.length})",
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
                        title: Text("₹\${e.amount}"),
                        subtitle: Text(
                          "\${e.notes ?? ''}\nDate: \${e.date} | Time: \${e.time}",
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog() {
    showDialog(
      context: context,
      builder: (_) => PaymentDialog(onSaved: _fetchPayments),
    );
  }
}
