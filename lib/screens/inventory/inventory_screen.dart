import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textDisabled),
            SizedBox(height: 16),
            Text('Inventory — Coming in Phase 8'),
          ],
        ),
      ),
    );
  }
}
