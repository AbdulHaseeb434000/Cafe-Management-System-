import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Central access point for Supabase.
/// Call [SupabaseService.initialize] once in main() before runApp.
class SupabaseService {
  SupabaseService._();

  // ── Replace these with your real project values from supabase.com ────────
  static const String _supabaseUrl =
      String.fromEnvironment('SUPABASE_URL');
  static const String _supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
  // ─────────────────────────────────────────────────────────────────────────

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
    );
  }

  // ── Auth helpers ─────────────────────────────────────────────────────────

  static User? get currentUser => auth.currentUser;
  static Session? get currentSession => auth.currentSession;
  static bool get isSignedIn => currentUser != null;

  /// Sign up a new restaurant owner.
  /// Creates an auth user; the DB trigger/post-signup flow creates
  /// the [restaurants] and [staff] rows.
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String restaurantName,
    required String ownerName,
  }) async {
    return auth.signUp(
      email: email,
      password: password,
      data: {
        'restaurant_name': restaurantName,
        'owner_name': ownerName,
      },
    );
  }

  /// Sign in with email + password.
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return auth.signInWithPassword(email: email, password: password);
  }

  /// Sign out current session.
  static Future<void> signOut() async => auth.signOut();

  /// Send password reset email.
  static Future<void> resetPassword(String email) async {
    await auth.resetPasswordForEmail(email);
  }

  // ── Restaurant & staff ───────────────────────────────────────────────────

  /// Fetch the restaurant row for the current user's staff record.
  static Future<Map<String, dynamic>?> fetchRestaurant() async {
    final user = currentUser;
    if (user == null) return null;

    final staffRow = await client
        .from('staff')
        .select('restaurant_id, role, name')
        .eq('auth_user_id', user.id)
        .eq('is_active', true)
        .maybeSingle();

    if (staffRow == null) return null;

    final restaurant = await client
        .from('restaurants')
        .select()
        .eq('id', staffRow['restaurant_id'] as String)
        .maybeSingle();

    return restaurant;
  }

  /// Fetch staff row for the current user.
  static Future<Map<String, dynamic>?> fetchStaffRecord() async {
    final user = currentUser;
    if (user == null) return null;

    return client
        .from('staff')
        .select()
        .eq('auth_user_id', user.id)
        .eq('is_active', true)
        .maybeSingle();
  }

  /// Create restaurant + owner staff row after signup.
  /// Called from SignupScreen once the auth user is created.
  static Future<void> createRestaurant({
    required String restaurantName,
    required String ownerName,
    String? address,
    String? phone,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Not signed in');

    final trialEnd = DateTime.now().add(const Duration(days: 3)).toUtc();

    // Generate restaurant UUID on the client so we never need to SELECT the
    // inserted row — the SELECT policy fails at this point because the staff
    // row doesn't exist yet (chicken-and-egg with current_restaurant_id()).
    final restaurantId = const Uuid().v4();

    await client.from('restaurants').insert({
      'id': restaurantId,
      'name': restaurantName,
      'owner_email': user.email,
      'address': address ?? '',
      'phone': phone ?? '',
      'plan': 'trial',
      'trial_end_date': trialEnd.toIso8601String(),
      'max_devices': 1,
    });

    // Insert owner staff record
    await client.from('staff').insert({
      'restaurant_id': restaurantId,
      'auth_user_id': user.id,
      'name': ownerName,
      'role': 'owner',
      'is_active': true,
    });
  }

  // ── Staff management ────────────────────────────────────────────────────

  /// List all staff for the current user's restaurant.
  static Future<List<Map<String, dynamic>>> listStaff() async {
    final staff = await fetchStaffRecord();
    if (staff == null) return [];
    final rows = await client
        .from('staff')
        .select()
        .eq('restaurant_id', staff['restaurant_id'] as String)
        .order('added_at', ascending: true);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Staff member joins an existing restaurant using an invite code.
  /// Returns the staff row on success.
  ///
  /// The invite lookup and auth-user linking are performed atomically inside
  /// the [claim_invite_code] SECURITY DEFINER RPC, which eliminates the
  /// TOCTOU race present in a client-side check-then-update approach and
  /// prevents cross-restaurant invite code enumeration.
  static Future<Map<String, dynamic>> joinWithInviteCode({
    required String email,
    required String password,
    required String inviteCode,
  }) async {
    // 1. Create the auth account first so auth.uid() is available for the RPC.
    final response = await auth.signUp(email: email, password: password);
    if (response.user == null) {
      throw Exception('Signup failed. Please try again.');
    }

    // 2. Atomically validate the code and link this auth user to the staff row.
    //    The RPC raises 'invalid_or_used_code' if the code is wrong or already
    //    claimed, which surfaces as a PostgrestException we re-throw clearly.
    try {
      final result = await client.rpc(
        'claim_invite_code',
        params: {'p_code': inviteCode.trim().toUpperCase()},
      );
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      // Sign the newly-created auth user out so they don't have a dangling
      // account if the invite claim fails.
      await auth.signOut();
      final msg = e.toString();
      if (msg.contains('expired_code')) {
        throw Exception(
          'This invite code has expired. Ask your manager to generate a new one.',
        );
      }
      if (msg.contains('invalid_or_used_code')) {
        throw Exception('Invalid invite code. Please check with your manager.');
      }
      rethrow;
    }
  }

  /// Add a pending staff member and return the generated invite code.
  /// The code expires after 72 hours; after that the staff member cannot join
  /// and the owner must generate a new invite.
  static Future<({String code, DateTime expiresAt})> addPendingStaff({
    required String name,
    required String role,
  }) async {
    final staff = await fetchStaffRecord();
    if (staff == null) throw Exception('Not signed in');
    final code = _generateInviteCode();
    final expiresAt = DateTime.now().toUtc().add(const Duration(hours: 72));
    await client.from('staff').insert({
      'restaurant_id': staff['restaurant_id'],
      'name': name,
      'role': role,
      'invite_code': code,
      'invite_expires_at': expiresAt.toIso8601String(),
      'is_active': true,
    });
    return (code: code, expiresAt: expiresAt);
  }

  /// Deactivate a staff member (soft-delete).
  static Future<void> deactivateStaff(String staffId) async {
    await client
        .from('staff')
        .update({'is_active': false})
        .eq('id', staffId);
  }

  /// Reactivate a previously deactivated staff member.
  static Future<void> reactivateStaff(String staffId) async {
    await client
        .from('staff')
        .update({'is_active': true})
        .eq('id', staffId);
  }

  static String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  // ── Subscription / plan helpers ──────────────────────────────────────────

  /// Returns true if the restaurant's subscription is currently active
  /// (plan = 'trial' with trial not expired, or plan = 'starter'/'standard'/'business').
  static bool isPlanActive(Map<String, dynamic> restaurant) {
    final plan = restaurant['plan'] as String? ?? 'trial';
    if (plan == 'suspended') return false;
    if (plan == 'trial') {
      final trialEnd = restaurant['trial_end_date'];
      if (trialEnd == null) return false;
      return DateTime.parse(trialEnd as String).isAfter(DateTime.now().toUtc());
    }
    return true; // starter / standard / business
  }

  /// Returns days left in trial, or null if not on trial.
  static int? trialDaysLeft(Map<String, dynamic> restaurant) {
    if (restaurant['plan'] != 'trial') return null;
    final trialEnd = restaurant['trial_end_date'];
    if (trialEnd == null) return 0;
    final diff = DateTime.parse(trialEnd as String)
        .toUtc()
        .difference(DateTime.now().toUtc());
    return diff.inDays.clamp(0, 99);
  }
}
