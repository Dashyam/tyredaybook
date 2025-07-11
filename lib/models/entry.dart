class Entry {
  final String id;
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
    return brand.toLowerCase().contains(query.toLowerCase()) ||
        size.toLowerCase().contains(query.toLowerCase()) ||
        model.toLowerCase().contains(query.toLowerCase()) ||
        person.toLowerCase().contains(query.toLowerCase()) ||
        date.contains(query);
  }
}
