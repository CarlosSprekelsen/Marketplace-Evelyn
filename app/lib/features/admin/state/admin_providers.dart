import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/state/auth_notifier.dart';
import '../admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final dio = ref.read(dioProvider);
  return AdminRepository(dio);
});
