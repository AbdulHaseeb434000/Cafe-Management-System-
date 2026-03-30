import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/order_model.dart';
import '../../providers/order_providers.dart';
import '../../providers/repository_providers.dart';
import '../../services/pdf/pdf_receipt_service.dart';
import '../../screens/receipt/receipt_preview_screen.dart';
import '../../widgets/order_type_badge.dart';
import '../../widgets/empty_state.dart';

class KitchenScreen extends ConsumerWidget {
  const KitchenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(activeOrdersProvider);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitchen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.read(activeOrdersProvider.notifier).load(),
          ),
        ],
      ),
      body: activeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (orders) {
          final kitchenOrders = orders
              .where((o) =>
                  o.isPending || o.isPreparing || o.isReady)
              .toList();

          if (kitchenOrders.isEmpty) {
            return const EmptyState(
              icon: Icons.soup_kitchen_outlined,
              title: 'Kitchen is clear',
              subtitle: 'No active orders to prepare',
            );
          }

          final pending =
              kitchenOrders.where((o) => o.isPending).toList();
          final preparing =
              kitchenOrders.where((o) => o.isPreparing).toList();
          final ready = kitchenOrders.where((o) => o.isReady).toList();

          if (isTablet) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: _Column(
                        title: 'Pending',
                        color: AppColors.statusPending,
                        orders: pending)),
                const VerticalDivider(width: 1),
                Expanded(
                    child: _Column(
                        title: 'Preparing',
                        color: AppColors.statusPreparing,
                        orders: preparing)),
                const VerticalDivider(width: 1),
                Expanded(
                    child: _Column(
                        title: 'Ready',
                        color: AppColors.statusReady,
                        orders: ready)),
              ],
            );
          }

          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                TabBar(
                  labelColor: AppColors.primaryDark,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  tabs: [
                    Tab(text: 'Pending (${pending.length})'),
                    Tab(text: 'Preparing (${preparing.length})'),
                    Tab(text: 'Ready (${ready.length})'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _Column(
                          title: 'Pending',
                          color: AppColors.statusPending,
                          orders: pending),
                      _Column(
                          title: 'Preparing',
                          color: AppColors.statusPreparing,
                          orders: preparing),
                      _Column(
                          title: 'Ready',
                          color: AppColors.statusReady,
                          orders: ready),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Column extends StatelessWidget {
  final String title;
  final Color color;
  final List<OrderModel> orders;

  const _Column(
      {required this.title,
      required this.color,
      required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Text('No $title orders',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _KitchenCard(order: orders[i]),
    );
  }
}

class _KitchenCard extends ConsumerWidget {
  final OrderModel order;
  const _KitchenCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elapsed =
        DateTime.now().difference(order.createdAt);
    final elapsedStr = elapsed.inMinutes > 0
        ? '${elapsed.inMinutes}m ago'
        : 'Just now';
    final isUrgent = elapsed.inMinutes >= 15 && order.isPending;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUrgent ? AppColors.error : AppColors.divider,
          width: isUrgent ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isUrgent
                  ? AppColors.error.withValues(alpha: 0.08)
                  : AppColors.surfaceVariant,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Text(order.displayId,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                OrderTypeBadge(type: order.type, small: true),
                const Spacer(),
                Icon(Icons.timer_outlined,
                    size: 14,
                    color: isUrgent
                        ? AppColors.error
                        : AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(elapsedStr,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isUrgent
                            ? AppColors.error
                            : AppColors.textSecondary)),
              ],
            ),
          ),
          // Sub-info
          if (order.tableName != null || order.customerName != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(
                order.displayLabel,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600),
              ),
            ),
          // Items
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: order.items
                  .map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('${item.quantity}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryDark)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(item.nameSnapshot,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          if (order.note != null && order.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Text('Note: ${order.note}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppColors.brown)),
            ),
          const Divider(height: 1),
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // Print kitchen ticket
                IconButton(
                  onPressed: () => _printTicket(context, ref),
                  icon: const Icon(Icons.print_outlined, size: 20),
                  tooltip: 'Print Kitchen Ticket',
                  style: IconButton.styleFrom(
                      foregroundColor: AppColors.textSecondary),
                ),
                // View order
                IconButton(
                  onPressed: () =>
                      context.push('/orders/${order.id}'),
                  icon: const Icon(Icons.open_in_new, size: 20),
                  tooltip: 'View Order',
                  style: IconButton.styleFrom(
                      foregroundColor: AppColors.textSecondary),
                ),
                const Spacer(),
                // Status advance button
                if (order.isPending)
                  _ActionButton(
                    label: 'Start Preparing',
                    color: AppColors.statusPreparing,
                    onTap: () => _advance(
                        ref, AppConstants.orderStatusPreparing),
                  ),
                if (order.isPreparing)
                  _ActionButton(
                    label: 'Mark Ready',
                    color: AppColors.statusReady,
                    onTap: () =>
                        _advance(ref, AppConstants.orderStatusReady),
                  ),
                if (order.isReady)
                  _ActionButton(
                    label: 'Go to Billing',
                    color: AppColors.primary,
                    onTap: () =>
                        context.push('/billing/${order.id}'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _advance(WidgetRef ref, String status) async {
    await ref
        .read(orderRepositoryProvider)
        .updateStatus(order.id!, status);
    ref.read(activeOrdersProvider.notifier).load();
  }

  Future<void> _printTicket(BuildContext context, WidgetRef ref) async {
    final pdfBytes =
        await PdfReceiptService.instance.buildKitchenTicket(order);
    if (!context.mounted) return;
    // Lock the order to signal kitchen is preparing
    await ref.read(orderRepositoryProvider).setLocked(order.id!, locked: true);
    ref.read(activeOrdersProvider.notifier).load();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiptPreviewScreen(
          pdfBytes: pdfBytes,
          filename:
              'kitchen_${order.displayId.replaceAll('#', '')}.pdf',
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color)),
      );
}
