import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/payment_entry.dart';

class FirebasePaymentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get uid => _auth.currentUser?.uid;

  Future<void> addPayment(PaymentEntry entry) async {
    if (uid == null) return;
    await _db.collection('payments').add(entry.toMap());
  }

  Future<List<PaymentEntry>> getAllPayments() async {
    if (uid == null) return [];

    final snapshot = await _db
        .collection('payments')
        .where('uid', isEqualTo: uid)
        .get();

    return snapshot.docs
        .map((doc) => PaymentEntry.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<List<String>> getSuggestedPersons() async {
    if (uid == null) return [];

    final snapshot = await _db
        .collection('payments')
        .where('uid', isEqualTo: uid)
        .get();

    return snapshot.docs
        .map((doc) => doc['person'].toString().trim())
        .toSet()
        .toList();
  }

  Future<void> markPersonSettled(String person, bool settled) async {
    if (uid == null) return;

    final batch = _db.batch();

    final snapshot = await _db
        .collection('payments')
        .where('uid', isEqualTo: uid)
        .where('person', isEqualTo: person)
        .get();

    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isSettled': settled});
    }

    await batch.commit();
  }

  Future<List<PaymentEntry>> getPaymentsForPerson(String person) async {
    if (uid == null) return [];

    final snapshot = await _db
        .collection('payments')
        .where('uid', isEqualTo: uid)
        .where('person', isEqualTo: person)
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => PaymentEntry.fromMap(doc.id, doc.data()))
        .toList();
  }
}
