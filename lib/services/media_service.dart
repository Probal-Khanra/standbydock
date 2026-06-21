import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

/// Model representing the current media playback state from the system.
class MediaMetadata {
  final String title;
  final String artist;
  final String album;
  final Uint8List? artworkBytes;
  final bool isPlaying;
  final bool hasSession;
  final String? error;

  const MediaMetadata({
    this.title = '',
    this.artist = '',
    this.album = '',
    this.artworkBytes,
    this.isPlaying = false,
    this.hasSession = false,
    this.error,
  });

  factory MediaMetadata.fromMap(Map<dynamic, dynamic> map) {
    Uint8List? artwork;
    final artworkStr = map['artwork'] as String? ?? '';
    if (artworkStr.isNotEmpty) {
      try {
        artwork = base64Decode(artworkStr);
      } catch (_) {
        artwork = null;
      }
    }

    return MediaMetadata(
      title: map['title'] as String? ?? '',
      artist: map['artist'] as String? ?? '',
      album: map['album'] as String? ?? '',
      artworkBytes: artwork,
      isPlaying: map['isPlaying'] as bool? ?? false,
      hasSession: map['hasSession'] as bool? ?? false,
      error: map['error'] as String?,
    );
  }

  /// Returns true if there's meaningful metadata to display.
  bool get hasMetadata => title.isNotEmpty || artist.isNotEmpty;
}

/// Service wrapping the native platform channels for media control.
class MediaService {
  static const _eventChannel =
      EventChannel('com.antigravity.standby_dock/media');
  static const _methodChannel =
      MethodChannel('com.antigravity.standby_dock/media_control');

  /// Broadcast stream of media metadata updates from the native layer.
  /// The native side pushes updates at ~1Hz and on playback state changes.
  Stream<MediaMetadata> get mediaStream {
    return _eventChannel.receiveBroadcastStream().map((dynamic event) {
      if (event is Map) {
        return MediaMetadata.fromMap(event);
      }
      return const MediaMetadata();
    }).handleError((dynamic error) {
      return const MediaMetadata();
    });
  }

  Future<void> play() => _methodChannel.invokeMethod('play');
  Future<void> pause() => _methodChannel.invokeMethod('pause');
  Future<void> next() => _methodChannel.invokeMethod('next');
  Future<void> previous() => _methodChannel.invokeMethod('previous');
  Future<void> playPause() => _methodChannel.invokeMethod('playPause');
  Future<void> openNotificationSettings() => _methodChannel.invokeMethod('openNotificationSettings');
}
