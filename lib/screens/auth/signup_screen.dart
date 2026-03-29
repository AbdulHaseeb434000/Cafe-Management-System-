import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import 'auth_widgets.dart';

/// Sign Up form — creates a new restaurant account.
/// Shown as the second tab inside LoginScreen.
class SignupForm extends StatefulWidget {
  const SignupForm({super.key});

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final _formKey = GlobalKey<FormState>();
  final _restaurantCtrl = TextEditingController();
  final _ownerCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _restaurantCtrl.dispose();
    _ownerCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final response = await SupabaseService.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        restaurantName: _restaurantCtrl.text.trim(),
        ownerName: _ownerCtrl.text.trim(),
      );

      if (response.user == null) {
        setState(() { _error = 'Signup failed. Please try again.'; _loading = false; });
        return;
      }

      await SupabaseService.createRestaurant(
        restaurantName: _restaurantCtrl.text.trim(),
        ownerName: _ownerCtrl.text.trim(),
      );

      if (!mounted) return;
      await _showTrialDialog();
    } on AuthException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Something went wrong. Check your connection.'; _loading = false; });
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
              'After the trial, plans start at Rs. 2,000/month for a single device. '
              'You can manage your subscription from Settings.',
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
            if (_error != null) ...[
              AuthErrorBanner(message: _error!),
              const SizedBox(height: 16),
            ],
            AuthTextField(
              controller: _restaurantCtrl,
              label: 'Restaurant / Café Name',
              hint: 'e.g. Plato Café',
              textCapitalization: TextCapitalization.words,
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            AuthTextField(
              controller: _ownerCtrl,
              label: 'Your Name',
              hint: 'e.g. Ahmed Khan',
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
                  : const Text('Create Account',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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
