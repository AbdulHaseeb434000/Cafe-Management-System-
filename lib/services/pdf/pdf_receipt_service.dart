import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/constants/app_constants.dart';
import '../../models/order_model.dart';
import '../../models/payment_model.dart';

/// Generates PDF bytes for receipts and kitchen tickets.
///
/// Page height is calculated precisely from content before the PDF is built,
/// so there is no blank space at the bottom — the page is exactly as tall
/// as the receipt content. This makes it efficient for thermal printing.
class PdfReceiptService {
  PdfReceiptService._();
  static final PdfReceiptService instance = PdfReceiptService._();

  static const double _w = 80 * PdfPageFormat.mm;

  // Approximate rendered heights for each element type (in PDF points).
  // Values are font-size × 1.2 (natural line height) + vertical padding.
  static const double _hTitle    = 17.0; // 13pt bold (cafe name)
  static const double _hSmall    = 10.5; // 8pt  (address, phone, footer lines)
  static const double _hInfo     = 13.0; // 9pt  info row (order #, date, type…)
  static const double _hItem     = 15.0; // 9pt  receipt item row (4pt v-padding)
  static const double _hItemNote = 11.5; // 9pt  item note in kitchen ticket
  static const double _hTotal    = 13.0; // 9pt  subtotal / discount / tax row
  static const double _hTotalBig = 17.0; // 12pt TOTAL row
  static const double _hKitItem  = 21.0; // 12pt bold kitchen item (6pt v-padding)
  static const double _hKitHdr   = 20.0; // 16pt KITCHEN TICKET header
  static const double _hNote     = 13.5; // 10pt order-level note
  static const double _hDivider  =  7.0; // Divider with 3pt padding each side
  static const double _hLogoGap  = 64.0; // 60pt image + 4pt SizedBox

  // Margins baked into pageFormat (4 mm each side ≈ 11.3 pt).
  static const double _margin = 4 * PdfPageFormat.mm;

  // ── Page format builders ─────────────────────────────────────────────────

  /// Returns a PdfPageFormat whose height exactly fits [contentPts] of content,
  /// plus a small safety buffer to avoid any edge clipping.
  static PdfPageFormat _fmt(double contentPts) {
    final height = (contentPts * 1.08).clamp(80.0, 2000.0); // 8 % buffer
    return PdfPageFormat(_w, height,
        marginLeft: _margin,
        marginRight: _margin,
        marginTop: _margin,
        marginBottom: _margin);
  }

  /// Calculates the content height (in PDF points) for a customer receipt.
  static double _receiptHeight({
    required OrderModel order,
    required PaymentModel payment,
    required bool hasLogo,
    required String cafeAddress,
    required String cafePhone,
    required String header,
    required String footer,
  }) {
    double h = 0;

    // ── Header block ─────────────────────────────────────────────────────
    if (hasLogo) h += _hLogoGap;
    h += _hTitle;                           // cafe name
    if (cafeAddress.isNotEmpty) h += _hSmall;
    if (cafePhone.isNotEmpty)   h += _hSmall;
    if (header.isNotEmpty)      h += 4 + _hSmall; // SizedBox(4) + header text
    h += _hDivider;

    // ── Order info block ─────────────────────────────────────────────────
    h += _hInfo * 3;  // Order, Date, Type
    if (order.isDineIn && order.tableName != null)        h += _hInfo;
    if (order.customerName != null)                       h += _hInfo;
    if (order.deliveryAddress?.isNotEmpty == true)        h += _hInfo;
    h += _hDivider;

    // ── Items block ──────────────────────────────────────────────────────
    h += order.items.length * _hItem;
    h += _hDivider;

    // ── Totals block ─────────────────────────────────────────────────────
    h += _hTotal;                           // Subtotal
    if (order.discountAmount > 0) h += _hTotal;
    if (order.taxAmount > 0)      h += _hTotal;
    h += 2;                                 // SizedBox(2)
    h += _hTotalBig;                        // TOTAL
    h += _hDivider;

    // ── Payment block ────────────────────────────────────────────────────
    h += _hTotal;                           // Payment method
    if (payment.method == AppConstants.paymentMethodCash) {
      h += _hTotal * 2;                     // Tendered + Change
    }
    h += _hDivider;

    // ── Footer block ─────────────────────────────────────────────────────
    if (footer.isNotEmpty) h += _hSmall;
    h += _hSmall;                           // "Thank you!"
    h += 6;                                 // SizedBox(6)
    h += _hDivider;
    h += _hSmall * 2;                       // developer lines (font 7)

    return h;
  }

  /// Calculates the content height (in PDF points) for a kitchen ticket.
  static double _kitchenHeight(OrderModel order) {
    double h = 0;

    h += _hKitHdr;  // "KITCHEN TICKET"
    h += _hDivider;
    h += _hInfo * 2;  // Order, Type
    if (order.tableName != null)    h += _hInfo;
    if (order.customerName != null) h += _hInfo;
    h += _hDivider;

    for (final item in order.items) {
      h += _hKitItem;
      if (item.note != null && item.note!.isNotEmpty) h += _hItemNote;
    }

    if (order.note != null && order.note!.isNotEmpty) {
      h += _hDivider;
      h += _hNote;
    }

    h += _hDivider;
    h += _hSmall; // timestamp

    return h;
  }

  // ── Public API ───────────────────────────────────────────────────────────

  Future<Uint8List> buildReceipt({
    required OrderModel order,
    required PaymentModel payment,
    required Map<String, String> settings,
  }) async {
    final cafeName    = settings[AppConstants.settingCafeName]       ?? 'My Cafe';
    final cafeAddress = settings[AppConstants.settingCafeAddress]    ?? '';
    final cafePhone   = settings[AppConstants.settingCafePhone]      ?? '';
    final header      = settings[AppConstants.settingReceiptHeader]  ?? '';
    final footer      = settings[AppConstants.settingReceiptFooter]  ?? '';
    final currency    = settings[AppConstants.settingCurrencySymbol] ??
        AppConstants.defaultCurrencySymbol;
    final logoPath    = settings[AppConstants.settingLogoPath]       ?? '';

    pw.ImageProvider? logo;
    if (logoPath.isNotEmpty) {
      final file = File(logoPath);
      if (await file.exists()) {
        logo = pw.MemoryImage(await file.readAsBytes());
      }
    }

    final bold = pw.Font.helveticaBold();
    final reg  = pw.Font.helvetica();

    // Calculate exact page height before building the PDF.
    final fmt = _fmt(_receiptHeight(
      order: order,
      payment: payment,
      hasLogo: logo != null,
      cafeAddress: cafeAddress,
      cafePhone: cafePhone,
      header: header,
      footer: footer,
    ));

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: fmt,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── Cafe header ────────────────────────────────────────────
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

            // ── Order info ─────────────────────────────────────────────
            _infoRow(reg, bold, 'Order',    order.displayId),
            _infoRow(reg, bold, 'Date',     _fmtDt(order.createdAt)),
            _infoRow(reg, bold, 'Type',     _typeLabel(order.type)),
            if (order.isDineIn && order.tableName != null)
              _infoRow(reg, bold, 'Table',    order.tableName!),
            if (order.customerName != null)
              _infoRow(reg, bold, 'Customer', order.customerName!),
            if (order.deliveryAddress != null &&
                order.deliveryAddress!.isNotEmpty)
              _infoRow(reg, bold, 'Address', order.deliveryAddress!),
            _divider(),

            // ── Items ──────────────────────────────────────────────────
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
                    pw.Text('$currency${item.lineTotal.toStringAsFixed(2)}',
                        style: pw.TextStyle(font: reg, fontSize: 9)),
                  ],
                ),
              ),
            ),
            _divider(),

            // ── Totals ─────────────────────────────────────────────────
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
                pw.Text('$currency${order.total.toStringAsFixed(2)}',
                    style: pw.TextStyle(font: bold, fontSize: 12)),
              ],
            ),
            _divider(),

            // ── Payment ────────────────────────────────────────────────
            _amtRow(reg, 'Payment', payment.method.toUpperCase()),
            if (payment.method == AppConstants.paymentMethodCash) ...[
              _amtRow(reg, 'Tendered',
                  '$currency${payment.amountTendered.toStringAsFixed(2)}'),
              _amtRow(reg, 'Change',
                  '$currency${payment.changeAmount.toStringAsFixed(2)}'),
            ],
            _divider(),

            // ── Footer ─────────────────────────────────────────────────
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
      ),
    );
    return pdf.save();
  }

  Future<Uint8List> buildKitchenTicket(OrderModel order) async {
    final bold = pw.Font.helveticaBold();
    final reg  = pw.Font.helvetica();

    final fmt = _fmt(_kitchenHeight(order));

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: fmt,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Text('KITCHEN TICKET',
                  style: pw.TextStyle(font: bold, fontSize: 16)),
            ),
            _divider(),
            _infoRow(reg, bold, 'Order', order.displayId),
            _infoRow(reg, bold, 'Type',  _typeLabel(order.type)),
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
                              style: pw.TextStyle(font: bold, fontSize: 12)),
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
      ),
    );
    return pdf.save();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  pw.Widget _divider() => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Divider(thickness: 0.5),
      );

  pw.Widget _infoRow(pw.Font reg, pw.Font bold, String label, String value) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(
          children: [
            pw.SizedBox(
              width: 50,
              child: pw.Text(label,
                  style: pw.TextStyle(font: reg, fontSize: 9)),
            ),
            pw.Text(': ', style: pw.TextStyle(font: reg, fontSize: 9)),
            pw.Expanded(
              child: pw.Text(value,
                  style: pw.TextStyle(font: bold, fontSize: 9)),
            ),
          ],
        ),
      );

  pw.Widget _amtRow(pw.Font reg, String label, String value) => pw.Padding(
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
        'dine_in'  => 'Dine-In',
        'delivery' => 'Delivery',
        _          => 'Takeaway',
      };
}
