import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'repositories/activity_log_repository.dart';
import 'services/supabase/supabase_service.dart';
import 'services/sync/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseService.initialize();

  // Start cloud sync (push pending rows + initial pull on new device)
  SyncService.instance.start();

  // Keep activity log tidy — purge entries older than 90 days
  unawaited(ActivityLogRepository.instance.purgeOlderThan(90));

  // Portrait + landscape supported; lock to portrait on small phones handled by screenutil
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ProviderScope(child: PlatoDeskApp()));
}
