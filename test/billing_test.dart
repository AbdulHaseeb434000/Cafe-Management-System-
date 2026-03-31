// Tests for billing calculation logic and subscription plan helpers.
//
// The billing math here replicates the private getters in BillingScreen
// (_discountAmount, _taxAmount, _total) so that they can be tested without
// a widget tree. Any change to the billing formulas must be reflected here.

import 'package:flutter_test/flutter_test.dart';

// ── Billing math helpers (mirror of BillingScreen private getters) ────────────

/// Matches BillingScreen._discountAmount
double discountAmount(double subtotal, String type, double value) {
  if (type == 'percent') {
    return (subtotal * value / 100).clamp(0, subtotal);
  }
  return value.clamp(0.0, subtotal);
}

/// Matches BillingScreen._taxAmount
double taxAmount(double subtotal, double discAmt, double taxPercent) {
  final taxable = subtotal - discAmt;
  return taxable * taxPercent / 100;
}

/// Matches BillingScreen._total
double total(double subtotal, double discAmt, double taxAmt) {
  return (subtotal - discAmt) + taxAmt;
}

// ── Plan helpers (pure logic extracted from SupabaseService) ──────────────────

/// Matches SupabaseService.isPlanActive
bool isPlanActive(Map<String, dynamic> restaurant) {
  final plan = restaurant['plan'] as String? ?? 'trial';
  if (plan == 'suspended') return false;
  if (plan == 'trial') {
    final trialEnd = restaurant['trial_end_date'];
    if (trialEnd == null) return false;
    return DateTime.parse(trialEnd as String).isAfter(DateTime.now().toUtc());
  }
  return true;
}

/// Matches SupabaseService.trialDaysLeft
int? trialDaysLeft(Map<String, dynamic> restaurant) {
  if (restaurant['plan'] != 'trial') return null;
  final trialEnd = restaurant['trial_end_date'];
  if (trialEnd == null) return 0;
  final diff = DateTime.parse(trialEnd as String)
      .toUtc()
      .difference(DateTime.now().toUtc());
  return diff.inDays.clamp(0, 99);
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('Billing — flat discount', () {
    test('zero discount leaves total = subtotal + tax', () {
      final disc = discountAmount(100, 'flat', 0);
      final tax = taxAmount(100, disc, 10);
      expect(disc, 0.0);
      expect(tax, 10.0);
      expect(total(100, disc, tax), 110.0);
    });

    test('partial flat discount', () {
      final disc = discountAmount(200, 'flat', 50);
      final tax = taxAmount(200, disc, 10);
      // taxable = 150, tax = 15, total = 165
      expect(disc, 50.0);
      expect(tax, 15.0);
      expect(total(200, disc, tax), 165.0);
    });

    test('flat discount clamped to subtotal (no negative totals)', () {
      final disc = discountAmount(100, 'flat', 999);
      expect(disc, 100.0, reason: 'discount cannot exceed subtotal');
      final tax = taxAmount(100, disc, 15);
      expect(tax, 0.0, reason: 'nothing left to tax after full discount');
      expect(total(100, disc, tax), 0.0);
    });

    test('flat discount exactly equal to subtotal', () {
      final disc = discountAmount(75, 'flat', 75);
      expect(disc, 75.0);
      expect(total(75, disc, taxAmount(75, disc, 20)), 0.0);
    });
  });

  group('Billing — percent discount', () {
    test('10% discount on 200', () {
      final disc = discountAmount(200, 'percent', 10);
      expect(disc, 20.0);
    });

    test('100% discount zeroes out the order', () {
      final disc = discountAmount(150, 'percent', 100);
      expect(disc, 150.0);
      expect(total(150, disc, taxAmount(150, disc, 18)), 0.0);
    });

    test('percent discount clamped — > 100% behaves like 100%', () {
      final disc = discountAmount(100, 'percent', 150);
      expect(disc, 100.0);
    });

    test('50% on 80 with 5% tax', () {
      final disc = discountAmount(80, 'percent', 50); // 40
      final tax = taxAmount(80, disc, 5); // taxable=40, tax=2
      expect(disc, 40.0);
      expect(tax, 2.0);
      expect(total(80, disc, tax), 42.0);
    });
  });

  group('Billing — tax edge cases', () {
    test('zero tax rate', () {
      final disc = discountAmount(100, 'flat', 0);
      expect(taxAmount(100, disc, 0), 0.0);
      expect(total(100, disc, 0), 100.0);
    });

    test('tax applies to post-discount amount', () {
      // Subtotal 500, flat discount 100 → taxable 400, 10% tax = 40, total = 440
      final disc = discountAmount(500, 'flat', 100);
      final tax = taxAmount(500, disc, 10);
      expect(tax, 40.0);
      expect(total(500, disc, tax), 440.0);
    });
  });

  group('isPlanActive', () {
    test('active trial returns true', () {
      final future = DateTime.now().toUtc().add(const Duration(days: 7));
      expect(
        isPlanActive({'plan': 'trial', 'trial_end_date': future.toIso8601String()}),
        isTrue,
      );
    });

    test('expired trial returns false', () {
      final past = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      expect(
        isPlanActive({'plan': 'trial', 'trial_end_date': past.toIso8601String()}),
        isFalse,
      );
    });

    test('suspended plan returns false regardless of trial date', () {
      final future = DateTime.now().toUtc().add(const Duration(days: 30));
      expect(
        isPlanActive({'plan': 'suspended', 'trial_end_date': future.toIso8601String()}),
        isFalse,
      );
    });

    test('starter plan is always active', () {
      expect(isPlanActive({'plan': 'starter'}), isTrue);
    });

    test('standard plan is always active', () {
      expect(isPlanActive({'plan': 'standard'}), isTrue);
    });

    test('business plan is always active', () {
      expect(isPlanActive({'plan': 'business'}), isTrue);
    });

    test('trial with null end date returns false', () {
      expect(isPlanActive({'plan': 'trial', 'trial_end_date': null}), isFalse);
    });
  });

  group('trialDaysLeft', () {
    test('returns null for paid plans', () {
      expect(trialDaysLeft({'plan': 'starter'}), isNull);
      expect(trialDaysLeft({'plan': 'standard'}), isNull);
      expect(trialDaysLeft({'plan': 'business'}), isNull);
    });

    test('returns 0 when null end date', () {
      expect(trialDaysLeft({'plan': 'trial', 'trial_end_date': null}), 0);
    });

    test('returns correct days for future trial', () {
      final future = DateTime.now().toUtc().add(const Duration(days: 3));
      final days = trialDaysLeft({'plan': 'trial', 'trial_end_date': future.toIso8601String()});
      expect(days, 3);
    });

    test('returns 1 for ~24 hours remaining', () {
      final future = DateTime.now().toUtc().add(const Duration(hours: 25));
      final days = trialDaysLeft({'plan': 'trial', 'trial_end_date': future.toIso8601String()});
      expect(days, 1);
    });

    test('returns 0 for expired trial (clamped — never negative)', () {
      final past = DateTime.now().toUtc().subtract(const Duration(days: 5));
      final days = trialDaysLeft({'plan': 'trial', 'trial_end_date': past.toIso8601String()});
      expect(days, 0);
    });
  });
}
