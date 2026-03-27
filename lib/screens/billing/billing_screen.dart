import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class BillingScreen extends StatelessWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Billing')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.point_of_sale_outlined, size: 64, color: AppColors.textDisabled),
            SizedBox(height: 16),
            Text('Billing & POS — Coming in Phase 6'),
          ],
        ),
      ),
    );
  }
}
