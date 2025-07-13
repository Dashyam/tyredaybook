import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/entry.dart';

class EntrySearchDelegate extends SearchDelegate {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

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
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return const Center(child: Text("User not logged in"));

    final keywords = query.toLowerCase().split(' ');

    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: _db
          .collection('tyre_entries')
          .where('uid', isEqualTo: currentUid)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final matches = snapshot.data!.docs
            .map((doc) => Entry.fromMap(doc.id, doc.data()))
            .where((e) => keywords.every((kw) =>
                e.brand.toLowerCase().contains(kw) ||
                e.size.toLowerCase().contains(kw) ||
                e.model.toLowerCase().contains(kw) ||
                e.person.toLowerCase().contains(kw) ||
                e.type.toLowerCase().contains(kw) ||
                e.date.toLowerCase().contains(kw) ||
                e.time.toLowerCase().contains(kw)))
            .toList();

        if (matches.isEmpty) {
          return const Center(child: Text("No matching entries"));
        }

        return ListView.builder(
          itemCount: matches.length,
          itemBuilder: (context, index) {
            final e = matches[index];
            return ListTile(
              title: Text('${e.brand} ${e.size} ${e.model}'),
              subtitle: Text('${e.person} | ${e.type} | Qty: ${e.quantity} | ${e.date} ${e.time}'),
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => const SizedBox();
}
