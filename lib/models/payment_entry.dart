
class PaymentEntry {
  final String id;
  final String uid;
  final String person;
  final String normalizedName;
  final int amount;
  final String type;
  final String notes;
  final String date;
  final String time;
  final bool isSettled;

  PaymentEntry({
    required this.id,
    required this.uid,
    required this.person,
    required this.normalizedName,
    required this.amount,
    required this.type,
    required this.notes,
    required this.date,
    required this.time,
    required this.isSettled,
  });

  factory PaymentEntry.fromMap(String id, Map<String, dynamic> data) {
    return PaymentEntry(
      id: id,
      uid: data['uid'] ?? '',
      person: data['person'] ?? '',
      normalizedName: data['normalizedName'] ?? '',
      amount: data['amount'] ?? 0,
      type: data['type'] ?? '',
      notes: data['notes'] ?? '',
      date: data['date'] ?? '',
      time: data['time'] ?? '',
      isSettled: data['isSettled'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'person': person,
      'normalizedName': normalizedName,
      'amount': amount,
      'type': type,
      'notes': notes,
      'date': date,
      'time': time,
      'isSettled': isSettled,
    };
  }

  PaymentEntry copyWith({
    String? id,
    String? uid,
    String? person,
    String? normalizedName,
    int? amount,
    String? type,
    String? notes,
    String? date,
    String? time,
    bool? isSettled,
  }) {
    return PaymentEntry(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      person: person ?? this.person,
      normalizedName: normalizedName ?? this.normalizedName,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      time: time ?? this.time,
      isSettled: isSettled ?? this.isSettled,
    );
  }
}
