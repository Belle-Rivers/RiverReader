import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/current_user_provider.dart';
import '../data/home_api.dart';

final homeApiProvider = Provider<HomeApi>((ref) => HomeApi());

/// Dashboard data from `GET /v1/me/home` (stats, resume reading, recent vault words).
final homeSummaryProvider = FutureProvider<HomeSummaryModel?>((ref) async {
  final String? userId = ref.watch(sessionUserIdProvider);
  if (userId == null) {
    return null;
  }
  final HomeApi api = ref.read(homeApiProvider);
  return api.fetchHome(userId);
});
