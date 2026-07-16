/// Carried via go_router's `extra` into ChatScreen. `socketQueryParams`
/// is `{'token': accessToken}` for guide/interpreter or
/// `{'listener_uuid': uuid}` for a listener - see
/// ChatConsumer._authorize. `listenerUuid` is repeated here (rather than
/// just read out of socketQueryParams) because it's also needed on
/// every REST send call (MessageCreateSerializer), which is a separate
/// concern from the socket's auth.
class ChatArgs {
  const ChatArgs({
    required this.sessionId,
    required this.socketQueryParams,
    required this.title,
    this.listenerUuid,
  });

  final int sessionId;
  final Map<String, String> socketQueryParams;
  final String title;
  final String? listenerUuid;
}
