import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
  String? userRole;
  String? shopId;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    _fetchUser();
  }

  void _fetchUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      setState(() {
        userRole = doc['role'];
        shopId = doc['shopId'];
      });
      _fetchEntries();
    }
  }

  Future<void> _generateAndDownloadPdf() async {
    final pdf = pw.Document();

    final dateTitle = fromDate != null && toDate != null
        ? "From ${DateFormat('dd MMM yyyy').format(fromDate!)} to ${DateFormat('dd MMM yyyy').format(toDate!)}"
        : DateFormat('EEEE, dd MMMM yyyy').format(selectedDate);

    final totalIn = _getTotal(inEntries);
    final totalOut = _getTotal(outEntries);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Text(
                'Tyre Daybook Report',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(dateTitle, style: pw.TextStyle(fontSize: 14)),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'IN Entries (Total: $totalIn)',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            _buildEntryTable(inEntries),
            pw.SizedBox(height: 16),
            pw.Text(
              'OUT Entries (Total: $totalOut)',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            _buildEntryTable(outEntries),
          ];
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'tyre_daybook_report.pdf',
    );
  }

  pw.Widget _buildEntryTable(List<Entry> entries) {
    if (entries.isEmpty) {
      return pw.Text("No entries available.");
    }

    return pw.Table.fromTextArray(
      headers: ['Brand', 'Size', 'Model', 'Qty', 'Person', 'Date', 'Time'],
      data: entries.map((e) {
        return [
          e.brand.toUpperCase(),
          e.size.toUpperCase(),
          e.model.toUpperCase(),
          e.quantity.toString(),
          e.person.toUpperCase(),
          e.date,
          e.time,
        ];
      }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellAlignment: pw.Alignment.centerLeft,
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(1),
        4: const pw.FlexColumnWidth(2),
        5: const pw.FlexColumnWidth(2),
        6: const pw.FlexColumnWidth(1.5),
      },
      border: pw.TableBorder.all(width: 0.3),
    );
  }

  void _fetchEntries() {
    if (shopId == null || userRole == null) return;

    final isRangeSelected = fromDate != null && toDate != null;
    DateTime from, to;

    if (isRangeSelected) {
      from = fromDate!;
      to = toDate!;
    } else {
      from = selectedDate;
      to = selectedDate;
    }

    final fromStr = DateFormat('yyyy-MM-dd').format(from);
    final toStr = DateFormat('yyyy-MM-dd').format(to);

    print('📣 Fetching entries for role: $userRole');
    print('🔍 shopId: $shopId');
    print('📅 Date range: $fromStr to $toStr');

    Query query = _db
        .collection('tyre_entries')
        .where('shopId', isEqualTo: shopId)
        .where('date', isGreaterThanOrEqualTo: fromStr)
        .where('date', isLessThanOrEqualTo: toStr);

    query.snapshots().listen((snapshot) {
      print(
        '📦 Total documents fetched from Firestore: ${snapshot.docs.length}',
      );

      List<Entry> inList = [];
      List<Entry> outList = [];

      final keywords = searchQuery.toLowerCase().split(' ');

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        print('🧾 Entry: ${data['brand']} - Date: ${data['date']}');

        final entry = Entry.fromMap(doc.id, data);

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
    if (userRole == 'manager') return;

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
    if (userRole == 'manager') return;

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
    final newDate = selectedDate.add(Duration(days: days));

    if (userRole == 'manager') {
      final today = DateTime.now();
      final earliest = today.subtract(const Duration(days: 6));

      if (newDate.isBefore(earliest) || newDate.isAfter(today)) return;
    }

    setState(() {
      selectedDate = newDate;
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
            Expanded(child: Text('Daybook – $titleDate')),
            if (userRole != 'manager')
              IconButton(
                icon: const Icon(Icons.calendar_today),
                tooltip: "Pick a date",
                onPressed: _selectSingleDate,
              ),
            if (userRole != 'manager')
              IconButton(
                icon: const Icon(Icons.payments),
                tooltip: "Go to Payments",
                onPressed: () {
                  Navigator.pushNamed(context, '/payments');
                },
              ),
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: "Download PDF",
              onPressed: _generateAndDownloadPdf,
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
            if (userRole != 'manager')
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
            if (userRole != 'manager')
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          FloatingActionButton(
            onPressed: _showEntryDialog,
            child: const Icon(Icons.add),
            tooltip: "Add Tyre Entry",
            heroTag: "add_button",
          ),
        ],
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
          if (userRole != 'manager')
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
