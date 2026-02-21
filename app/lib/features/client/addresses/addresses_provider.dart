import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/user_address.dart';
import '../../auth/state/auth_notifier.dart';
import '../../auth/state/auth_state.dart';
import 'addresses_repository.dart';

final addressesRepositoryProvider = Provider<AddressesRepository>((ref) {
  final dio = ref.read(dioProvider);
  return AddressesRepository(dio);
});

final userAddressesProvider = FutureProvider<List<UserAddress>>((ref) async {
  final authState = ref.watch(authNotifierProvider);
  if (authState.status != AuthStatus.authenticated || authState.user == null) {
    return const <UserAddress>[];
  }

  final repository = ref.read(addressesRepositoryProvider);
  return repository.getMyAddresses();
});
