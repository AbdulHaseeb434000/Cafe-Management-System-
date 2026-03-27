import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class TablesScreen extends StatelessWidget {
  const TablesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tables')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.table_restaurant_outlined, size: 64, color: AppColors.textDisabled),
            SizedBox(height: 16),
            Text('Tables — Coming in Phase 3'),
          ],
        ),
      ),
    );
  }
}
