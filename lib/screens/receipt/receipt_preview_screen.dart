import 'dart:typed_data';
import 'package:flutter/material.dart';
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
    // Constrain preview width so it looks like a receipt strip,
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
        // Return pre-built bytes. PdfPreview reads the embedded page
        // dimensions from the PDF itself — do NOT pass an initialPageFormat
        // with double.infinity height or the widget renders blank.
        build: (_) => pdfBytes,
        pdfFileName: filename,
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        // Key: constrains how wide the page renders in the preview so
        // the receipt looks narrow like actual thermal paper.
        maxPageWidth: receiptWidth,
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
