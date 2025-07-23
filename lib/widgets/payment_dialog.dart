import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../models/payment_entry.dart';
import '../utils/normalized_name_util.dart';

class PaymentDialog extends StatefulWidget {
  final VoidCallback onSaved;

  const PaymentDialog({super.key, required this.onSaved});

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final TextEditingController _personController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _type = 'to_receive';
  DateTime _selectedDate = DateTime.now();
  bool _warnDuplicate = false;
  List<String> _suggestedPeople = [];

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  void _loadSuggestions() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await _db
        .collection('payments')
        .where('uid', isEqualTo: uid)
        .get();

    final names = snapshot.docs
        .map((doc) => doc['person'].toString().trim().toUpperCase())
        .toSet()
        .toList();

    setState(() {
      _suggestedPeople = names;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final now = TimeOfDay.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final timeStr = now.format(context);
    final typedName = _personController.text.trim().toUpperCase();
    final normalized = normalizeName(typedName);

    final existingNormalized = _suggestedPeople
        .map((e) => normalizeName(e))
        .firstWhere((e) => e == normalized, orElse: () => '');

    if (_warnDuplicate == false &&
        existingNormalized.isNotEmpty &&
        existingNormalized != normalized) {
      setState(() => _warnDuplicate = true);
      return;
    }

    final entry = PaymentEntry(
      id: '',
      uid: uid,
      person: typedName,
      normalizedName: normalized,
      amount: int.parse(_amountController.text.trim()),
      type: _type,
      notes: _notesController.text.trim().toUpperCase(),
      date: dateStr,
      time: timeStr,
      isSettled: false,
    );

    try {
      await _db.collection('payments').add(entry.toMap());
      if (mounted) {
        Navigator.pop(context); // Close dialog
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Payment entry saved"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Failed to save payment: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Add Payment"),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 350,
          child: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(
                    labelText: 'To Receive / To Pay',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'to_receive',
                      child: Text('To Receive'),
                    ),
                    DropdownMenuItem(value: 'to_pay', child: Text('To Pay')),
                  ],
                  onChanged: (val) => setState(() => _type = val!),
                ),
                const SizedBox(height: 12),
                TypeAheadFormField(
                  textFieldConfiguration: TextFieldConfiguration(
                    controller: _personController,
                    decoration: InputDecoration(
                      labelText: 'Person Name',
                      suffixIcon: Tooltip(
                        message: "Use the same spelling to group payments.",
                        child: const Icon(Icons.info_outline),
                      ),
                    ),
                    onChanged: (_) => setState(() => _warnDuplicate = false),
                  ),
                  suggestionsCallback: (pattern) {
                    return _suggestedPeople.where(
                      (p) => p.contains(pattern.toUpperCase()),
                    );
                  },
                  itemBuilder: (context, suggestion) {
                    return ListTile(title: Text(suggestion));
                  },
                  onSuggestionSelected: (suggestion) {
                    _personController.text = suggestion;
                  },
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                if (_warnDuplicate)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      "Looks like you’ve used this name before. This payment will be grouped under that. Change the name if it’s someone else, or press OK to continue.",
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Required';
                    final n = int.tryParse(val.trim());
                    if (n == null || n <= 0) return 'Invalid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text("Date: "),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2023),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                      child: Text(
                        DateFormat('dd MMM yyyy').format(_selectedDate),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(onPressed: _save, child: const Text("Save")),
      ],
    );
  }
}
