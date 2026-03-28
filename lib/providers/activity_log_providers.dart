import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_log_model.dart';
import '../repositories/activity_log_repository.dart';

final activityLogRepositoryProvider = Provider<ActivityLogRepository>(
  (_) => ActivityLogRepository.instance,
);

final activityLogsProvider = FutureProvider<List<ActivityLogModel>>((ref) {
  return ref.watch(activityLogRepositoryProvider).getAll();
});
