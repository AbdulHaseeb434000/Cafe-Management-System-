import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';

class OrderTypeBadge extends StatelessWidget {
  final String type;
  final bool small;

  const OrderTypeBadge({super.key, required this.type, this.small = false});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      AppConstants.orderTypeDineIn => ('Dine-In', AppColors.dineIn),
      AppConstants.orderTypeDelivery => ('Delivery', AppColors.delivery),
      _ => ('Takeaway', AppColors.takeaway),
    };
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 6 : 8, vertical: small ? 2 : 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: small ? 10 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class OrderStatusBadge extends StatelessWidget {
  final String status;
  const OrderStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      AppConstants.orderStatusPending => ('Pending', AppColors.statusPending),
      AppConstants.orderStatusPreparing =>
        ('Preparing', AppColors.statusPreparing),
      AppConstants.orderStatusReady => ('Ready', AppColors.statusReady),
      AppConstants.orderStatusCompleted =>
        ('Completed', AppColors.statusCompleted),
      _ => ('Cancelled', AppColors.statusCancelled),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
