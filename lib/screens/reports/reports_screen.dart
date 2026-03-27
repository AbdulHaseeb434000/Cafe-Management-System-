import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_outlined, size: 64, color: AppColors.textDisabled),
            SizedBox(height: 16),
            Text('Reports — Coming in Phase 9'),
          ],
        ),
      ),
    );
  }
}
