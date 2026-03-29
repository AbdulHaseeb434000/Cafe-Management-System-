import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/constants/app_constants.dart';
import '../../models/order_model.dart';
import '../../models/payment_model.dart';

/// Generates PDF bytes for receipts and kitchen tickets.
/// Page width matches standard 80 mm thermal paper.
class PdfReceiptService {
  PdfReceiptService._();
  static final PdfReceiptService instance = PdfReceiptService._();

  // 80 mm wide thermal receipt. Height is generous to fit any receipt length;
  // maxPageWidth in PdfPreview constrains the on-screen render width.
  static final _fmt = PdfPageFormat(
    80 * PdfPageFormat.mm,
    600 * PdfPageFormat.mm,
    marginLeft: 4 * PdfPageFormat.mm,
    marginRight: 4 * PdfPageFormat.mm,
    marginTop: 4 * PdfPageFormat.mm,
    marginBottom: 4 * PdfPageFormat.mm,
  );

  // ── Public API ───────────────────────────────────────────────────────────

  Future<Uint8List> buildReceipt({
    required OrderModel order,
    required PaymentModel payment,
    required Map<String, String> settings,
  }) async {
    final cafeName = settings[AppConstants.settingCafeName] ?? 'My Cafe';
    final cafeAddress = settings[AppConstants.settingCafeAddress] ?? '';
    final cafePhone = settings[AppConstants.settingCafePhone] ?? '';
    final header = settings[AppConstants.settingReceiptHeader] ?? '';
    final footer = settings[AppConstants.settingReceiptFooter] ?? '';
    final currency = settings[AppConstants.settingCurrencySymbol] ??
        AppConstants.defaultCurrencySymbol;
    final logoPath = settings[AppConstants.settingLogoPath] ?? '';

    pw.ImageProvider? logo;
    if (logoPath.isNotEmpty) {
      final file = File(logoPath);
      if (await file.exists()) {
        logo = pw.MemoryImage(await file.readAsBytes());
      }
    }

    final bold = pw.Font.helveticaBold();
    final reg = pw.Font.helvetica();

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: _fmt,
        build: (ctx) => [
          // ── Cafe header ──────────────────────────────────────────────
          if (logo != null) ...[
            pw.Center(child: pw.Image(logo, width: 60, height: 60)),
            pw.SizedBox(height: 4),
          ],
          pw.Center(
            child: pw.Text(cafeName.toUpperCase(),
                style: pw.TextStyle(font: bold, fontSize: 13)),
          ),
          if (cafeAddress.isNotEmpty)
            pw.Center(
              child: pw.Text(cafeAddress,
                  style: pw.TextStyle(font: reg, fontSize: 8)),
            ),
          if (cafePhone.isNotEmpty)
            pw.Center(
              child: pw.Text(cafePhone,
                  style: pw.TextStyle(font: reg, fontSize: 8)),
            ),
          if (header.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(header,
                  style: pw.TextStyle(font: reg, fontSize: 8)),
            ),
          ],
          _divider(),

          // ── Order info ───────────────────────────────────────────────
          _infoRow(reg, bold, 'Order', order.displayId),
          _infoRow(reg, bold, 'Date', _fmtDt(order.createdAt)),
          _infoRow(reg, bold, 'Type', _typeLabel(order.type)),
          if (order.isDineIn && order.tableName != null)
            _infoRow(reg, bold, 'Table', order.tableName!),
          if (order.customerName != null)
            _infoRow(reg, bold, 'Customer', order.customerName!),
          if (order.deliveryAddress != null &&
              order.deliveryAddress!.isNotEmpty)
            _infoRow(reg, bold, 'Address', order.deliveryAddress!),
          _divider(),

          // ── Items ────────────────────────────────────────────────────
          ...order.items.map(
            (item) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('${item.quantity}×  ',
                      style: pw.TextStyle(font: bold, fontSize: 9)),
                  pw.Expanded(
                    child: pw.Text(item.nameSnapshot,
                        style: pw.TextStyle(font: reg, fontSize: 9)),
                  ),
                  pw.Text(
                      '$currency${item.lineTotal.toStringAsFixed(2)}',
                      style: pw.TextStyle(font: reg, fontSize: 9)),
                ],
              ),
            ),
          ),
          _divider(),

          // ── Totals ───────────────────────────────────────────────────
          _amtRow(reg, 'Subtotal',
              '$currency${order.subtotal.toStringAsFixed(2)}'),
          if (order.discountAmount > 0)
            _amtRow(reg, 'Discount',
                '-$currency${order.discountAmount.toStringAsFixed(2)}'),
          if (order.taxAmount > 0)
            _amtRow(reg,
                'Tax (${order.taxPercent.toStringAsFixed(1)}%)',
                '$currency${order.taxAmount.toStringAsFixed(2)}'),
          pw.SizedBox(height: 2),
          pw.Row(
            children: [
              pw.Text('TOTAL',
                  style: pw.TextStyle(font: bold, fontSize: 12)),
              pw.Spacer(),
              pw.Text(
                  '$currency${order.total.toStringAsFixed(2)}',
                  style: pw.TextStyle(font: bold, fontSize: 12)),
            ],
          ),
          _divider(),

          // ── Payment ──────────────────────────────────────────────────
          _amtRow(reg, 'Payment', payment.method.toUpperCase()),
          if (payment.method == AppConstants.paymentMethodCash) ...[
            _amtRow(reg, 'Tendered',
                '$currency${payment.amountTendered.toStringAsFixed(2)}'),
            _amtRow(reg, 'Change',
                '$currency${payment.changeAmount.toStringAsFixed(2)}'),
          ],
          _divider(),

          // ── Footer ───────────────────────────────────────────────────
          if (footer.isNotEmpty)
            pw.Center(
              child: pw.Text(footer,
                  style: pw.TextStyle(font: reg, fontSize: 8)),
            ),
          pw.Center(
            child: pw.Text('Thank you! Visit again.',
                style: pw.TextStyle(font: reg, fontSize: 8)),
          ),
          pw.SizedBox(height: 6),
          _divider(),
          pw.Center(
            child: pw.Text('Developed by: Agentic-Devs',
                style: pw.TextStyle(font: reg, fontSize: 7)),
          ),
          pw.Center(
            child: pw.Text('WhatsApp: +92 313 1248353',
                style: pw.TextStyle(font: reg, fontSize: 7)),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  Future<Uint8List> buildKitchenTicket(OrderModel order) async {
    final bold = pw.Font.helveticaBold();
    final reg = pw.Font.helvetica();

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: _fmt,
        build: (ctx) => [
          pw.Center(
            child: pw.Text('KITCHEN TICKET',
                style: pw.TextStyle(font: bold, fontSize: 16)),
          ),
          _divider(),
          _infoRow(reg, bold, 'Order', order.displayId),
          _infoRow(reg, bold, 'Type', _typeLabel(order.type)),
          if (order.tableName != null)
            _infoRow(reg, bold, 'Table', order.tableName!),
          if (order.customerName != null)
            _infoRow(reg, bold, 'Customer', order.customerName!),
          _divider(),
          ...order.items.map(
            (item) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Text('${item.quantity}×  ',
                          style: pw.TextStyle(font: bold, fontSize: 12)),
                      pw.Expanded(
                        child: pw.Text(item.nameSnapshot,
                            style:
                                pw.TextStyle(font: bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  if (item.note != null && item.note!.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 20),
                      child: pw.Text('→ ${item.note}',
                          style: pw.TextStyle(font: reg, fontSize: 9)),
                    ),
                ],
              ),
            ),
          ),
          if (order.note != null && order.note!.isNotEmpty) ...[
            _divider(),
            pw.Center(
              child: pw.Text('NOTE: ${order.note}',
                  style: pw.TextStyle(font: bold, fontSize: 10)),
            ),
          ],
          _divider(),
          pw.Center(
            child: pw.Text(_fmtDt(order.createdAt),
                style: pw.TextStyle(font: reg, fontSize: 8)),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  pw.Widget _divider() => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Divider(thickness: 0.5),
      );

  pw.Widget _infoRow(
          pw.Font reg, pw.Font bold, String label, String value) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(
          children: [
            pw.SizedBox(
              width: 50,
              child:
                  pw.Text(label, style: pw.TextStyle(font: reg, fontSize: 9)),
            ),
            pw.Text(': ',
                style: pw.TextStyle(font: reg, fontSize: 9)),
            pw.Expanded(
              child: pw.Text(value,
                  style: pw.TextStyle(font: bold, fontSize: 9)),
            ),
          ],
        ),
      );

  pw.Widget _amtRow(pw.Font reg, String label, String value) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(
          children: [
            pw.Text(label, style: pw.TextStyle(font: reg, fontSize: 9)),
            pw.Spacer(),
            pw.Text(value, style: pw.TextStyle(font: reg, fontSize: 9)),
          ],
        ),
      );

  String _fmtDt(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}  $h:$m';
  }

  String _typeLabel(String type) => switch (type) {
        'dine_in' => 'Dine-In',
        'delivery' => 'Delivery',
        _ => 'Takeaway',
      };
}
