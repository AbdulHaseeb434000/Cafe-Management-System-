/// Tracks user inactivity and signals when the session should be invalidated.
///
/// Usage:
///   - Call [touch] on any user interaction (tap, scroll).
///   - Call [checkTimeout] when the app returns to the foreground.
///   - Call [reset] after a successful re-authentication.
///   - Call [clear] on sign-out so the next session starts clean.
///
/// The [timeout] duration is set from settings by [MainScaffold] on every
/// build, so it reflects any changes to the settings value immediately.
class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  /// How long without interaction before the session is considered expired.
  /// Defaults to 30 minutes; updated by MainScaffold from settings.
  Duration timeout = const Duration(minutes: 30);

  DateTime? _lastActivity;

  /// Returns true once a session has been started (user has logged in).
  bool get isActive => _lastActivity != null;

  /// Record user interaction — resets the inactivity timer.
  void touch() {
    _lastActivity = DateTime.now();
  }

  /// Returns true if inactivity since the last [touch] exceeds [timeout].
  bool get isTimedOut {
    if (_lastActivity == null) return false;
    return DateTime.now().difference(_lastActivity!) > timeout;
  }

  /// Convenience alias used in [MainScaffold.didChangeAppLifecycleState].
  bool checkTimeout() => isTimedOut;

  /// Reset the inactivity timer (e.g. after the user re-authenticates).
  void reset() => _lastActivity = DateTime.now();

  /// Clear all state on sign-out so the next login starts fresh.
  void clear() => _lastActivity = null;
}
