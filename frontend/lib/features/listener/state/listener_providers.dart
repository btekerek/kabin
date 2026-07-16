import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/listener/listener_identity.dart';
import '../../auth/state/auth_providers.dart';
import '../data/listener_repository.dart';

final listenerRepositoryProvider = Provider<ListenerRepository>((ref) {
  return ListenerRepository(ref.watch(dioProvider));
});

final listenerIdentityProvider = Provider<ListenerIdentity>((ref) {
  return ListenerIdentity();
});

/// The persisted listener_uuid, created on first use (see ADR-002 /
/// ListenerIdentity). A plain FutureProvider is enough - this value
/// never changes once created, there's no "state" to manage beyond
/// reading it.
final listenerUuidProvider = FutureProvider<String>((ref) {
  return ref.watch(listenerIdentityProvider).getOrCreate();
});
