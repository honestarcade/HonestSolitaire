/// The app's one bridge to Android (#83, #91): the files directory and
/// opening a URL in the browser. Nothing here touches the network; the
/// platform-surface guard keeps the surface to exactly these two calls.
library;

import 'package:flutter/services.dart';

class PlatformChannel {
  PlatformChannel([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel(name);

  static const String name = 'honestsolitaire/platform';

  final MethodChannel _channel;

  /// The app's private files directory (`context.filesDir`), or null when
  /// the platform does not answer.
  Future<String?> filesDir() => _channel.invokeMethod<String>('filesDir');

  /// Opens [url] in the phone's browser; false when nothing could open it.
  Future<bool> openUrl(String url) async =>
      await _channel.invokeMethod<bool>('openUrl', {'url': url}) ?? false;
}
