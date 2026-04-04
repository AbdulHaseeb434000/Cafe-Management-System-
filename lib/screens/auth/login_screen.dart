import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/database/database_helper.dart';
import '../../providers/auth_providers.dart';
import '../../services/supabase/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../services/sync/sync_service.dart';
import 'auth_widgets.dart';
import 'signup_screen.dart';

/// Login + Sign Up screen with tab switcher.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.dinner_dining, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 12),
            Text(
              'PlatoDesk',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.brown,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabs,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Login'),
                    Tab(text: 'Sign Up'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: const [
                  _LoginForm(),
                  SignupForm(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Login form ──────────────────────────────────────────────────────────────

class _LoginForm extends ConsumerStatefulWidget {
  const _LoginForm();

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _rememberMe = false;
  String? _error;

  static const _storage = FlutterSecureStorage();
  static const _keyEmail = 'saved_email';
  static const _keyPass = 'saved_password';
  static const _keyRemember = 'remember_me';

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final remember = await _storage.read(key: _keyRemember);
      if (remember != '1') return;
      final email = await _storage.read(key: _keyEmail);
      final pass = await _storage.read(key: _keyPass);
      if (email != null && pass != null) {
        setState(() {
          _emailCtrl.text = email;
          _passCtrl.text = pass;
          _rememberMe = true;
        });
      }
    } catch (_) {
      // Secure storage unavailable — proceed without pre-fill
    }
  }

  Future<void> _saveCredentials() async {
    try {
      if (_rememberMe) {
        await _storage.write(key: _keyEmail, value: _emailCtrl.text.trim());
        await _storage.write(key: _keyPass, value: _passCtrl.text);
        await _storage.write(key: _keyRemember, value: '1');
      } else {
        await _storage.delete(key: _keyEmail);
        await _storage.delete(key: _keyPass);
        await _storage.delete(key: _keyRemember);
      }
    } catch (_) {}
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
      return 'An account with this email already exists.';
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
      await SupabaseService.signIn(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      if (!mounted) return;

      // Try fetching restaurant online; fall back to local cache if offline.
      Map<String, dynamic>? restaurant;
      try {
        restaurant = await SupabaseService.fetchRestaurant();
        if (restaurant != null) await _cacheRestaurant(restaurant);
      } catch (_) {
        restaurant = await _loadCachedRestaurant();
      }

      if (!mounted) return;

      if (restaurant == null) {
        // Auth OK but no restaurant/staff rows — setup was interrupted.
        setState(() { _loading = false; });
        if (!mounted) return;
        await _showCompleteSetupDialog();
        return;
      }

      if (!SupabaseService.isPlanActive(restaurant)) {
        context.go('/paywall');
        return;
      }

      ref.read(restaurantProvider.notifier).state = restaurant;
      ref.read(trialDaysProvider.notifier).state =
          SupabaseService.trialDaysLeft(restaurant);

      Map<String, dynamic>? staff;
      try {
        staff = await SupabaseService.fetchStaffRecord();
      } catch (_) {
        staff = null;
      }
      if (!mounted) return;

      final role = staff?['role'] as String? ?? 'waiter';
      setRole(role, ref);

      // Save or clear credentials based on "Remember me" choice.
      await _saveCredentials();

      unawaited(SyncService.instance.triggerOnLogin());
      if (role == 'kitchen') {
        context.go('/kitchen');
      } else {
        context.go('/');
      }
    } on AuthException catch (e) {
      setState(() { _error = _friendlyAuthError(e); _loading = false; });
    } catch (_) {
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _loading = false;
      });
    }
  }

  /// Load cached restaurant from local SQLite (offline fallback).
  Future<Map<String, dynamic>?> _loadCachedRestaurant() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('settings',
          where: 'key = ?', whereArgs: ['cached_restaurant']);
      if (rows.isEmpty) return null;
      return Map<String, dynamic>.from(
          jsonDecode(rows.first['value'] as String) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheRestaurant(Map<String, dynamic> restaurant) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert(
        'settings',
        {'key': 'cached_restaurant', 'value': jsonEncode(restaurant)},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<void> _showCompleteSetupDialog() async {
    final restaurantCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? dialogError;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: const Text('Complete Your Setup'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Your account was created but setup didn\'t finish. '
                  'Enter your details to complete it.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (dialogError != null) ...[
                  Text(dialogError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                  const SizedBox(height: 8),
                ],
                TextFormField(
                  controller: restaurantCtrl,
                  decoration: const InputDecoration(labelText: 'Restaurant / Café Name'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Your Name'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                // H4: Use signOutAndClear(ref) so Riverpod providers are reset.
                await signOutAndClear(ref);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Sign Out'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  await SupabaseService.createRestaurant(
                    restaurantName: restaurantCtrl.text.trim(),
                    ownerName: nameCtrl.text.trim(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    setRole('owner', ref);
                    context.go('/');
                  }
                } catch (e) {
                  setInner(() => dialogError =
                      'Setup failed. Please try again.');
                }
              },
              child: const Text('Complete Setup'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email first, then tap Forgot Password.')),
      );
      return;
    }
    await SupabaseService.resetPassword(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password reset email sent.')),
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
            if (_error != null) ...[
              AuthErrorBanner(message: _error!),
              const SizedBox(height: 16),
            ],
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
            const SizedBox(height: 4),
            // Remember Me + Forgot Password row
            Row(
              children: [
                Checkbox(
                  value: _rememberMe,
                  onChanged: (v) => setState(() => _rememberMe = v ?? false),
                  visualDensity: VisualDensity.compact,
                  activeColor: AppColors.primary,
                ),
                GestureDetector(
                  onTap: () => setState(() => _rememberMe = !_rememberMe),
                  child: Text(
                    'Remember me',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textPrimary),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _forgotPassword,
                  child: const Text('Forgot Password?'),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
                  : const Text('Login', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            // M6: Use currentSession (not isSignedIn static getter) for freshness.
            if (SupabaseService.currentSession != null) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () async {
                    await signOutAndClear(ref);
                    setState(() {});
                  },
                  child: const Text('Sign out of current account'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
