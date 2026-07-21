import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

Future<void> requestMicrophonePermission() async {
  if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
    return;
  }
  final status = await Permission.microphone.request();
  if (!status.isGranted) {
    throw StateError('Microphone permission was not granted.');
  }
}
