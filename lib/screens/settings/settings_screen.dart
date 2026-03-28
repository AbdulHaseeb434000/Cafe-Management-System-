import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_helpers.dart';
import '../../models/table_model.dart';
import '../../providers/settings_providers.dart';
import '../../providers/table_providers.dart';
import '../../services/backup/backup_service.dart';
import '../../core/database/database_helper.dart';
import '../../services/printer/printer_service.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/section_header.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (settings) => ListView(
          children: [
            const SectionHeader(title: 'Cafe Info'),
            _LogoTile(settings: settings),
            _SettingsTile(
              icon: Icons.store_outlined,
              label: 'Cafe Name',
              value: settings[AppConstants.settingCafeName] ?? 'My Cafe',
              onTap: () => _editSetting(
                context,
                key: AppConstants.settingCafeName,
                label: 'Cafe Name',
                current: settings[AppConstants.settingCafeName] ?? '',
              ),
            ),
            _SettingsTile(
              icon: Icons.location_on_outlined,
              label: 'Address',
              value: settings[AppConstants.settingCafeAddress]?.isEmpty ?? true
                  ? 'Not set'
                  : settings[AppConstants.settingCafeAddress]!,
              onTap: () => _editSetting(
                context,
                key: AppConstants.settingCafeAddress,
                label: 'Address',
                current: settings[AppConstants.settingCafeAddress] ?? '',
                maxLines: 2,
              ),
            ),
            _SettingsTile(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: settings[AppConstants.settingCafePhone]?.isEmpty ?? true
                  ? 'Not set'
                  : settings[AppConstants.settingCafePhone]!,
              onTap: () => _editSetting(
                context,
                key: AppConstants.settingCafePhone,
                label: 'Phone',
                current: settings[AppConstants.settingCafePhone] ?? '',
                inputType: TextInputType.phone,
              ),
            ),

            const SectionHeader(title: 'Billing'),
            _SettingsTile(
              icon: Icons.percent_outlined,
              label: 'Tax Rate',
              value: '${settings[AppConstants.settingTaxPercent] ?? '0'}%',
              onTap: () => _editSetting(
                context,
                key: AppConstants.settingTaxPercent,
                label: 'Tax Rate (%)',
                current: settings[AppConstants.settingTaxPercent] ?? '0',
                inputType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            _SettingsTile(
              icon: Icons.currency_exchange_outlined,
              label: 'Currency Symbol',
              value: settings[AppConstants.settingCurrencySymbol] ??
                  AppConstants.defaultCurrencySymbol,
              onTap: () => _editSetting(
                context,
                key: AppConstants.settingCurrencySymbol,
                label: 'Currency Symbol',
                current: settings[AppConstants.settingCurrencySymbol] ??
                    AppConstants.defaultCurrencySymbol,
              ),
            ),

            const SectionHeader(title: 'Receipt'),
            _SettingsTile(
              icon: Icons.text_fields_outlined,
              label: 'Receipt Header',
              value: settings[AppConstants.settingReceiptHeader]?.isEmpty ?? true
                  ? 'Not set'
                  : settings[AppConstants.settingReceiptHeader]!,
              onTap: () => _editSetting(
                context,
                key: AppConstants.settingReceiptHeader,
                label: 'Receipt Header',
                current: settings[AppConstants.settingReceiptHeader] ?? '',
                maxLines: 2,
              ),
            ),
            _SettingsTile(
              icon: Icons.text_fields_outlined,
              label: 'Receipt Footer',
              value: settings[AppConstants.settingReceiptFooter]?.isEmpty ?? true
                  ? 'Not set'
                  : settings[AppConstants.settingReceiptFooter]!,
              onTap: () => _editSetting(
                context,
                key: AppConstants.settingReceiptFooter,
                label: 'Receipt Footer',
                current: settings[AppConstants.settingReceiptFooter] ?? '',
                maxLines: 2,
              ),
            ),

            const SectionHeader(title: 'Printers'),
            SwitchListTile.adaptive(
              secondary: const Icon(Icons.print_outlined,
                  size: 22, color: AppColors.textSecondary),
              title: const Text('Use one printer for everything'),
              subtitle: const Text(
                  'Bills and kitchen tickets print on the same device'),
              value: (settings[AppConstants.settingUseSinglePrinter] ?? 'false') == 'true',
              activeColor: AppColors.primary,
              onChanged: (v) {
                ref.read(settingsNotifierProvider.notifier).set(
                    AppConstants.settingUseSinglePrinter, v ? 'true' : 'false');
                if (v) {
                  // Mirror POS printer → kitchen printer
                  ref.read(settingsNotifierProvider.notifier).setAll({
                    AppConstants.settingKitchenPrinterAddress:
                        settings[AppConstants.settingPosPrinterAddress] ?? '',
                    AppConstants.settingKitchenPrinterName:
                        settings[AppConstants.settingPosPrinterName] ?? '',
                  });
                }
              },
            ),
            if ((settings[AppConstants.settingUseSinglePrinter] ?? 'false') == 'true')
              _PrinterTile(
                label: 'Printer (Bills & Kitchen Tickets)',
                primaryAddressKey: AppConstants.settingPosPrinterAddress,
                primaryNameKey: AppConstants.settingPosPrinterName,
                mirrorAddressKey: AppConstants.settingKitchenPrinterAddress,
                mirrorNameKey: AppConstants.settingKitchenPrinterName,
                settings: settings,
              )
            else ...[
              _PrinterTile(
                label: 'POS Printer (Bills / Receipts)',
                primaryAddressKey: AppConstants.settingPosPrinterAddress,
                primaryNameKey: AppConstants.settingPosPrinterName,
                settings: settings,
              ),
              _PrinterTile(
                label: 'Kitchen Printer (Order Tickets)',
                primaryAddressKey: AppConstants.settingKitchenPrinterAddress,
                primaryNameKey: AppConstants.settingKitchenPrinterName,
                settings: settings,
              ),
            ],

            const SectionHeader(title: 'Tables'),
            _TableManagementTile(),

            const SectionHeader(title: 'Backup & Restore'),
            _BackupRestoreSection(),

            const SectionHeader(title: 'About'),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.local_cafe,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CafeDesk',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          Text('Version ${AppConstants.appVersion}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  const Text('Developed by',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  const Text('Agentic-Devs',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.chat_outlined,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      const Text('WhatsApp: +92 313 1248353',
                          style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _editSetting(
    BuildContext context, {
    required String key,
    required String label,
    required String current,
    TextInputType inputType = TextInputType.text,
    int maxLines = 1,
  }) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $label'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: inputType,
          maxLines: maxLines,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null) {
      ref.read(settingsNotifierProvider.notifier).set(key, result);
    }
  }
}

// ── Logo Tile ─────────────────────────────────────────────────────────────────

class _LogoTile extends ConsumerWidget {
  final Map<String, String> settings;
  const _LogoTile({required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logoPath = settings[AppConstants.settingLogoPath] ?? '';
    final hasLogo = logoPath.isNotEmpty && File(logoPath).existsSync();

    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: hasLogo
            ? Image.file(File(logoPath),
                width: 44, height: 44, fit: BoxFit.cover)
            : Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.image_outlined,
                    color: AppColors.textSecondary, size: 22),
              ),
      ),
      title: const Text('Restaurant Logo'),
      subtitle: Text(
        hasLogo ? 'Tap to change • shown on receipts' : 'Tap to upload logo',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.textSecondary),
      ),
      trailing: hasLogo
          ? IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.error, size: 20),
              tooltip: 'Remove logo',
              onPressed: () => ref
                  .read(settingsNotifierProvider.notifier)
                  .set(AppConstants.settingLogoPath, ''),
            )
          : const Icon(Icons.chevron_right,
              size: 18, color: AppColors.textSecondary),
      onTap: () => _pickLogo(context, ref),
    );
  }

  Future<void> _pickLogo(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final srcPath = result.files.first.path;
    if (srcPath == null) return;

    final docsDir = await getApplicationDocumentsDirectory();
    final dest = File('${docsDir.path}/cafe_logo.jpg');
    await File(srcPath).copy(dest.path);

    ref
        .read(settingsNotifierProvider.notifier)
        .set(AppConstants.settingLogoPath, dest.path);
  }
}

// ── Settings Tile ─────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, size: 22, color: AppColors.textSecondary),
        title: Text(label),
        subtitle: Text(value,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right, size: 18,
            color: AppColors.textSecondary),
        onTap: onTap,
      );
}

// ── Printer Tile ──────────────────────────────────────────────────────────────

class _PrinterTile extends ConsumerWidget {
  final String label;
  final String primaryAddressKey;
  final String primaryNameKey;
  // When set, selecting a printer also saves to these keys (single-printer mode)
  final String? mirrorAddressKey;
  final String? mirrorNameKey;
  final Map<String, String> settings;

  const _PrinterTile({
    required this.label,
    required this.primaryAddressKey,
    required this.primaryNameKey,
    this.mirrorAddressKey,
    this.mirrorNameKey,
    required this.settings,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = settings[primaryNameKey] ?? '';
    final address = settings[primaryAddressKey] ?? '';

    return ListTile(
      leading: const Icon(Icons.print_outlined,
          size: 22, color: AppColors.textSecondary),
      title: Text(label),
      subtitle: Text(
        name.isEmpty ? 'Not configured — tap to pair' : '$name  •  $address',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.textSecondary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(
        name.isEmpty ? Icons.warning_amber_outlined : Icons.check_circle_outline,
        size: 18,
        color: name.isEmpty ? AppColors.warning : AppColors.success,
      ),
      onTap: () => _showPrinterPicker(context, ref, name, address),
    );
  }

  Future<void> _showPrinterPicker(BuildContext context, WidgetRef ref,
      String currentName, String currentAddress) async {
    final devices = await PrinterService.instance.scanDevices();

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.bluetooth_searching, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(label,
                        style: Theme.of(ctx).textTheme.titleMedium),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (devices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No paired Bluetooth devices found.\n\nPair your thermal printer in Android Settings → Bluetooth first, then come back here.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...devices.map(
                (d) => ListTile(
                  leading: const Icon(Icons.print_outlined),
                  title: Text(d.name),
                  subtitle: Text(d.macAdress),
                  selected: currentAddress == d.macAdress,
                  selectedTileColor:
                      AppColors.primaryLight.withValues(alpha: 0.15),
                  trailing: currentAddress == d.macAdress
                      ? const Icon(Icons.check, color: AppColors.primary, size: 18)
                      : null,
                  onTap: () {
                    final updates = {
                      primaryNameKey: d.name,
                      primaryAddressKey: d.macAdress,
                    };
                    if (mirrorAddressKey != null && mirrorNameKey != null) {
                      updates[mirrorNameKey!] = d.name;
                      updates[mirrorAddressKey!] = d.macAdress;
                    }
                    ref.read(settingsNotifierProvider.notifier).setAll(updates);
                    Navigator.pop(ctx);
                  },
                ),
              ),
            if (currentAddress.isNotEmpty) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.link_off, color: AppColors.error),
                title: const Text('Remove Printer',
                    style: TextStyle(color: AppColors.error)),
                onTap: () {
                  final updates = {primaryNameKey: '', primaryAddressKey: ''};
                  if (mirrorAddressKey != null && mirrorNameKey != null) {
                    updates[mirrorNameKey!] = '';
                    updates[mirrorAddressKey!] = '';
                  }
                  ref.read(settingsNotifierProvider.notifier).setAll(updates);
                  Navigator.pop(ctx);
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Table Management Tile ─────────────────────────────────────────────────────

class _TableManagementTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablesAsync = ref.watch(tablesProvider);
    return tablesAsync.when(
      loading: () => const ListTile(title: Text('Loading tables...')),
      error: (_, __) => const ListTile(title: Text('Error loading tables')),
      data: (tables) => ListTile(
        leading: const Icon(Icons.table_restaurant_outlined,
            size: 22, color: AppColors.textSecondary),
        title: const Text('Manage Tables'),
        subtitle: Text('${tables.length} table${tables.length == 1 ? '' : 's'}'),
        trailing: const Icon(Icons.chevron_right, size: 18,
            color: AppColors.textSecondary),
        onTap: () => _showTableManager(context, ref, tables),
      ),
    );
  }

  void _showTableManager(BuildContext context, WidgetRef ref,
      List<TableModel> tables) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, sc) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Text('Tables',
                      style: Theme.of(ctx).textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _addTable(ctx, ref),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: tables.isEmpty
                  ? const Center(child: Text('No tables yet'))
                  : ListView.separated(
                      controller: sc,
                      itemCount: tables.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final t = tables[i];
                        return ListTile(
                          leading: const Icon(Icons.table_restaurant),
                          title: Text(t.name),
                          subtitle:
                              Text('Capacity: ${t.capacity}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AppColors.error, size: 20),
                            onPressed: () async {
                              final ok = await showConfirmDialog(
                                ctx,
                                title: 'Delete Table',
                                message: 'Delete "${t.name}"?',
                                confirmLabel: 'Delete',
                                destructive: true,
                              );
                              if (ok) {
                                ref
                                    .read(tablesProvider.notifier)
                                    .remove(t.id!);
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _addTable(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final capCtrl = TextEditingController(text: '4');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Table'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Table name',
                    hintText: 'e.g. Table 1')),
            const SizedBox(height: 12),
            TextField(
                controller: capCtrl,
                decoration:
                    const InputDecoration(labelText: 'Capacity'),
                keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              ref.read(tablesProvider.notifier).add(
                    TableModel.create(
                        name: name,
                        capacity:
                            int.tryParse(capCtrl.text.trim()) ?? 4),
                  );
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// ── Backup & Restore Section ──────────────────────────────────────────────────

class _BackupRestoreSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_BackupRestoreSection> createState() =>
      _BackupRestoreSectionState();
}

class _BackupRestoreSectionState
    extends ConsumerState<_BackupRestoreSection> {
  bool _exporting = false;
  bool _importing = false;

  BackupService get _backup =>
      BackupService(DatabaseHelper.instance);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.cloud_upload_outlined,
              size: 22, color: AppColors.textSecondary),
          title: const Text('Export Backup'),
          subtitle: const Text(
              'Save all data to a .cafedesk file and share to Google Drive, email, etc.'),
          trailing: _exporting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.chevron_right, size: 18,
                  color: AppColors.textSecondary),
          onTap: _exporting ? null : _export,
        ),
        const Divider(height: 1, indent: 56),
        ListTile(
          leading: const Icon(Icons.cloud_download_outlined,
              size: 22, color: AppColors.textSecondary),
          title: const Text('Import Backup'),
          subtitle: const Text(
              'Restore from a .cafedesk file. Choose Merge to keep existing data.'),
          trailing: _importing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.chevron_right, size: 18,
                  color: AppColors.textSecondary),
          onTap: _importing ? null : _import,
        ),
      ],
    );
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await _backup.export();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    try {
      final payload = await _backup.pickAndParse();
      if (payload == null) {
        if (mounted) setState(() => _importing = false);
        return;
      }

      final summary = await _backup.analyze(payload);

      if (!mounted) return;
      final mode = await _showImportDialog(summary);
      if (mode == null) {
        setState(() => _importing = false);
        return;
      }

      if (mode == 'merge') {
        await _backup.importMerge(payload);
      } else {
        await _backup.importReplace(payload);
      }

      // Refresh all providers
      ref.read(settingsNotifierProvider.notifier).load();
      ref.read(tablesProvider.notifier).load();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restored successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Import failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<String?> _showImportDialog(
      BackupConflictSummary summary) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (summary.exportedAt != null)
                Text(
                  'Backup from: ${DateHelpers.formatDateTime(summary.exportedAt!)}',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary),
                ),
              if (summary.deviceName != null)
                Text('Device: ${summary.deviceName}',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              Text('New records to add: ${summary.totalNew}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.success)),
              Text(
                  'Already exist (will be skipped in Merge): ${summary.totalExisting}'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.4)),
                ),
                child: const Text(
                  '⚠ Full Replace will erase all current data.',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.warning),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          OutlinedButton(
            onPressed: () async {
              final ok = await showConfirmDialog(
                ctx,
                title: 'Full Replace',
                message:
                    'This will DELETE all current data and replace it with the backup. Continue?',
                confirmLabel: 'Replace All',
                destructive: true,
              );
              if (ok && ctx.mounted) Navigator.pop(ctx, 'replace');
            },
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error)),
            child: const Text('Full Replace'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'merge'),
            child: const Text('Merge'),
          ),
        ],
      ),
    );
  }
}
