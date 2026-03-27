import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class KitchenScreen extends StatelessWidget {
  const KitchenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kitchen')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.soup_kitchen_outlined, size: 64, color: AppColors.textDisabled),
            SizedBox(height: 16),
            Text('Kitchen Display — Coming in Phase 5'),
          ],
        ),
      ),
    );
  }
}
