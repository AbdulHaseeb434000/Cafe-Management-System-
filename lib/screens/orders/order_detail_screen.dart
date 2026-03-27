import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../../models/order_model.dart';
import '../../providers/order_providers.dart';
import '../../providers/table_providers.dart';
import '../../providers/repository_providers.dart';
import '../../services/printer/printer_service.dart';
import '../../widgets/order_type_badge.dart';
import '../../widgets/confirm_dialog.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  OrderModel? _order;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final order =
        await ref.read(orderRepositoryProvider).getById(widget.orderId);
    if (mounted) setState(() { _order = order; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final order = _order;
    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order')),
        body: const Center(child: Text('Order not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(order.displayId),
        actions: [
          if (order.isActive)
            PopupMenuButton<String>(
              onSelected: (v) => _handleAction(v, order),
              itemBuilder: (_) => [
                if (!order.isPreparing && !order.isReady)
                  const PopupMenuItem(
                      value: 'preparing', child: Text('Mark Preparing')),
                if (order.isPreparing)
                  const PopupMenuItem(
                      value: 'ready', child: Text('Mark Ready')),
                const PopupMenuItem(
                    value: 'print_kitchen', child: Text('Print Kitchen Ticket')),
                const PopupMenuItem(
                    value: 'cancel',
                    child: Text('Cancel Order',
                        style: TextStyle(color: AppColors.error))),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header card
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      OrderTypeBadge(type: order.type),
                      const SizedBox(width: 8),
                      OrderStatusBadge(status: order.status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _row('Order', order.displayId),
                  _row('Date', DateHelpers.formatDateTime(order.createdAt)),
                  if (order.isDineIn && order.tableName != null)
                    _row('Table', order.tableName!),
                  if (order.customerName != null)
                    _row('Customer', order.customerName!),
                  if (order.isDelivery && order.deliveryAddress != null)
                    _row('Address', order.deliveryAddress!),
                  if (order.note != null && order.note!.isNotEmpty)
                    _row('Note', order.note!),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Items
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Items',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ...order.items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('${item.quantity}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.nameSnapshot,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w500)),
                                  if (item.note != null &&
                                      item.note!.isNotEmpty)
                                    Text(item.note!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                                color: AppColors.textSecondary,
                                                fontStyle: FontStyle.italic)),
                                ],
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(item.lineTotal),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Totals
            _card(
              child: Column(
                children: [
                  _totalRow(context, 'Subtotal',
                      CurrencyFormatter.format(order.subtotal)),
                  if (order.discountAmount > 0)
                    _totalRow(context, 'Discount',
                        '- ${CurrencyFormatter.format(order.discountAmount)}',
                        color: AppColors.success),
                  if (order.taxAmount > 0)
                    _totalRow(context,
                        'Tax (${order.taxPercent.toStringAsFixed(1)}%)',
                        CurrencyFormatter.format(order.taxAmount)),
                  const Divider(height: 16),
                  _totalRow(context, 'Total',
                      CurrencyFormatter.format(order.total),
                      bold: true),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (order.isActive && (order.isPending || order.isReady))
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/billing/${order.id}'),
                  icon: const Icon(Icons.point_of_sale),
                  label: const Text('Proceed to Billing'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(String action, OrderModel order) async {
    switch (action) {
      case 'preparing':
        await ref
            .read(orderRepositoryProvider)
            .updateStatus(order.id!, AppConstants.orderStatusPreparing);
        _load();
        ref.read(activeOrdersProvider.notifier).load();
        break;
      case 'ready':
        await ref
            .read(orderRepositoryProvider)
            .updateStatus(order.id!, AppConstants.orderStatusReady);
        _load();
        ref.read(activeOrdersProvider.notifier).load();
        break;
      case 'print_kitchen':
        final settings =
            ref.read(settingsNotifierProvider).valueOrNull ?? {};
        final addr =
            settings[AppConstants.settingKitchenPrinterAddress] ?? '';
        if (addr.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Kitchen printer not configured in Settings')),
            );
          }
          return;
        }
        await PrinterService.instance
            .printKitchenTicket(order: order, printerAddress: addr);
        break;
      case 'cancel':
        final ok = await showConfirmDialog(
          context,
          title: 'Cancel Order',
          message: 'Cancel ${order.displayId}?',
          confirmLabel: 'Yes, Cancel',
          destructive: true,
        );
        if (!ok) return;
        await ref.read(orderRepositoryProvider).cancel(order.id!);
        if (order.tableId != null) {
          final hasOther = await ref
              .read(orderRepositoryProvider)
              .getActiveByTable(order.tableId!);
          if (hasOther == null) {
            await ref
                .read(tableRepositoryProvider)
                .setFree(order.tableId!);
            ref.read(tablesProvider.notifier).load();
          }
        }
        ref.read(activeOrdersProvider.notifier).load();
        if (mounted) context.pop();
        break;
    }
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

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary)),
            ),
            Expanded(
              child: Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );

  Widget _totalRow(BuildContext context, String label, String value,
      {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text(label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
            const Spacer(),
            Text(value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                    color: color)),
          ],
        ),
      );
}
