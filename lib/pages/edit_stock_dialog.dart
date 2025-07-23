import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditStockDialog extends StatefulWidget {
  final Map<String, dynamic> item;

  const EditStockDialog({super.key, required this.item});

  @override
  State<EditStockDialog> createState() => _EditStockDialogState();
}

class _EditStockDialogState extends State<EditStockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _quantityController.text = widget.item['quantity'].toString();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    final docId =
        "${widget.item['brand']}|${widget.item['size']}|${widget.item['model']}";

    await _db.collection('stock_items').doc(docId).set({
      'brand': widget.item['brand'],
      'size': widget.item['size'],
      'model': widget.item['model'],
      'quantity': quantity,
      'uid': uid,
    });

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final title =
        "${widget.item['brand']} ${widget.item['size']} ${widget.item['model']}"
            .toUpperCase();

    return AlertDialog(
      title: Text("Edit Stock: $title"),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _quantityController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Quantity"),
          validator: (val) {
            if (val == null || val.isEmpty) return "Enter quantity";
            if (int.tryParse(val) == null) return "Must be a number";
            return null;
          },
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
