import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tyre_daybook/models/entry.dart';

class EntrySearchDelegate extends SearchDelegate {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  String get searchFieldLabel => "Search any field";

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) {
    final currentUid = _auth.currentUser?.uid;

    if (currentUid == null) {
      return const Center(child: Text("User not authenticated"));
    }

    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: _db
          .collection('tyre_entries')
          .where('uid', isEqualTo: currentUid)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final matches = snapshot.data!.docs
            .map((doc) => Entry.fromMap(doc.id, doc.data()))
            .where((e) => e.matches(query))
            .toList();

        if (matches.isEmpty) return const Center(child: Text("No matching entries"));

        return ListView.builder(
          itemCount: matches.length,
          itemBuilder: (context, index) {
            final e = matches[index];
            return ListTile(
              title: Text("${e.brand} – ${e.size} ${e.model}"),
              subtitle: Text(
                "${e.type} | ${e.person} | ${e.date} ${e.time} | Qty: ${e.quantity}",
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => const SizedBox();
}
