import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/expense_model.dart';
import '../../providers/repository_providers.dart';
import '../../repositories/activity_log_repository.dart';
import '../../widgets/confirm_dialog.dart';

final _expensesProvider =
    StateNotifierProvider<_ExpensesNotifier, AsyncValue<List<ExpenseModel>>>(
        (ref) => _ExpensesNotifier(ref));

class _ExpensesNotifier
    extends StateNotifier<AsyncValue<List<ExpenseModel>>> {
  final Ref _ref;
  DateTime _from = DateTime.now().copyWith(day: 1, hour: 0, minute: 0, second: 0);
  DateTime _to = DateTime.now().copyWith(hour: 23, minute: 59, second: 59);

  _ExpensesNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  void setRange(DateTime from, DateTime to) {
    _from = from;
    _to = to;
    load();
  }

  DateTime get from => _from;
  DateTime get to => _to;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final expenses = await _ref
          .read(expenseRepositoryProvider)
          .getFiltered(from: _from, to: _to);
      state = AsyncValue.data(expenses);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }
}

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(_expensesProvider.notifier);
    final expensesAsync = ref.watch(_expensesProvider);
    final dateFmt = DateFormat('d MMM');
    final fullFmt = DateFormat('d MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range_outlined),
            tooltip: 'Filter by date',
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDateRange: DateTimeRange(
                  start: notifier.from,
                  end: notifier.to,
                ),
              );
              if (picked != null) {
                notifier.setRange(
                  picked.start,
                  picked.end.copyWith(hour: 23, minute: 59, second: 59),
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showExpenseDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (expenses) {
          final total = expenses.fold<double>(0, (s, e) => s + e.amount);

          return Column(
            children: [
              // Period + total banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: AppColors.surfaceVariant,
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      '${dateFmt.format(notifier.from)} – ${fullFmt.format(notifier.to)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      'Total: ${CurrencyFormatter.format(total)}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                    ),
                  ],
                ),
              ),
              if (expenses.isEmpty)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 48, color: AppColors.textDisabled),
                        SizedBox(height: 12),
                        Text('No expenses recorded',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: expenses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) =>
                        _ExpenseTile(expense: expenses[i], onChanged: notifier.load),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showExpenseDialog(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ExpenseForm(
        onSaved: () => ref.read(_expensesProvider.notifier).load(),
      ),
    );
  }
}

// ── Expense tile ─────────────────────────────────────────────────────────────

class _ExpenseTile extends ConsumerWidget {
  final ExpenseModel expense;
  final VoidCallback onChanged;
  const _ExpenseTile({required this.expense, required this.onChanged});

  static const _categoryColors = <String, Color>{
    'Rent': Color(0xFF5C6BC0),
    'Utilities': Color(0xFF00897B),
    'Salaries': Color(0xFF8D6E63),
    'Supplies': Color(0xFFFF7043),
    'Maintenance': Color(0xFF78909C),
    'Marketing': Color(0xFFAB47BC),
    'Other': Color(0xFF9E9E9E),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _categoryColors[expense.category] ?? AppColors.textSecondary;
    final dateFmt = DateFormat('d MMM yyyy');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_categoryIcon(expense.category), color: color, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                expense.description.isNotEmpty
                    ? expense.description
                    : expense.category,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: Text(
                CurrencyFormatter.format(expense.amount),
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.error),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${expense.category} · ${dateFmt.format(expense.date)}',
          style:
              const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) => _handleAction(context, ref, v),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(
                value: 'delete',
                child: Text('Delete',
                    style: TextStyle(color: AppColors.error))),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, WidgetRef ref, String action) async {
    if (action == 'edit') {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => _ExpenseForm(expense: expense, onSaved: onChanged),
      );
    } else if (action == 'delete') {
      final ok = await showConfirmDialog(context,
          title: 'Delete Expense',
          message: 'Delete this expense?',
          confirmLabel: 'Delete',
          destructive: true);
      if (!ok) return;
      await ref.read(expenseRepositoryProvider).delete(expense.id!);
      final label = expense.description.isNotEmpty
          ? expense.description
          : expense.category;
      ActivityLogRepository.instance.log(
        actionType: 'expense_deleted',
        entityType: 'expense',
        entityName: label,
        details: '${expense.category} · ${expense.amount.toStringAsFixed(2)}',
      );
      onChanged();
    }
  }

  IconData _categoryIcon(String cat) => switch (cat) {
        'Rent' => Icons.home_outlined,
        'Utilities' => Icons.bolt_outlined,
        'Salaries' => Icons.people_outline,
        'Supplies' => Icons.shopping_cart_outlined,
        'Maintenance' => Icons.build_outlined,
        'Marketing' => Icons.campaign_outlined,
        _ => Icons.receipt_outlined,
      };
}

// ── Add / Edit form ───────────────────────────────────────────────────────────

class _ExpenseForm extends ConsumerStatefulWidget {
  final ExpenseModel? expense;
  final VoidCallback onSaved;
  const _ExpenseForm({this.expense, required this.onSaved});

  @override
  ConsumerState<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<_ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  late final TextEditingController _descCtrl;
  late String _category;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
        text: widget.expense != null ? widget.expense!.amount.toStringAsFixed(2) : '');
    _descCtrl = TextEditingController(text: widget.expense?.description ?? '');
    _category = widget.expense?.category ?? ExpenseModel.categories.first;
    _date = widget.expense?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final repo = ref.read(expenseRepositoryProvider);
    final desc = _descCtrl.text.trim();
    final label = desc.isNotEmpty ? desc : _category;

    if (widget.expense == null) {
      await repo.insert(ExpenseModel.create(
        category: _category,
        amount: amount,
        description: desc,
        date: _date,
      ));
      ActivityLogRepository.instance.log(
        actionType: 'expense_created',
        entityType: 'expense',
        entityName: label,
        details: '$_category · ${amount.toStringAsFixed(2)}',
      );
    } else {
      await repo.update(widget.expense!.copyWith(
        category: _category,
        amount: amount,
        description: desc,
        date: _date,
      ));
      ActivityLogRepository.instance.log(
        actionType: 'expense_updated',
        entityType: 'expense',
        entityName: label,
        details: '$_category · ${amount.toStringAsFixed(2)}',
      );
    }
    widget.onSaved();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy');
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.expense == null ? 'Add Expense' : 'Edit Expense',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            // Category
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: ExpenseModel.categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 14),
            // Amount
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixIcon: Icon(Icons.attach_money_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (double.tryParse(v.trim()) == null) return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: 14),
            // Description
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 14),
            // Date picker
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  prefixIcon: Icon(Icons.event_outlined),
                ),
                child: Text(dateFmt.format(_date)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  widget.expense == null ? 'Save Expense' : 'Update Expense',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
