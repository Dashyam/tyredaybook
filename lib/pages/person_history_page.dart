import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tyre_daybook/utils/normalized_name_util.dart';
import '../models/payment_entry.dart';

class PersonPaymentHistoryPage extends StatefulWidget {
  final String personName;
  final String normalizedKey;

  const PersonPaymentHistoryPage({
    super.key,
    required this.personName,
    required this.normalizedKey,
  });

  @override
  State<PersonPaymentHistoryPage> createState() =>
      _PersonPaymentHistoryPageState();
}

class _PersonPaymentHistoryPageState extends State<PersonPaymentHistoryPage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  List<PaymentEntry> entries = [];
  bool isLoading = true;
  int totalToReceive = 0;
  int totalToPay = 0;

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
      return PaymentEntry.fromMap(doc.id, doc.data() as Map<String, dynamic>);
    }).toList();

    result.sort((a, b) => b.date.compareTo(a.date)); // newest to oldest

    int receive = 0;
    int pay = 0;
    for (var entry in result) {
      if (entry.type == 'to_receive') {
        receive += entry.amount;
      } else {
        pay += entry.amount;
      }
    }

    setState(() {
      entries = result;
      totalToReceive = receive;
      totalToPay = pay;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final person = widget.personName;
    final netBalance = totalToReceive - totalToPay;

    String statusText;
    Color statusColor;

    if (netBalance > 0) {
      statusText = " Receive: ₹$netBalance";
      statusColor = Colors.green;
    } else if (netBalance < 0) {
      statusText = "Pay: ₹${-netBalance}";
      statusColor = Colors.red;
    } else {
      statusText = "Settled";
      statusColor = Colors.green;
    }

    return Scaffold(
      appBar: AppBar(title: Text("History: $person")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : entries.isEmpty
          ? const Center(child: Text("No entries for this person"))
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  color: statusColor.withOpacity(0.1),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    padding: const EdgeInsets.all(12),
                    child: Table(
                      columnWidths: const {
                        0: FixedColumnWidth(100),
                        1: FlexColumnWidth(),
                      },
                      border: TableBorder.all(color: Colors.grey.shade300),
                      defaultVerticalAlignment:
                          TableCellVerticalAlignment.middle,
                      children: [
                        TableRow(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                          ),
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

                          return TableRow(
                            children: [
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
                                          ? 'Payment'
                                          : 'Receipt',
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
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
