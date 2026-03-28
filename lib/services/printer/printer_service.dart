import 'dart:io';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../models/order_model.dart';
import '../../models/payment_model.dart';

class PrinterService {
  PrinterService._();
  static final PrinterService instance = PrinterService._();

  Future<List<BluetoothInfo>> scanDevices() async {
    try {
      final paired = await PrintBluetoothThermal.pairedBluetooths;
      return paired;
    } catch (_) {
      return [];
    }
  }

  Future<bool> connect(String address) async {
    try {
      return PrintBluetoothThermal.connect(macPrinterAddress: address);
    } catch (_) {
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {}
  }

  Future<bool> get isConnected async {
    try {
      return PrintBluetoothThermal.connectionStatus;
    } catch (_) {
      return false;
    }
  }

  // ── Receipt printing ─────────────────────────────────────────────────

  Future<bool> printReceipt({
    required OrderModel order,
    required PaymentModel payment,
    required String cafeName,
    required String cafeAddress,
    required String cafePhone,
    required String header,
    required String footer,
    required String currencySymbol,
    required String printerAddress,
    String logoPath = '',
  }) async {
    try {
      final connected = await connect(printerAddress);
      if (!connected) return false;

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      final bytes = <int>[];

      bytes.addAll(generator.setGlobalCodeTable('CP1252'));

      // Print logo if set
      if (logoPath.isNotEmpty) {
        final logoFile = File(logoPath);
        if (await logoFile.exists()) {
          final rawBytes = await logoFile.readAsBytes();
          final decoded = img.decodeImage(rawBytes);
          if (decoded != null) {
            final resized = img.copyResize(decoded, width: 200);
            bytes.addAll(generator.image(resized,
                align: PosAlign.center));
            bytes.addAll(generator.emptyLines(1));
          }
        }
      }

      bytes.addAll(generator.text(cafeName,
          styles: const PosStyles(
              bold: true,
              align: PosAlign.center,
              height: PosTextSize.size2,
              width: PosTextSize.size2)));
      if (cafeAddress.isNotEmpty) {
        bytes.addAll(generator.text(cafeAddress,
            styles: const PosStyles(align: PosAlign.center)));
      }
      if (cafePhone.isNotEmpty) {
        bytes.addAll(generator.text('Tel: $cafePhone',
            styles: const PosStyles(align: PosAlign.center)));
      }
      bytes.addAll(generator.hr());

      if (header.isNotEmpty) {
        bytes.addAll(generator.text(header,
            styles: const PosStyles(align: PosAlign.center)));
        bytes.addAll(generator.emptyLines(1));
      }

      bytes.addAll(generator.row([
        PosColumn(text: 'Order', width: 4,
            styles: const PosStyles(bold: true)),
        PosColumn(text: order.displayId, width: 8,
            styles: const PosStyles(align: PosAlign.right)),
      ]));
      bytes.addAll(generator.row([
        PosColumn(text: 'Type', width: 4, styles: const PosStyles(bold: true)),
        PosColumn(text: _typeLabel(order.type), width: 8,
            styles: const PosStyles(align: PosAlign.right)),
      ]));
      if (order.isDineIn && order.tableName != null) {
        bytes.addAll(generator.row([
          PosColumn(text: 'Table', width: 4, styles: const PosStyles(bold: true)),
          PosColumn(text: order.tableName!, width: 8,
              styles: const PosStyles(align: PosAlign.right)),
        ]));
      }
      if (order.customerName != null) {
        bytes.addAll(generator.row([
          PosColumn(text: 'Customer', width: 4, styles: const PosStyles(bold: true)),
          PosColumn(text: order.customerName!, width: 8,
              styles: const PosStyles(align: PosAlign.right)),
        ]));
      }
      bytes.addAll(generator.hr());

      // Items
      bytes.addAll(generator.text('Items',
          styles: const PosStyles(bold: true)));
      for (final item in order.items) {
        bytes.addAll(generator.row([
          PosColumn(
              text: '${item.quantity}x ${item.nameSnapshot}', width: 9),
          PosColumn(
              text: '$currencySymbol ${item.lineTotal.toStringAsFixed(2)}',
              width: 3,
              styles: const PosStyles(align: PosAlign.right)),
        ]));
      }
      bytes.addAll(generator.hr());

      // Totals
      bytes.addAll(generator.row([
        PosColumn(text: 'Subtotal', width: 8),
        PosColumn(
            text: '$currencySymbol ${order.subtotal.toStringAsFixed(2)}',
            width: 4,
            styles: const PosStyles(align: PosAlign.right)),
      ]));
      if (order.discountAmount > 0) {
        bytes.addAll(generator.row([
          PosColumn(text: 'Discount', width: 8),
          PosColumn(
              text: '-$currencySymbol ${order.discountAmount.toStringAsFixed(2)}',
              width: 4,
              styles: const PosStyles(align: PosAlign.right)),
        ]));
      }
      if (order.taxAmount > 0) {
        bytes.addAll(generator.row([
          PosColumn(
              text: 'Tax (${order.taxPercent.toStringAsFixed(1)}%)', width: 8),
          PosColumn(
              text: '$currencySymbol ${order.taxAmount.toStringAsFixed(2)}',
              width: 4,
              styles: const PosStyles(align: PosAlign.right)),
        ]));
      }
      bytes.addAll(generator.hr());
      bytes.addAll(generator.row([
        PosColumn(
            text: 'TOTAL',
            width: 6,
            styles: const PosStyles(bold: true, height: PosTextSize.size2)),
        PosColumn(
            text: '$currencySymbol ${order.total.toStringAsFixed(2)}',
            width: 6,
            styles: const PosStyles(
                bold: true,
                align: PosAlign.right,
                height: PosTextSize.size2)),
      ]));
      bytes.addAll(generator.hr());

      bytes.addAll(generator.row([
        PosColumn(text: 'Payment', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: payment.method.toUpperCase(), width: 6,
            styles: const PosStyles(align: PosAlign.right)),
      ]));
      if (payment.method == 'cash' && payment.changeAmount > 0) {
        bytes.addAll(generator.row([
          PosColumn(text: 'Change', width: 6),
          PosColumn(
              text: '$currencySymbol ${payment.changeAmount.toStringAsFixed(2)}',
              width: 6,
              styles: const PosStyles(align: PosAlign.right)),
        ]));
      }

      if (footer.isNotEmpty) {
        bytes.addAll(generator.emptyLines(1));
        bytes.addAll(generator.text(footer,
            styles: const PosStyles(align: PosAlign.center)));
      }

      bytes.addAll(generator.emptyLines(1));
      bytes.addAll(generator.hr());
      bytes.addAll(generator.text('Developed by: Agentic-Devs',
          styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.text('WhatsApp: +92 313 1248353',
          styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.emptyLines(3));
      bytes.addAll(generator.cut());

      return PrintBluetoothThermal.writeBytes(bytes);
    } catch (_) {
      return false;
    }
  }

  // ── Kitchen ticket printing ──────────────────────────────────────────

  Future<bool> printKitchenTicket({
    required OrderModel order,
    required String printerAddress,
  }) async {
    try {
      final connected = await connect(printerAddress);
      if (!connected) return false;

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      final bytes = <int>[];

      bytes.addAll(generator.setGlobalCodeTable('CP1252'));
      bytes.addAll(generator.text('** KITCHEN TICKET **',
          styles: const PosStyles(
              bold: true,
              align: PosAlign.center,
              height: PosTextSize.size2)));
      bytes.addAll(generator.hr());

      bytes.addAll(generator.row([
        PosColumn(
            text: order.displayId,
            width: 6,
            styles: const PosStyles(bold: true, height: PosTextSize.size2)),
        PosColumn(
            text: _typeLabel(order.type),
            width: 6,
            styles: const PosStyles(
                align: PosAlign.right, height: PosTextSize.size2)),
      ]));

      if (order.isDineIn && order.tableName != null) {
        bytes.addAll(generator.text('Table: ${order.tableName}',
            styles: const PosStyles(bold: true)));
      }
      if (order.isDelivery && order.customerName != null) {
        bytes.addAll(generator.text('Customer: ${order.customerName}',
            styles: const PosStyles(bold: true)));
      }

      bytes.addAll(generator.hr());
      bytes.addAll(generator.text('ITEMS:',
          styles: const PosStyles(bold: true)));

      for (final item in order.items) {
        bytes.addAll(generator.text(
            '${item.quantity}x  ${item.nameSnapshot}',
            styles: const PosStyles(height: PosTextSize.size2)));
        if (item.note != null && item.note!.isNotEmpty) {
          bytes.addAll(generator.text('   Note: ${item.note}',
              styles: const PosStyles(bold: false)));
        }
      }

      if (order.note != null && order.note!.isNotEmpty) {
        bytes.addAll(generator.hr());
        bytes.addAll(generator.text('Order Note: ${order.note}',
            styles: const PosStyles(bold: true)));
      }

      final time = DateTime.now();
      final timeStr =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      bytes.addAll(generator.hr());
      bytes.addAll(generator.text(timeStr,
          styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.emptyLines(3));
      bytes.addAll(generator.cut());

      return PrintBluetoothThermal.writeBytes(bytes);
    } catch (_) {
      return false;
    }
  }

  String _typeLabel(String type) {
    return switch (type) {
      'dine_in' => 'Dine-In',
      'delivery' => 'Delivery',
      _ => 'Takeaway',
    };
  }
}
