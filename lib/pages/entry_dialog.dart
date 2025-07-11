import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  late String _type;
  late String _brand;
  late String _size;
  late String _model;
  late String _person;
  late int _quantity;
  late String _date;
  late String _time;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _time = DateFormat('HH:mm').format(now);
    _date = DateFormat('yyyy-MM-dd').format(now);

    if (widget.existingEntry != null) {
      final e = widget.existingEntry!;
      _type = e.type;
      _brand = e.brand;
      _size = e.size;
      _model = e.model;
      _person = e.person;
      _quantity = e.quantity;
      _date = e.date;
      _time = e.time;
    } else {
      _type = 'IN';
      _brand = '';
      _size = '';
      _model = '';
      _person = '';
      _quantity = 1;
    }
  }

  void _saveEntry() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final data = {
        'type': _type,
        'brand': _brand,
        'size': _size,
        'model': _model,
        'quantity': _quantity,
        'date': _date,
        'time': _time,
        _type == 'IN' ? 'supplier' : 'buyer': _person,
      };

      if (widget.existingEntry == null) {
        await _db.collection('tyre_entries').add(data);
      } else {
        await _db.collection('tyre_entries').doc(widget.existingEntry!.id).update(data);
      }

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
              TextFormField(
                initialValue: _type == 'IN' ? _person : (_person),
                decoration: InputDecoration(labelText: _type == 'IN' ? 'Supplier' : 'Buyer'),
                onSaved: (val) => _person = val ?? '',
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                initialValue: _brand,
                decoration: const InputDecoration(labelText: 'Brand'),
                onSaved: (val) => _brand = val ?? '',
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                initialValue: _size,
                decoration: const InputDecoration(labelText: 'Size'),
                onSaved: (val) => _size = val ?? '',
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                initialValue: _model,
                decoration: const InputDecoration(labelText: 'Model'),
                onSaved: (val) => _model = val ?? '',
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                initialValue: _quantity.toString(),
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
                onSaved: (val) => _quantity = int.tryParse(val ?? '1') ?? 1,
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                initialValue: _date,
                decoration: const InputDecoration(labelText: 'Date'),
                onTap: () async {
                  FocusScope.of(context).requestFocus(FocusNode());
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.parse(_date),
                    firstDate: DateTime(2023),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _date = DateFormat('yyyy-MM-dd').format(picked));
                  }
                },
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
