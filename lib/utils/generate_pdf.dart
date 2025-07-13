import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tyre_daybook/models/entry.dart';

Future<Uint8List> generateEntryPdf(List<Entry> inEntries, List<Entry> outEntries) async {
  final pdf = pw.Document();

  pw.Widget buildTable(String title, List<Entry> entries) {
    if (entries.isEmpty) {
      return pw.Text("No entries found for $title.");
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headers: ['Type', 'Brand', 'Size', 'Model', 'Qty', 'Person', 'Date', 'Time'],
          data: entries.map((e) => [
            e.type,
            e.brand,
            e.size,
            e.model,
            e.quantity.toString(),
            e.person,
            e.date,
            e.time
          ]).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.all(5),
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pdf.addPage(
    pw.MultiPage(
      build: (context) => [
        pw.Text("Tyre Daybook Report", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 20),
        buildTable("🟢 IN Entries", inEntries),
        buildTable("🔴 OUT Entries", outEntries),
      ],
    ),
  );

  return pdf.save();
}
