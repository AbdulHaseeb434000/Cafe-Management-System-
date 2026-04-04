import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../services/sync/sync_service.dart';
import '../../providers/auth_providers.dart';
import '../../providers/settings_providers.dart';
import '../../services/supabase/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import 'auth_widgets.dart';

/// Sign Up form — two modes:
///   1. "New Restaurant" — owner creates account + restaurant
///   2. "Join with Code"  — staff member links account using invite code
class SignupForm extends ConsumerStatefulWidget {
  const SignupForm({super.key});

  @override
  ConsumerState<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends ConsumerState<SignupForm> {
  final _formKey = GlobalKey<FormState>();
  final _restaurantCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String? _error;
  bool _joinMode = false; // false = new restaurant, true = join with code

  @override
  void dispose() {
    _restaurantCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  /// Maps Supabase AuthException messages to user-friendly strings.
  static String _friendlyAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('email not confirmed') ||
        msg.contains('email_not_confirmed')) {
      return 'Please confirm your email address before logging in.';
    }
    if (msg.contains('user already registered') ||
        msg.contains('user_already_exists')) {
      return 'An account with this email already exists. Please log in instead.';
    }
    if (msg.contains('rate') || msg.contains('too many')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (msg.contains('network') || msg.contains('connection')) {
      return 'Connection failed. Check your internet connection.';
    }
    return e.message;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      if (_joinMode) {
        await _joinWithCode();
      } else {
        await _createRestaurant();
      }
    } on AuthException catch (e) {
      setState(() { _error = _friendlyAuthError(e); _loading = false; });
    } catch (e) {
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _createRestaurant() async {
    final response = await SupabaseService.signUp(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
      restaurantName: _restaurantCtrl.text.trim(),
      ownerName: _nameCtrl.text.trim(),
    );

    if (response.user == null) {
      setState(() { _error = 'Signup failed. Please try again.'; _loading = false; });
      return;
    }

    // M4: If restaurant creation fails after auth user is created, sign out
    // to prevent a dangling account with no restaurant row.
    try {
      await SupabaseService.createRestaurant(
        restaurantName: _restaurantCtrl.text.trim(),
        ownerName: _nameCtrl.text.trim(),
      );
    } catch (_) {
      await SupabaseService.signOut();
      rethrow; // surfaces as "Something went wrong" in _submit's catch
    }

    setRole('owner', ref);
    unawaited(SyncService.instance.triggerOnLogin());

    if (!mounted) return;
    await _showCurrencyDialog();
    if (!mounted) return;
    await _showTrialDialog();
  }

  Future<void> _showCurrencyDialog() async {
    // Pre-save the default so skipping the dialog still sets a valid symbol.
    await ref.read(settingsNotifierProvider.notifier).set(
          AppConstants.settingCurrencySymbol,
          AppConstants.defaultCurrencySymbol,
        );
    final ctrl = TextEditingController(text: AppConstants.defaultCurrencySymbol);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Currency Symbol'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'What currency symbol does your restaurant use?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: r'Currency symbol ($, £, €, Rs.)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Skip')),
          FilledButton(
            onPressed: () async {
              final symbol = ctrl.text.trim();
              if (symbol.isNotEmpty) {
                await ref.read(settingsNotifierProvider.notifier).set(
                      AppConstants.settingCurrencySymbol,
                      symbol,
                    );
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _joinWithCode() async {
    final staff = await SupabaseService.joinWithInviteCode(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
      inviteCode: _codeCtrl.text.trim(),
    );

    final role = staff['role'] as String? ?? 'waiter';
    setRole(role, ref);
    unawaited(SyncService.instance.triggerOnLogin());

    if (!mounted) return;
    if (role == 'kitchen') {
      context.go('/kitchen');
    } else {
      context.go('/');
    }
  }

  Future<void> _showTrialDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.celebration_outlined, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            const Text('Welcome to PlatoDesk!'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your 3-day free trial has started.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Explore all features during the trial. To continue after '
              '3 days, contact us at support@platodesk.app for pricing '
              'and activation details.',
            ),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/');
            },
            child: const Text("Let's go!"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mode toggle
            Row(
              children: [
                Expanded(
                  child: _ModeChip(
                    label: 'New Restaurant',
                    icon: Icons.store_outlined,
                    selected: !_joinMode,
                    onTap: () => setState(() { _joinMode = false; _error = null; }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeChip(
                    label: 'Join with Code',
                    icon: Icons.vpn_key_outlined,
                    selected: _joinMode,
                    onTap: () => setState(() { _joinMode = true; _error = null; }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_joinMode) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.vpn_key_outlined,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your manager has already set up the restaurant on PlatoDesk '
                        'and generated a 6-character invite code just for you. '
                        'Enter it below to join their team.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_error != null) ...[
              AuthErrorBanner(message: _error!),
              const SizedBox(height: 16),
            ],

            if (!_joinMode) ...[
              AuthTextField(
                controller: _restaurantCtrl,
                label: 'Restaurant / Café Name',
                hint: 'Restaurant name',
                textCapitalization: TextCapitalization.words,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
            ],

            AuthTextField(
              controller: _nameCtrl,
              label: _joinMode ? 'Your Name' : 'Owner Name',
              hint: 'Your full name',
              textCapitalization: TextCapitalization.words,
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 14),

            AuthTextField(
              controller: _emailCtrl,
              label: 'Email',
              hint: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  v == null || !v.contains('@') ? 'Enter a valid email' : null,
            ),
            const SizedBox(height: 14),

            AuthTextField(
              controller: _passCtrl,
              label: 'Password',
              hint: '••••••••',
              obscureText: _obscure,
              suffix: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              validator: (v) =>
                  v == null || v.length < 6 ? 'Min. 6 characters' : null,
            ),
            const SizedBox(height: 14),

            AuthTextField(
              controller: _confirmCtrl,
              label: 'Confirm Password',
              hint: '••••••••',
              obscureText: _obscure,
              validator: (v) => v != _passCtrl.text ? 'Passwords do not match' : null,
            ),

            if (_joinMode) ...[
              const SizedBox(height: 14),
              AuthTextField(
                controller: _codeCtrl,
                label: 'Invite Code',
                hint: '6-character code',
                textCapitalization: TextCapitalization.characters,
                validator: (v) =>
                    v == null || v.trim().length != 6 ? 'Enter the 6-character code' : null,
              ),
            ],

            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _joinMode ? 'Join Restaurant' : 'Create Account',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              "By signing up you agree to PlatoDesk's Terms of Service and Privacy Policy.",
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
