import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart'; // From printing package
import '../../theme/app_theme.dart';
// import 'package:pdf/pdf.dart'; // Not strictly needed here if we just use PdfPreview

class InvoicePreviewScreen extends StatelessWidget {
  final String title;
  final Future<Uint8List> Function(dynamic format) buildPdf;

  const InvoicePreviewScreen({
    super.key,
    required this.title,
    required this.buildPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        build: buildPdf,
        // Optional: customize actions
        canChangeOrientation: false,
        canDebug: false,
        actions: const [
          // We can add custom actions here if needed,
          // but PdfPreview comes with Print, Share, etc. by default.
        ],
      ),
    );
  }
}
