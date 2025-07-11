import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/entry.dart';

class EntrySearchDelegate extends SearchDelegate {
  final _db = FirebaseFirestore.instance;

  @override
  String get searchFieldLabel => "Search tyre entries";

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear)),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        onPressed: () => close(context, null),
        icon: const Icon(Icons.arrow_back),
      );

  @override
  Widget buildResults(BuildContext context) {
    return FutureBuilder(
      future: _db.collection('tyre_entries').get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final matches = snapshot.data!.docs
            .map((doc) => Entry.fromMap(doc.id, doc.data()))
            .where((e) =>
                e.brand.toLowerCase().contains(query.toLowerCase()) ||
                e.size.toLowerCase().contains(query.toLowerCase()) ||
                e.model.toLowerCase().contains(query.toLowerCase()) ||
                e.person.toLowerCase().contains(query.toLowerCase()))
            .toList();
        return ListView(
          children: matches
              .map((e) => ListTile(
                    title: Text('${e.brand} ${e.size} ${e.model}'),
                    subtitle: Text('${e.person} | ${e.type} | Qty: ${e.quantity} | ${e.date} ${e.time}'),
                  ))
              .toList(),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => const SizedBox();
}
