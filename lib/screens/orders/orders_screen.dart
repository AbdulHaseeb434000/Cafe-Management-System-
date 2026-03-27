import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textDisabled),
            SizedBox(height: 16),
            Text('Orders — Coming in Phase 4'),
          ],
        ),
      ),
    );
  }
}
