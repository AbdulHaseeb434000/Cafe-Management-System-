import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../../models/order_model.dart';
import '../../models/payment_model.dart';
import '../../providers/order_providers.dart';
import '../../providers/table_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/settings_providers.dart';
import '../../services/printer/printer_service.dart';

class BillingScreen extends ConsumerStatefulWidget {
  final int orderId;
  const BillingScreen({super.key, required this.orderId});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  OrderModel? _order;
  bool _loading = true;

  // Discount
  String _discountType = AppConstants.discountTypeFlat;
  final _discountCtrl = TextEditingController(text: '0');

  // Payment
  String _paymentMethod = AppConstants.paymentMethodCash;
  final _tenderedCtrl = TextEditingController();

  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _load();
    _discountCtrl.addListener(_recalculate);
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    _tenderedCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final order =
        await ref.read(orderRepositoryProvider).getById(widget.orderId);
    if (!mounted) return;
    // Guard: if order is already completed/cancelled, leave billing screen
    if (order == null ||
        order.status == AppConstants.orderStatusCompleted ||
        order.status == AppConstants.orderStatusCancelled) {
      context.go('/orders');
      return;
    }
    setState(() {
      _order = order;
      _loading = false;
    });
    _recalculate();
  }

  double get _subtotal => _order?.subtotal ?? 0;

  double get _discountValue =>
      double.tryParse(_discountCtrl.text.trim()) ?? 0;

  double get _discountAmount {
    if (_discountType == AppConstants.discountTypePercent) {
      return (_subtotal * _discountValue / 100)
          .clamp(0, _subtotal);
    }
    return _discountValue.clamp(0, _subtotal);
  }

  double get _taxPercent {
    final settings =
        ref.read(settingsNotifierProvider).valueOrNull ?? {};
    return double.tryParse(
            settings[AppConstants.settingTaxPercent] ?? '0') ??
        0;
  }

  double get _taxableAmount => _subtotal - _discountAmount;
  double get _taxAmount => _taxableAmount * _taxPercent / 100;
  double get _total => _taxableAmount + _taxAmount;

  double get _change {
    final tendered =
        double.tryParse(_tenderedCtrl.text.trim()) ?? 0;
    return (tendered - _total).clamp(0, double.infinity);
  }

  void _recalculate() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    final order = _order;
    if (order == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Billing')),
          body: const Center(child: Text('Order not found')));
    }

    return Scaffold(
      appBar: AppBar(title: Text('Bill — ${order.displayId}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Items summary
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order Items',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ...order.items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Text('${item.quantity}×',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(item.nameSnapshot,
                                    style: const TextStyle(fontSize: 13))),
                            Text(
                              CurrencyFormatter.format(item.lineTotal),
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      )),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(CurrencyFormatter.format(_subtotal),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Discount
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Discount',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ToggleButton(
                          label: 'Flat (Rs.)',
                          selected: _discountType ==
                              AppConstants.discountTypeFlat,
                          onTap: () => setState(() {
                            _discountType =
                                AppConstants.discountTypeFlat;
                            _discountCtrl.text = '0';
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ToggleButton(
                          label: 'Percent (%)',
                          selected: _discountType ==
                              AppConstants.discountTypePercent,
                          onTap: () => setState(() {
                            _discountType =
                                AppConstants.discountTypePercent;
                            _discountCtrl.text = '0';
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _discountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      labelText: _discountType ==
                              AppConstants.discountTypeFlat
                          ? 'Discount Amount'
                          : 'Discount %',
                      suffixText: _discountType ==
                              AppConstants.discountTypePercent
                          ? '%'
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Totals
            _card(
              child: Column(
                children: [
                  _totalRow('Subtotal', CurrencyFormatter.format(_subtotal)),
                  if (_discountAmount > 0)
                    _totalRow('Discount',
                        '- ${CurrencyFormatter.format(_discountAmount)}',
                        color: AppColors.success),
                  if (_taxAmount > 0)
                    _totalRow(
                        'Tax (${_taxPercent.toStringAsFixed(1)}%)',
                        CurrencyFormatter.format(_taxAmount)),
                  const Divider(height: 16),
                  _totalRow('TOTAL', CurrencyFormatter.format(_total),
                      bold: true),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Payment method
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payment Method',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ToggleButton(
                          label: 'Cash',
                          icon: Icons.payments_outlined,
                          selected: _paymentMethod ==
                              AppConstants.paymentMethodCash,
                          onTap: () => setState(() => _paymentMethod =
                              AppConstants.paymentMethodCash),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ToggleButton(
                          label: 'Card',
                          icon: Icons.credit_card_outlined,
                          selected: _paymentMethod ==
                              AppConstants.paymentMethodCard,
                          onTap: () => setState(() => _paymentMethod =
                              AppConstants.paymentMethodCard),
                        ),
                      ),
                    ],
                  ),
                  if (_paymentMethod == AppConstants.paymentMethodCash) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tenderedCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Amount Tendered',
                          prefixText: 'Rs. '),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_tenderedCtrl.text.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color:
                                  AppColors.success.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Change',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success)),
                            Text(
                              CurrencyFormatter.format(_change),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  color: AppColors.success),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _processing ? null : _completePayment,
                icon: _processing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline),
                label: Text(_processing
                    ? 'Processing...'
                    : 'Complete Payment'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _completePayment() async {
    final order = _order;
    if (order == null) return;

    if (_paymentMethod == AppConstants.paymentMethodCash) {
      final tendered =
          double.tryParse(_tenderedCtrl.text.trim()) ?? 0;
      if (tendered < _total) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Amount tendered is less than total')),
        );
        return;
      }
    }

    setState(() => _processing = true);

    final orderRepo = ref.read(orderRepositoryProvider);
    final payRepo = ref.read(paymentRepositoryProvider);
    final tableRepo = ref.read(tableRepositoryProvider);

    // Update order totals & status
    final updated = order.copyWith(
      discountType: _discountAmount > 0 ? _discountType : null,
      discountValue: _discountValue,
      discountAmount: _discountAmount,
      taxPercent: _taxPercent,
      taxAmount: _taxAmount,
      subtotal: _subtotal,
      total: _total,
      status: AppConstants.orderStatusCompleted,
    );
    await orderRepo.update(updated);

    // Record payment
    final tendered = _paymentMethod == AppConstants.paymentMethodCash
        ? (double.tryParse(_tenderedCtrl.text.trim()) ?? _total)
        : _total;
    await payRepo.insert(PaymentModel.create(
      orderId: order.id!,
      orderUuid: order.uuid,
      method: _paymentMethod,
      amountTendered: tendered,
      changeAmount: _paymentMethod == AppConstants.paymentMethodCash
          ? _change
          : 0,
    ));

    // Free the table
    if (order.tableId != null) {
      final hasOther =
          await orderRepo.getActiveByTable(order.tableId!);
      if (hasOther == null) {
        await tableRepo.setFree(order.tableId!);
        ref.read(tablesProvider.notifier).load();
      }
    }

    ref.read(activeOrdersProvider.notifier).load();

    if (!mounted) return;
    setState(() => _processing = false);
    _showReceiptDialog(updated);
  }

  void _showReceiptDialog(OrderModel order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 22),
            const SizedBox(width: 8),
            const Text('Payment Complete'),
          ],
        ),
        content: const Text('Receipt options:'),
        actions: [
          // Skip — go to orders
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/orders');
            },
            child: const Text('Skip'),
          ),
          // Share as text
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _shareReceipt(order);
              if (mounted) context.go('/orders');
            },
            icon: const Icon(Icons.share, size: 16),
            label: const Text('Share'),
          ),
          // Print
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _printReceipt(order);
              if (mounted) context.go('/orders');
            },
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Print'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareReceipt(OrderModel order) async {
    final settings = ref.read(settingsNotifierProvider).valueOrNull ?? {};
    final payment =
        await ref.read(paymentRepositoryProvider).getByOrderId(order.id!);

    final cafeName =
        settings[AppConstants.settingCafeName] ?? 'My Cafe';
    final cafeAddress = settings[AppConstants.settingCafeAddress] ?? '';
    final cafePhone = settings[AppConstants.settingCafePhone] ?? '';
    final header = settings[AppConstants.settingReceiptHeader] ?? '';
    final footer = settings[AppConstants.settingReceiptFooter] ?? '';
    final currency = settings[AppConstants.settingCurrencySymbol] ??
        AppConstants.defaultCurrencySymbol;

    final sep = '─' * 32;
    final buf = StringBuffer();

    buf.writeln(sep);
    buf.writeln(cafeName.toUpperCase());
    if (cafeAddress.isNotEmpty) buf.writeln(cafeAddress);
    if (cafePhone.isNotEmpty) buf.writeln('Tel: $cafePhone');
    if (header.isNotEmpty) buf.writeln(header);
    buf.writeln(sep);
    buf.writeln('Order : ${order.displayId}');
    buf.writeln('Date  : ${DateHelpers.formatDateTime(order.createdAt)}');
    buf.writeln('Type  : ${order.type.replaceAll('_', '-').toUpperCase()}');
    if (order.displayLabel.isNotEmpty) buf.writeln('Info  : ${order.displayLabel}');
    buf.writeln(sep);

    for (final item in order.items) {
      final name = item.nameSnapshot.length > 18
          ? '${item.nameSnapshot.substring(0, 17)}…'
          : item.nameSnapshot;
      final price = '$currency${CurrencyFormatter.formatRaw(item.lineTotal)}';
      final qty = '${item.quantity}x $name';
      buf.writeln('${qty.padRight(24)}${price.padLeft(8)}');
    }

    buf.writeln(sep);
    buf.writeln(
        '${'Subtotal'.padRight(24)}${('$currency${CurrencyFormatter.formatRaw(_subtotal)}').padLeft(8)}');
    if (_discountAmount > 0) {
      buf.writeln(
          '${'Discount'.padRight(24)}${('-$currency${CurrencyFormatter.formatRaw(_discountAmount)}').padLeft(8)}');
    }
    if (_taxAmount > 0) {
      buf.writeln(
          '${'Tax (${_taxPercent.toStringAsFixed(1)}%)'.padRight(24)}${('$currency${CurrencyFormatter.formatRaw(_taxAmount)}').padLeft(8)}');
    }
    buf.writeln(sep);
    buf.writeln(
        '${'TOTAL'.padRight(24)}${('$currency${CurrencyFormatter.formatRaw(_total)}').padLeft(8)}');
    buf.writeln(sep);

    if (payment != null) {
      buf.writeln('Payment : ${payment.method.toUpperCase()}');
      if (payment.method == AppConstants.paymentMethodCash) {
        buf.writeln(
            '${'Tendered'.padRight(24)}${('$currency${CurrencyFormatter.formatRaw(payment.amountTendered)}').padLeft(8)}');
        buf.writeln(
            '${'Change'.padRight(24)}${('$currency${CurrencyFormatter.formatRaw(payment.changeAmount)}').padLeft(8)}');
      }
    }

    buf.writeln(sep);
    if (footer.isNotEmpty) buf.writeln(footer);
    buf.writeln('Thank you! Visit again.');
    buf.writeln(sep);
    buf.writeln('Developed by : Agentic-Devs');
    buf.writeln('WhatsApp     : +92 313 1248353');
    buf.writeln(sep);

    await SharePlus.instance.share(ShareParams(
      text: buf.toString(),
      subject: 'Receipt — ${order.displayId} — $cafeName',
    ));
  }

  Future<void> _printReceipt(OrderModel order) async {
    final settings =
        ref.read(settingsNotifierProvider).valueOrNull ?? {};
    final addr =
        settings[AppConstants.settingPosPrinterAddress] ?? '';
    if (addr.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('POS printer not configured in Settings')),
        );
      }
      return;
    }
    final payment =
        await ref.read(paymentRepositoryProvider).getByOrderId(order.id!);
    if (payment == null) return;

    await PrinterService.instance.printReceipt(
      order: order,
      payment: payment,
      cafeName: settings[AppConstants.settingCafeName] ?? 'My Cafe',
      cafeAddress: settings[AppConstants.settingCafeAddress] ?? '',
      cafePhone: settings[AppConstants.settingCafePhone] ?? '',
      header: settings[AppConstants.settingReceiptHeader] ?? '',
      footer: settings[AppConstants.settingReceiptFooter] ?? '',
      currencySymbol: settings[AppConstants.settingCurrencySymbol] ??
          AppConstants.defaultCurrencySymbol,
      printerAddress: addr,
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: child,
      );

  Widget _totalRow(String label, String value,
      {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text(label,
                style: TextStyle(
                    fontWeight:
                        bold ? FontWeight.w700 : FontWeight.normal,
                    fontSize: bold ? 16 : 14)),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: bold ? 16 : 14,
                    color: color)),
          ],
        ),
      );
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color:
                selected ? AppColors.primary : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selected
                    ? AppColors.primary
                    : AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 16,
                    color: selected
                        ? Colors.white
                        : AppColors.textSecondary),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: TextStyle(
                      color: selected
                          ? Colors.white
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
          ),
        ),
      );
}
