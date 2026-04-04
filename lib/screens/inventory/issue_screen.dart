import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../models/inventory_item_model.dart';
import '../../providers/inventory_providers.dart';

class IssueScreen extends ConsumerStatefulWidget {
  const IssueScreen({super.key});

  @override
  ConsumerState<IssueScreen> createState() => _IssueScreenState();
}

class _IssueScreenState extends ConsumerState<IssueScreen> {
  final _formKey = GlobalKey<FormState>();
  InventoryItemModel? _selectedItem;
  final _qtyCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final item = _selectedItem;
    if (item == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select an item')));
      return;
    }
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Quantity must be > 0')));
      return;
    }
    if (qty > item.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Insufficient stock (available: ${item.quantity} ${item.unit})')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(inventoryProvider.notifier).issue(
            item,
            quantity: qty,
            reason: _reasonCtrl.text.trim().isEmpty
                ? null
                : _reasonCtrl.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Issued ${qty.toStringAsFixed(2)} ${item.unit} of ${item.name}'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Issue to Kitchen')),
      body: inventoryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Item selector
                  DropdownButtonFormField<InventoryItemModel>(
                    value: _selectedItem,
                    decoration: const InputDecoration(
                      labelText: 'Item *',
                      border: OutlineInputBorder(),
                    ),
                    items: items
                        .map((item) => DropdownMenuItem(
                              value: item,
                              child: Text(
                                  '${item.name} (${item.quantity} ${item.unit} available)'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedItem = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Quantity issued
                  TextFormField(
                    controller: _qtyCtrl,
                    decoration: InputDecoration(
                      labelText: 'Quantity Issued *',
                      border: const OutlineInputBorder(),
                      suffixText: _selectedItem?.unit ?? '',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if ((double.tryParse(v.trim()) ?? 0) <= 0) {
                        return 'Must be greater than 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Reason / note
                  TextFormField(
                    controller: _reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Reason / Note (optional)',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Issue to Kitchen'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
