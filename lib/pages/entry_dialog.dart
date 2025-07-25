import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

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

  final _brandC = TextEditingController();
  final _sizeC = TextEditingController();
  final _modelC = TextEditingController();
  final _personC = TextEditingController();
  final _qtyC = TextEditingController();

  final _personFocus = FocusNode();
  final _brandFocus = FocusNode();
  final _sizeFocus = FocusNode();
  final _modelFocus = FocusNode();
  final _qtyFocus = FocusNode();

  List<String> _brandSuggestions = [];
  List<String> _sizeSuggestions = [];
  List<String> _modelSuggestions = [];
  List<String> _personSuggestions = [];

  late String _type;
  late DateTime _selectedDate;
  late String _time;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = now;
    _time = DateFormat('HH:mm').format(now);
    _type = widget.existingEntry?.type ?? 'IN';

    if (widget.existingEntry != null) {
      final e = widget.existingEntry!;
      _brandC.text = e.brand;
      _sizeC.text = e.size;
      _modelC.text = e.model;
      _personC.text = e.person;
      _qtyC.text = e.quantity.toString();
      _selectedDate = DateTime.tryParse(e.date) ?? now;
      _time = e.time;
    } else {
      _qtyC.text = '1';
    }

    _loadSuggestions();
  }

  @override
  void dispose() {
    _personFocus.dispose();
    _brandFocus.dispose();
    _sizeFocus.dispose();
    _modelFocus.dispose();
    _qtyFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final doc = await _db.collection('user_suggestions').doc(uid).get();
    final data = doc.data() ?? {};

    setState(() {
      _brandSuggestions = (data['brand'] as List?)?.cast<String>() ?? [];
      _sizeSuggestions = (data['size'] as List?)?.cast<String>() ?? [];
      _modelSuggestions = (data['model'] as List?)?.cast<String>() ?? [];
      _personSuggestions =
          (data[_type == 'IN' ? 'supplier' : 'buyer'] as List?)
              ?.cast<String>() ??
          [];
    });
  }

  Future<void> _addSuggestion(String field, String value) async {
    if (value.trim().isEmpty) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _db.collection('user_suggestions').doc(uid).set({
      field: FieldValue.arrayUnion([value.trim()]),
    }, SetOptions(merge: true));
  }

  Widget _buildTypeAheadField({
    required TextEditingController controller,
    required String label,
    required List<String> suggestions,
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
  }) {
    return TypeAheadFormField<String>(
      textFieldConfiguration: TextFieldConfiguration(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.next,
        onEditingComplete: () {
          FocusScope.of(context).requestFocus(nextFocusNode);
        },
        decoration: InputDecoration(labelText: label),
        onTap: () {
          if (controller.text.isEmpty) {
            controller.text = '';
          }
        },
      ),
      suggestionsCallback: (pattern) {
        if (pattern.isEmpty) return suggestions;
        return suggestions.where(
          (item) => item.toLowerCase().contains(pattern.toLowerCase()),
        );
      },
      itemBuilder: (context, String suggestion) {
        return ListTile(title: Text(suggestion));
      },
      onSuggestionSelected: (String suggestion) {
        controller.text = suggestion;
      },
      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
      noItemsFoundBuilder: (context) => const SizedBox(),
      suggestionsBoxDecoration: SuggestionsBoxDecoration(
        elevation: 4,
        constraints: BoxConstraints(maxHeight: 200),
      ),
      transitionBuilder: (context, suggestionsBox, controller) {
        return Material(elevation: 4, child: suggestionsBox);
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final userDoc = await _db.collection('users').doc(uid).get();
    final shopId = userDoc.data()?['shopId'] ?? '';
    if (shopId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ shopId not found for user')),
      );
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final personField = _type == 'IN' ? 'supplier' : 'buyer';
    final personValue = _personC.text.trim();
    final quantity = int.tryParse(_qtyC.text.trim()) ?? 1;
    final brand = _brandC.text.trim();
    final size = _sizeC.text.trim();
    final model = _modelC.text.trim();

    final data = {
      'uid': uid,
      'shopId': shopId,
      'type': _type,
      'brand': brand,
      'size': size,
      'model': model,
      'quantity': quantity,
      'date': dateStr,
      'time': _time,
      personField: personValue,
    };

    final col = _db.collection('tyre_entries');

    try {
      if (widget.existingEntry == null) {
        await col.add(data);
      } else {
        await col.doc(widget.existingEntry!.id).update(data);
      }

      await Future.wait([
        _addSuggestion('brand', brand),
        _addSuggestion('size', size),
        _addSuggestion('model', model),
        _addSuggestion(personField, personValue),
      ]);

      final safeSize = size.replaceAll('/', '_');
      final docId = "$brand|$safeSize|$model";
      final stockRef = _db.collection('stock_items').doc(docId);

      await stockRef.set({
        'brand': brand,
        'size': size,
        'model': model,
        'uid': uid,
        'shopId': shopId,
        'quantity': FieldValue.increment(_type == 'IN' ? quantity : -quantity),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingEntry == null
                ? '✅ Tyre entry saved'
                : '✅ Tyre entry updated',
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to save entry: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existingEntry == null ? 'New Tyre Entry' : 'Edit Tyre Entry',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'IN', child: Text('IN')),
                  DropdownMenuItem(value: 'OUT', child: Text('OUT')),
                ],
                onChanged: (val) {
                  setState(() {
                    _type = val!;
                    _loadSuggestions();
                  });
                },
              ),
              _buildTypeAheadField(
                controller: _personC,
                label: _type == 'IN' ? 'Supplier' : 'Buyer',
                suggestions: _personSuggestions,
                focusNode: _personFocus,
                nextFocusNode: _brandFocus,
              ),
              _buildTypeAheadField(
                controller: _brandC,
                label: 'Brand',
                suggestions: _brandSuggestions,
                focusNode: _brandFocus,
                nextFocusNode: _sizeFocus,
              ),
              _buildTypeAheadField(
                controller: _sizeC,
                label: 'Size',
                suggestions: _sizeSuggestions,
                focusNode: _sizeFocus,
                nextFocusNode: _modelFocus,
              ),
              _buildTypeAheadField(
                controller: _modelC,
                label: 'Model',
                suggestions: _modelSuggestions,
                focusNode: _modelFocus,
                nextFocusNode: _qtyFocus,
              ),
              TextFormField(
                controller: _qtyC,
                focusNode: _qtyFocus,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2023),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null)
                        setState(() => _selectedDate = picked);
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
