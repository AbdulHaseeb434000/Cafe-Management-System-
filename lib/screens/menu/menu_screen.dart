import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu_outlined, size: 64, color: AppColors.textDisabled),
            SizedBox(height: 16),
            Text('Menu Management — Coming in Phase 2'),
          ],
        ),
      ),
    );
  }
}
