import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/media_service.dart';

/// Right panel: unified media controller with artwork, metadata, and transport controls.
class MediaPanel extends StatefulWidget {
  final MediaMetadata metadata;
  final Color accentColor;

  const MediaPanel({
    super.key,
    required this.metadata,
    required this.accentColor,
  });

  @override
  State<MediaPanel> createState() => _MediaPanelState();
}

class _MediaPanelState extends State<MediaPanel> with TickerProviderStateMixin {
  final MediaService _mediaService = MediaService();

  // Animation for play/pause icon morphing
  late AnimationController _playPauseController;

  // Artwork crossfade tracking
  Uint8List? _artworkBytes;
  Uint8List? _previousArtwork;
  late AnimationController _artworkFadeController;

  @override
  void initState() {
    super.initState();

    _playPauseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: widget.metadata.isPlaying ? 1.0 : 0.0,
    );

    _artworkFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      value: 1.0,
    );

    _artworkBytes = widget.metadata.artworkBytes;
  }

  @override
  void didUpdateWidget(covariant MediaPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Synchronize play/pause icon animation state
    if (widget.metadata.isPlaying != oldWidget.metadata.isPlaying) {
      if (widget.metadata.isPlaying) {
        _playPauseController.forward();
      } else {
        _playPauseController.reverse();
      }
    }

    // Trigger crossfade of artwork image when artwork changes
    if (!listEquals(widget.metadata.artworkBytes, oldWidget.metadata.artworkBytes)) {
      if (widget.metadata.artworkBytes != null) {
        _previousArtwork = oldWidget.metadata.artworkBytes;
        _artworkBytes = widget.metadata.artworkBytes;
        _artworkFadeController.forward(from: 0.0);
      } else {
        _artworkBytes = null;
        _previousArtwork = null;
      }
    }
  }

  @override
  void dispose() {
    _playPauseController.dispose();
    _artworkFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metadata = widget.metadata;

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: metadata.error == 'PERMISSION_REQUIRED'
          ? _buildPermissionPrompt()
          : metadata.hasSession
              ? _buildMediaController(metadata)
              : _buildNoSessionState(),
    );
  }

  Widget _buildPermissionPrompt() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_off_rounded,
                size: 48,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 16),
              Text(
                'Notification Access Required',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: widget.accentColor.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Go to Settings → Apps → Special Access →\nNotification Access and enable Standby Dock',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.45),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.accentColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.settings_suggest_rounded, size: 16),
                label: Text(
                  'Grant Permission',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                onPressed: () {
                  _mediaService.openNotificationSettings();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoSessionState() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.music_off_rounded,
                size: 48,
                color: Colors.white.withValues(alpha: 0.12),
              ),
              const SizedBox(height: 16),
              Text(
                'No Media Playing',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.25),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Play something in Spotify, YouTube Music, etc.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaController(MediaMetadata metadata) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ---- Album Artwork ----
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _artworkBytes != null
                      ? [
                          BoxShadow(
                            color: widget.accentColor.withValues(alpha: 0.24),
                            blurRadius: 28,
                            spreadRadius: -4,
                          ),
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedBuilder(
                    animation: _artworkFadeController,
                    builder: (context, _) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          // Previous artwork fading out
                          if (_previousArtwork != null)
                            Opacity(
                              opacity: max(0.0, min(1.0, 1.0 - _artworkFadeController.value)),
                              child: Image.memory(
                                _previousArtwork!,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              ),
                            ),
                          // Current artwork fading in
                          if (_artworkBytes != null)
                            Opacity(
                              opacity: _artworkFadeController.value,
                              child: Image.memory(
                                _artworkBytes!,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              ),
                            ),
                          // Placeholder gradient when no artwork
                          if (_artworkBytes == null)
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF161622),
                                    Color(0xFF12121E),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.album_rounded,
                                  size: 60,
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ---- Track Metadata ----
        SizedBox(
          height: 50,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.2),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: FittedBox(
              key: ValueKey<String>('${metadata.title}_${metadata.artist}'),
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    metadata.title.isNotEmpty ? metadata.title : 'Unknown Track',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    metadata.artist.isNotEmpty ? metadata.artist : 'Unknown Artist',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.4),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // ---- Soundwave Visualizer ----
        _SoundwaveVisualizer(
          isPlaying: metadata.isPlaying,
          color: widget.accentColor,
        ),
        const SizedBox(height: 10),

        // ---- Transport Controls ----
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Skip Previous
            _InteractiveTransportButton(
              icon: Icons.skip_previous_rounded,
              size: 32,
              accentColor: widget.accentColor,
              onPressed: () => _mediaService.previous(),
            ),
            const SizedBox(width: 24),
            // Play / Pause
            _PlayPauseButton(
              animation: _playPauseController,
              accentColor: widget.accentColor,
              onPressed: () => _mediaService.playPause(),
            ),
            const SizedBox(width: 24),
            // Skip Next
            _InteractiveTransportButton(
              icon: Icons.skip_next_rounded,
              size: 32,
              accentColor: widget.accentColor,
              onPressed: () => _mediaService.next(),
            ),
          ],
        ),
      ],
    );
  }
}

/// Pulsing glassmorphic visualizer soundwave lines.
class _SoundwaveVisualizer extends StatefulWidget {
  final bool isPlaying;
  final Color color;

  const _SoundwaveVisualizer({
    required this.isPlaying,
    required this.color,
  });

  @override
  State<_SoundwaveVisualizer> createState() => _SoundwaveVisualizerState();
}

class _SoundwaveVisualizerState extends State<_SoundwaveVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _baseHeights = const [0.2, 0.7, 0.4, 0.9, 0.3, 0.8, 0.5];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _SoundwaveVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_baseHeights.length, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final val = _controller.value;
              final wave = sin((val * 2 * pi) + (index * 1.2)) * 0.5 + 0.5;
              final height = 3.0 + (15.0 * _baseHeights[index] * (widget.isPlaying ? wave : 0.15));

              return Container(
                width: 3,
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: widget.isPlaying ? 0.75 : 0.25),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

/// A transport control button with scale-down touch feedback.
class _InteractiveTransportButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color accentColor;
  final VoidCallback onPressed;

  const _InteractiveTransportButton({
    required this.icon,
    required this.size,
    required this.accentColor,
    required this.onPressed,
  });

  @override
  State<_InteractiveTransportButton> createState() =>
      __InteractiveTransportButtonState();
}

class __InteractiveTransportButtonState extends State<_InteractiveTransportButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.86).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(50),
          splashColor: widget.accentColor.withValues(alpha: 0.15),
          highlightColor: widget.accentColor.withValues(alpha: 0.08),
          onTapDown: (_) => _animController.forward(),
          onTapUp: (_) {
            _animController.reverse();
            widget.onPressed();
          },
          onTapCancel: () => _animController.reverse(),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              widget.icon,
              size: widget.size,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

/// Press-responsive play/pause button with tap scale feedback and glow styling.
class _PlayPauseButton extends StatefulWidget {
  final AnimationController animation;
  final Color accentColor;
  final VoidCallback onPressed;

  const _PlayPauseButton({
    required this.animation,
    required this.accentColor,
    required this.onPressed,
  });

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.90).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          splashColor: Colors.black.withValues(alpha: 0.18),
          highlightColor: Colors.black.withValues(alpha: 0.08),
          onTapDown: (_) => _scaleController.forward(),
          onTapUp: (_) {
            _scaleController.reverse();
            widget.onPressed();
          },
          onTapCancel: () => _scaleController.reverse(),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.accentColor,
              boxShadow: [
                BoxShadow(
                  color: widget.accentColor.withValues(alpha: 0.4),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: AnimatedIcon(
              icon: AnimatedIcons.play_pause,
              progress: widget.animation,
              size: 36,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}
