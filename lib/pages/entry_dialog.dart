import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/entry.dart';

class EntryDialog extends StatefulWidget {
  final VoidCallback onSaved;
  final Entry? existingEntry;

  const EntryDialog({super.key, required this.onSaved, this.existingEntry});

  @override
  State<EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<EntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  late String _type;
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _sizeController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _personController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  late DateTime _selectedDate;
  late String _time;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = now;
    _time = DateFormat('HH:mm').format(now);

    if (widget.existingEntry != null) {
      final e = widget.existingEntry!;
      _type = e.type;
      _brandController.text = e.brand;
      _sizeController.text = e.size;
      _modelController.text = e.model;
      _personController.text = e.person;
      _quantityController.text = e.quantity.toString();
      _selectedDate = DateTime.tryParse(e.date) ?? now;
      _time = e.time;
    } else {
      _type = 'IN';
      _quantityController.text = '1';
    }
  }

  Future<List<String>> _getSuggestions(String field) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final snapshot = await _db
        .collection('tyre_entries')
        .where('uid', isEqualTo: uid)
        .orderBy('date', descending: true)
        .limit(100)
        .get();

    final set = <String>{};
    for (var doc in snapshot.docs) {
      final value = doc.data()[field];
      if (value != null && value is String) set.add(value);
    }
    return set.toList();
  }

 Widget _autoField(TextEditingController controller, String label, String field) {
  return FutureBuilder<List<String>>(
    future: _getSuggestions(field),
    builder: (context, snapshot) {
      final suggestions = snapshot.data ?? [];

      return Autocomplete<String>(
        optionsBuilder: (text) {
          if (!snapshot.hasData) return const Iterable<String>.empty();
          final input = text.text.toLowerCase();
          return suggestions.where((e) => input.isEmpty || e.toLowerCase().contains(input));
        },
        onSelected: (val) => controller.text = val,
        fieldViewBuilder: (context, tController, focusNode, onSubmit) {
          tController.text = controller.text;
          return TextFormField(
            controller: tController,
            focusNode: focusNode,
            decoration: InputDecoration(labelText: label),
            onChanged: (val) => controller.text = val,
            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
          );
        },
      );
    },
  );
}


  void _saveEntry() async {
    if (_formKey.currentState!.validate()) {
      final uid = _auth.currentUser!.uid;
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final data = {
        'uid': uid,
        'type': _type,
        'brand': _brandController.text.trim(),
        'size': _sizeController.text.trim(),
        'model': _modelController.text.trim(),
        'quantity': int.tryParse(_quantityController.text.trim()) ?? 1,
        'date': dateStr,
        'time': _time,
        _type == 'IN' ? 'supplier' : 'buyer': _personController.text.trim(),
      };

      if (widget.existingEntry == null) {
        await _db.collection('tyre_entries').add(data);
      } else {
        await _db.collection('tyre_entries').doc(widget.existingEntry!.id).update(data);
      }

      if (context.mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingEntry == null ? 'Entry saved' : 'Entry updated'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _brandController.dispose();
    _sizeController.dispose();
    _modelController.dispose();
    _personController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingEntry == null ? 'New Tyre Entry' : 'Edit Tyre Entry'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _type,
                items: ['IN', 'OUT'].map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (value) => setState(() => _type = value!),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              _autoField(_personController, _type == 'IN' ? 'Supplier' : 'Buyer', _type == 'IN' ? 'supplier' : 'buyer'),
              _autoField(_brandController, 'Brand', 'brand'),
              _autoField(_sizeController, 'Size', 'size'),
              _autoField(_modelController, 'Model', 'model'),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.calendar_today),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2023),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                    child: Text(DateFormat('dd-MM-yyyy').format(_selectedDate)),
                  ),
                ],
              ),
              TextFormField(
                initialValue: _time,
                decoration: const InputDecoration(labelText: 'Time'),
                enabled: false,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _saveEntry, child: const Text('Save')),
      ],
    );
  }
}
