import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tyre_daybook/utils/normalized_name_util.dart';
import '../models/payment_entry.dart';

class PersonPaymentHistoryPage extends StatefulWidget {
  final String personName;
  final String normalizedKey;

  const PersonPaymentHistoryPage({super.key,
    required this.personName,
    required this.normalizedKey,});

  @override
  State<PersonPaymentHistoryPage> createState() =>
      _PersonPaymentHistoryPageState();
}

class _PersonPaymentHistoryPageState extends State<PersonPaymentHistoryPage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  List<PaymentEntry> entries = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPersonPayments();
  }

  void _fetchPersonPayments() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await _db
    .collection('payments')
    .where('uid', isEqualTo: uid)
    .where('normalizedName', isEqualTo: widget.normalizedKey)
    .get();

    final result = snapshot.docs.map((doc) {
      return PaymentEntry.fromMap(
        doc.id,
        doc.data() as Map<String, dynamic>,
      );
    }).toList();

    setState(() {
      entries = result;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final person = widget.personName;

    return Scaffold(
      appBar: AppBar(title: Text("History: $person")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : entries.isEmpty
              ? const Center(child: Text("No entries for this person"))
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  padding: const EdgeInsets.all(12),
                  child: Table(
                    columnWidths: const {
                      0: FixedColumnWidth(100),
                      1: FlexColumnWidth(),
                    },
                    border: TableBorder.all(color: Colors.grey.shade300),
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      TableRow(
                        decoration:
                            BoxDecoration(color: Colors.grey.shade200),
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              "Date",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              "Details",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      ...entries.map((entry) {
                        final date = entry.date;
                        final note = entry.notes;
                        final amount = entry.amount;
                        final type = entry.type;
                        final balance = type == 'to_receive'
                            ? "+₹$amount"
                            : "-₹$amount";

                        return TableRow(children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              DateFormat('dd MMM').format(
                                DateTime.tryParse(date) ?? DateTime.now(),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  type == 'to_receive'
                                      ? 'To Receive'
                                      : 'To Pay',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: type == 'to_receive'
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                                Text('Amount: $balance'),
                                if (note.isNotEmpty)
                                  Text(
                                    'Note: $note',
                                    style:
                                        const TextStyle(color: Colors.grey),
                                  ),
                              ],
                            ),
                          ),
                        ]);
                      }).toList()
                    ],
                  ),
                ),
    );
  }
}
