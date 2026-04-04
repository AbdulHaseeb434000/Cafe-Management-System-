// Update pricing here before releasing a new version.
abstract final class PlanConstants {
  /// WhatsApp support number — international format, no spaces or '+'.
  static const supportWhatsApp = '923131248353';
  static const supportEmail = 'support@platodesk.app';

  static const plans = <PlanInfo>[
    PlanInfo(
      name: 'Starter',
      price: 'Rs. 2,000',
      period: '/month',
      devices: '1 device',
      highlights: [
        'All core features',
        'Unlimited orders',
        'PDF receipts & reports',
      ],
      recommended: false,
    ),
    PlanInfo(
      name: 'Standard',
      price: 'Rs. 4,500',
      period: '/month',
      devices: 'Up to 3 devices',
      highlights: [
        'Everything in Starter',
        'Multi-staff roles',
        'Priority support',
      ],
      recommended: true,
    ),
    PlanInfo(
      name: 'Business',
      price: 'Rs. 9,000',
      period: '/month',
      devices: 'Up to 8 devices',
      highlights: [
        'Everything in Standard',
        'Cloud sync',
        'Advanced analytics',
      ],
      recommended: false,
    ),
  ];
}

class PlanInfo {
  const PlanInfo({
    required this.name,
    required this.price,
    required this.period,
    required this.devices,
    required this.highlights,
    required this.recommended,
  });

  final String name;
  final String price;
  final String period;
  final String devices;
  final List<String> highlights;
  final bool recommended;
}
