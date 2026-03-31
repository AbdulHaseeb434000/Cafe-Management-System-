import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../services/supabase/supabase_service.dart';

// Settings key used to persist the last successful staff list fetch.
const _kCacheKey = 'staff_list_cache';
const _kCacheAtKey = 'staff_list_cached_at';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  List<Map<String, dynamic>> _staff = [];
  bool _loading = true;
  String? _error;
  String? _currentAuthUserId;

  /// Set to true when the displayed list comes from local cache (network failed).
  bool _fromCache = false;
  DateTime? _cachedAt;

  @override
  void initState() {
    super.initState();
    _currentAuthUserId = SupabaseService.currentUser?.id;
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _fromCache = false; });
    try {
      final rows = await SupabaseService.listStaff();
      await _saveCache(rows);
      if (!mounted) return;
      setState(() { _staff = rows; _loading = false; });
    } catch (e) {
      // Network / auth failure — try serving the last cached list.
      final cached = await _loadCache();
      if (!mounted) return;
      if (cached != null) {
        setState(() {
          _staff = cached;
          _fromCache = true;
          _loading = false;
          _error = null; // suppress error UI when cache is available
        });
      } else {
        setState(() { _error = e.toString(); _loading = false; });
      }
    }
  }

  // ── Cache helpers ────────────────────────────────────────────────────────────

  Future<void> _saveCache(List<Map<String, dynamic>> rows) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    await db.insert('settings', {'key': _kCacheKey, 'value': jsonEncode(rows)},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('settings', {'key': _kCacheAtKey, 'value': now},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>?> _loadCache() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('settings',
        where: 'key = ?', whereArgs: [_kCacheKey]);
    final atRows = await db.query('settings',
        where: 'key = ?', whereArgs: [_kCacheAtKey]);
    if (rows.isEmpty) return null;
    try {
      final list = (jsonDecode(rows.first['value'] as String) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (atRows.isNotEmpty) {
        _cachedAt = DateTime.parse(atRows.first['value'] as String);
      }
      return list;
    } catch (_) {
      return null;
    }
  }

  // ── UI helpers ───────────────────────────────────────────────────────────────

  Future<void> _showAddDialog() async {
    // Billing warning confirmation
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Staff Member'),
        content: const Text(
          'Adding a staff member gives them access to this restaurant and counts as an additional seat. '
          'This may affect your billing at the next cycle.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue')),
        ],
      ),
    );
    if (proceed != true) return;

    final nameCtrl = TextEditingController();
    String role = 'waiter';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: const Text('Add Staff Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full name'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'manager', child: Text('Manager')),
                  DropdownMenuItem(value: 'waiter', child: Text('Waiter')),
                  DropdownMenuItem(value: 'kitchen', child: Text('Kitchen')),
                ],
                onChanged: (v) => setInner(() => role = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Generate Code'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    try {
      final result = await SupabaseService.addPendingStaff(name: name, role: role);
      if (!mounted) return;
      _showInviteCode(name, result.code, result.expiresAt);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showInviteCode(String name, String code, DateTime expiresAt) {
    final expiryLabel = DateFormat('d MMM, h:mm a').format(expiresAt.toLocal());
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite Code Generated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Share this code with $name:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                code,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  letterSpacing: 6,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'They enter this code when signing up.\nExpires: $expiryLabel',
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code copied')),
              );
            },
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReactivate(Map<String, dynamic> member) async {
    final name = member['name'] as String? ?? 'this staff member';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reactivate Staff'),
        content: Text('Restore $name to the team? They will regain app access.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SupabaseService.reactivateStaff(member['id'] as String);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _confirmDeactivate(Map<String, dynamic> member) async {
    final name = member['name'] as String? ?? 'this staff member';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate Staff'),
        content: Text('Remove $name from the team? They will lose app access.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SupabaseService.deactivateStaff(member['id'] as String);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Staff'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_staff.isEmpty) {
      return const Center(child: Text('No staff yet. Tap + to add someone.'));
    }

    return Column(
      children: [
        if (_fromCache) _CacheBanner(cachedAt: _cachedAt, onRetry: _load),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: _staff.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _StaffTile(
                member: _staff[i],
                isCurrentUser: _staff[i]['auth_user_id'] == _currentAuthUserId,
                onDeactivate: () => _confirmDeactivate(_staff[i]),
                onReactivate: () => _confirmReactivate(_staff[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Cache banner ───────────────────────────────────────────────────────────────

class _CacheBanner extends StatelessWidget {
  final DateTime? cachedAt;
  final VoidCallback onRetry;

  const _CacheBanner({required this.cachedAt, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final label = cachedAt != null
        ? DateFormat('d MMM, h:mm a').format(cachedAt!)
        : 'unknown';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.5),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined,
              size: 16, color: Theme.of(context).colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing cached data · last updated $label',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Retry',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Staff tile ─────────────────────────────────────────────────────────────────

class _StaffTile extends StatelessWidget {
  const _StaffTile({
    required this.member,
    required this.isCurrentUser,
    required this.onDeactivate,
    required this.onReactivate,
  });

  final Map<String, dynamic> member;
  final bool isCurrentUser;
  final VoidCallback onDeactivate;
  final VoidCallback onReactivate;

  @override
  Widget build(BuildContext context) {
    final name = member['name'] as String? ?? '—';
    final role = member['role'] as String? ?? '—';
    final isActive = member['is_active'] as bool? ?? false;
    final isPending = member['auth_user_id'] == null;
    final inviteCode = member['invite_code'] as String?;
    final inviteExpiresAt = member['invite_expires_at'] as String?;
    final isExpired = isPending &&
        inviteExpiresAt != null &&
        DateTime.parse(inviteExpiresAt).isBefore(DateTime.now().toUtc());

    Widget? trailing;
    if (isCurrentUser) {
      trailing = Tooltip(
        message: 'Cannot remove yourself',
        child: const Icon(Icons.lock_outline, color: Colors.grey),
      );
    } else if (isActive) {
      trailing = IconButton(
        icon: const Icon(Icons.person_off_outlined),
        tooltip: 'Deactivate',
        onPressed: onDeactivate,
      );
    } else {
      trailing = IconButton(
        icon: const Icon(Icons.refresh, color: Colors.green),
        tooltip: 'Reactivate',
        onPressed: onReactivate,
      );
    }

    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(name[0].toUpperCase())),
        title: Text(name),
        subtitle: Text(
          isPending
              ? isExpired
                  ? 'Invite Expired · Code: ${inviteCode ?? '—'}'
                  : 'Pending · Code: ${inviteCode ?? '—'}'
              : '${_label(role)} · ${isActive ? 'Active' : 'Inactive'}',
          style: isExpired
              ? TextStyle(color: Theme.of(context).colorScheme.error)
              : null,
        ),
        trailing: trailing,
      ),
    );
  }

  String _label(String role) => switch (role) {
        'owner' => 'Owner',
        'manager' => 'Manager',
        'waiter' => 'Waiter',
        'kitchen' => 'Kitchen',
        _ => role,
      };
}
