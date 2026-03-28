import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

/// Full-screen PDF preview sized as a thermal receipt strip.
/// The preview renders at receipt width (not full screen) and includes
/// built-in Print and Share actions via the [printing] package.
class ReceiptPreviewScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String filename;

  /// Called when the user taps the close button. Defaults to [Navigator.pop].
  final VoidCallback? onDone;

  const ReceiptPreviewScreen({
    super.key,
    required this.pdfBytes,
    required this.filename,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    // Keep the preview page narrow so it looks like a receipt strip,
    // not a stretched full-page document.
    final screenWidth = MediaQuery.of(context).size.width;
    final receiptWidth = (screenWidth * 0.65).clamp(220.0, 340.0);

    return Scaffold(
      backgroundColor: const Color(0xFFD0D0D0),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: onDone ?? () => Navigator.of(context).pop(),
        ),
        title: const Text('Receipt Preview'),
      ),
      body: PdfPreview(
        build: (_) => pdfBytes,
        pdfFileName: filename,
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        // Constrains how wide the page renders in the preview widget —
        // this is the key setting that makes the receipt look narrow.
        maxPageWidth: receiptWidth,
        initialPageFormat: PdfPageFormat(
          80 * PdfPageFormat.mm,
          double.infinity,
        ),
        scrollViewDecoration: const BoxDecoration(
          color: Color(0xFFD0D0D0),
        ),
        previewPageMargin: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
      ),
    );
  }
}
