import 'package:supabase_flutter/supabase_flutter.dart';

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

    // Insert restaurant
    final restaurant = await client
        .from('restaurants')
        .insert({
          'name': restaurantName,
          'owner_email': user.email,
          'address': address ?? '',
          'phone': phone ?? '',
          'plan': 'trial',
          'trial_end_date': trialEnd.toIso8601String(),
          'max_devices': 1,
        })
        .select()
        .single();

    // Insert owner staff record
    await client.from('staff').insert({
      'restaurant_id': restaurant['id'],
      'auth_user_id': user.id,
      'name': ownerName,
      'role': 'owner',
      'is_active': true,
    });
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
