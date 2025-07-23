class Entry {
  final String id;
  final String uid;
  final String shopId; // ✅ NEW
  final String type;
  final String brand;
  final String size;
  final String model;
  final int quantity;
  final String person;
  final String date;
  final String time;

  Entry({
    required this.id,
    required this.uid,
    required this.shopId, // ✅ NEW
    required this.type,
    required this.brand,
    required this.size,
    required this.model,
    required this.quantity,
    required this.person,
    required this.date,
    required this.time,
  });

  factory Entry.fromMap(String id, Map<String, dynamic> data) {
    return Entry(
      id: id,
      uid: data['uid'] ?? '',
      shopId: data['shopId'] ?? '', // ✅ NEW fallback to empty if missing
      type: data['type'],
      brand: data['brand'],
      size: data['size'],
      model: data['model'],
      quantity: data['quantity'],
      person: data['type'] == 'IN' ? data['supplier'] : data['buyer'],
      date: data['date'],
      time: data['time'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'shopId': shopId, // ✅ NEW
      'type': type,
      'brand': brand,
      'size': size,
      'model': model,
      'quantity': quantity,
      'date': date,
      'time': time,
      type == 'IN' ? 'supplier' : 'buyer': person,
    };
  }

  bool matches(String query) {
    final q = query.toLowerCase();
    return brand.toLowerCase().contains(q) ||
        size.toLowerCase().contains(q) ||
        model.toLowerCase().contains(q) ||
        person.toLowerCase().contains(q) ||
        date.contains(query) ||
        time.contains(query) ||
        type.toLowerCase().contains(q);
  }
}
