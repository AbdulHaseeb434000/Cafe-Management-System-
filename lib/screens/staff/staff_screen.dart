import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/supabase/supabase_service.dart';

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

  @override
  void initState() {
    super.initState();
    _currentAuthUserId = SupabaseService.currentUser?.id;
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await SupabaseService.listStaff();
      setState(() { _staff = rows; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

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
      final code = await SupabaseService.addPendingStaff(name: name, role: role);
      if (!mounted) return;
      _showInviteCode(name, code);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showInviteCode(String name, String code) {
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
            const Text(
              'They enter this code when signing up.',
              style: TextStyle(fontSize: 12),
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
      return const Column(
        children: [
          _SyncNoticeBanner(),
          Expanded(child: Center(child: Text('No staff yet. Tap + to add someone.'))),
        ],
      );
    }

    return Column(
      children: [
        const _SyncNoticeBanner(),
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
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SyncNoticeBanner extends StatelessWidget {
  const _SyncNoticeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.wifi_outlined,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Each device syncs data automatically when connected to the internet or Wi-Fi. '
              'Make sure staff members have an active connection when signing in for the first time.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  const _StaffTile({
    required this.member,
    required this.isCurrentUser,
    required this.onDeactivate,
  });

  final Map<String, dynamic> member;
  final bool isCurrentUser;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final name = member['name'] as String? ?? '—';
    final role = member['role'] as String? ?? '—';
    final isActive = member['is_active'] as bool? ?? false;
    final isPending = member['auth_user_id'] == null;
    final inviteCode = member['invite_code'] as String?;

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
      trailing = const Icon(Icons.block, color: Colors.grey);
    }

    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(name[0].toUpperCase())),
        title: Text(name),
        subtitle: Text(
          isPending
              ? 'Pending · Code: ${inviteCode ?? '—'}'
              : '${_label(role)} · ${isActive ? 'Active' : 'Inactive'}',
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
