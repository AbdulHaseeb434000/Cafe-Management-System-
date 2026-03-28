import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

/// Full-screen PDF preview with system Print and Share built-in.
/// Navigate to this via [Navigator.push] and on close use [onDone] callback.
class ReceiptPreviewScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String filename;

  /// Called when the user taps the close button.
  /// Defaults to [Navigator.pop].
  final VoidCallback? onDone;

  const ReceiptPreviewScreen({
    super.key,
    required this.pdfBytes,
    required this.filename,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: onDone ?? () => Navigator.of(context).pop(),
        ),
        title: const Text('Receipt'),
      ),
      body: PdfPreview(
        // Return pre-built bytes — no re-generation needed
        build: (_) => pdfBytes,
        pdfFileName: filename,
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        // Match the 80 mm receipt width so the preview looks right
        initialPageFormat: PdfPageFormat(
          80 * PdfPageFormat.mm,
          300 * PdfPageFormat.mm,
        ),
        scrollViewDecoration: const BoxDecoration(
          color: Color(0xFFEEEEEE),
        ),
      ),
    );
  }
}
