import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_providers.dart';
import '../../services/payment/safepay_service.dart';
import '../../services/supabase/supabase_service.dart';

/// Opens the Safepay hosted checkout inside an in-app WebView.
///
/// Intercepts the redirect URLs:
///   platodesk://payment/success → payment completed, begin polling
///   platodesk://payment/cancel  → user cancelled, pop with false
///
/// Returns [true] when the payment is confirmed as [paid] in Supabase,
/// [false] when cancelled or timed out.
class SafepayWebviewScreen extends ConsumerStatefulWidget {
  const SafepayWebviewScreen({
    super.key,
    required this.checkoutUrl,
    required this.orderId,
    required this.planName,
  });

  final String checkoutUrl;
  final String orderId;
  final String planName;

  @override
  ConsumerState<SafepayWebviewScreen> createState() =>
      _SafepayWebviewScreenState();
}

class _SafepayWebviewScreenState
    extends ConsumerState<SafepayWebviewScreen> {
  late final WebViewController _controller;
  bool _pageLoading = true;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _pageLoading = true),
        onPageFinished: (_) => setState(() => _pageLoading = false),
        onNavigationRequest: _handleNavigation,
        onWebResourceError: (err) {
          // Ignore errors for intercepted custom-scheme URLs
          if (err.url?.startsWith('platodesk://') == true) return;
          debugPrint('WebView error: ${err.description}');
        },
      ))
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  NavigationDecision _handleNavigation(NavigationRequest request) {
    final url = request.url;

    if (url.startsWith('platodesk://payment/success')) {
      _onPaymentSuccess();
      return NavigationDecision.prevent;
    }

    if (url.startsWith('platodesk://payment/cancel')) {
      _onPaymentCancelled();
      return NavigationDecision.prevent;
    }

    // Allow all other navigation within the Safepay checkout
    return NavigationDecision.navigate;
  }

  Future<void> _onPaymentSuccess() async {
    if (_polling) return;
    setState(() => _polling = true);

    try {
      final payment = await SafepayService.pollPaymentStatus(widget.orderId);

      if (!mounted) return;

      if (payment.isPaid) {
        // Refresh the cached restaurant row so the plan badge updates
        final restaurant = await SupabaseService.fetchRestaurant();
        if (mounted && restaurant != null) {
          ref.read(restaurantProvider.notifier).state = restaurant;
        }
        if (mounted) Navigator.of(context).pop(true);
      } else {
        _showError(
          'Payment status: ${payment.status}. '
          'Please contact support if money was deducted.',
        );
        if (mounted) Navigator.of(context).pop(false);
      }
    } on SafepayException catch (e) {
      if (mounted) {
        _showError(e.message);
        Navigator.of(context).pop(false);
      }
    } catch (e) {
      if (mounted) {
        _showError('Could not confirm payment. Please check your subscription status.');
        Navigator.of(context).pop(false);
      }
    }
  }

  void _onPaymentCancelled() {
    if (mounted) Navigator.of(context).pop(false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  Future<bool> _onWillPop() async {
    // Confirm before dismissing mid-checkout
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel payment?'),
        content: const Text(
            'Leaving now will cancel this payment session. You can try again anytime.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Stay')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Leave')),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) Navigator.of(context).pop(false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.planName} — Checkout'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cancel',
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && mounted) Navigator.of(context).pop(false);
            },
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),

            // Page loading indicator (thin top bar)
            if (_pageLoading)
              const LinearProgressIndicator(
                minHeight: 3,
                color: AppColors.primary,
              ),

            // Polling overlay — shown while we wait for webhook confirmation
            if (_polling)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Confirming payment…',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'This usually takes a few seconds.',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
