import '../domain/interpreter_join_result.dart';

/// Carried via go_router's `extra` from the join screen to the
/// broadcasting screen. `interpreterCode` is kept alongside the join
/// result because ChannelLeaveView (unlike the listener flow) needs it
/// again to release the claim on the way out.
class BroadcastingArgs {
  const BroadcastingArgs({
    required this.joinResult,
    required this.interpreterCode,
  });

  final InterpreterJoinResult joinResult;
  final String interpreterCode;
}
