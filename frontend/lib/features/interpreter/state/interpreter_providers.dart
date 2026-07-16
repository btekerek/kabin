import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/state/auth_providers.dart';
import '../data/interpreter_repository.dart';

final interpreterRepositoryProvider = Provider<InterpreterRepository>((ref) {
  return InterpreterRepository(ref.watch(dioProvider));
});
