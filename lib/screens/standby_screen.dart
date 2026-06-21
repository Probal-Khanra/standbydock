import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/media_service.dart';
import '../widgets/clock_panel.dart';
import '../widgets/media_panel.dart';
import '../widgets/utility_panel.dart';

enum ClockStyle { minimalist, bold, flip, analog }
enum LayoutMode { split, swap, clockOnly, mediaOnly }
enum RightPanelUtility {
  media,
  stopwatch,
  timer,
  calendar,
  todo,
  pomodoro,
  worldClock,
  notes,
  zen
}

class StandbyScreen extends StatefulWidget {
  const StandbyScreen({super.key});

  @override
  State<StandbyScreen> createState() => _StandbyScreenState();
}

class _StandbyScreenState extends State<StandbyScreen>
    with TickerProviderStateMixin {
  final Random _random = Random();
  final MediaService _mediaService = MediaService();
  StreamSubscription? _mediaSubscription;

  // Configuration States
  ClockStyle _clockStyle = ClockStyle.minimalist;
  LayoutMode _layoutMode = LayoutMode.split;
  RightPanelUtility _utilityMode = RightPanelUtility.media;
  Color _accentColor = const Color(0xFF00E5FF);
  bool _showAmbientGlow = true;
  bool _keepAwake = true;
  bool _onboardingDismissed = false;

  // Zen Focus Mode (Double-Tap)
  bool _isZenMode = false;

  // Alarm Breathing Edge Glow
  bool _isAlarmActive = false;
  late AnimationController _alarmController;

  // Media States
  MediaMetadata _metadata = const MediaMetadata();

  // Settings Panel States
  bool _isSettingsOpen = false;
  bool _showSettingsIcon = false;
  Timer? _settingsIconTimer;

  // OLED Micro-drift States
  double _driftX = 0.0;
  double _driftY = 0.0;
  Timer? _driftTimer;
  late AnimationController _driftAnimController;
  late Animation<double> _driftXAnimation;
  late Animation<double> _driftYAnimation;

  final List<Color> _accentColors = const [
    Color(0xFF00E5FF), // Cyan
    Color(0xFF00E676), // Green
    Color(0xFFFFD600), // Amber
    Color(0xFFFF6D00), // Orange
    Color(0xFFFF2A85), // Pink
    Color(0xFFD500F9), // Purple
    Color(0xFFFF1744), // Night Mode Red
    Color(0xFFFFFFFF), // Pure White
    Color(0xFF9E9E9E), // Sleek Grey
    Color(0xFF90CAF9), // Sky Blue
    Color(0xFFFFAB91), // Rose Gold
    Color(0xFFA5D6A7), // Mint Green
    Color(0xFFE1BEE7), // Lavender
  ];

  @override
  void initState() {
    super.initState();

    // 1. Initialize Micro-drift
    _driftAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _driftXAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _driftAnimController, curve: Curves.easeInOut),
    );
    _driftYAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _driftAnimController, curve: Curves.easeInOut),
    );

    _driftTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _applyDrift();
    });

    // 2. Initialize Alarm Controller
    _alarmController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // 3. Subscribe to Media Stream
    _mediaSubscription = _mediaService.mediaStream.listen((metadata) {
      if (!mounted) return;
      setState(() {
        _metadata = metadata;
      });
    });

    // 4. Load Saved Preferences
    _loadPreferences();

    _triggerSettingsIconReveal();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _clockStyle = ClockStyle.values[prefs.getInt('clockStyle') ?? 0];
        _layoutMode = LayoutMode.values[prefs.getInt('layoutMode') ?? 0];
        _utilityMode = RightPanelUtility.values[prefs.getInt('utilityMode') ?? 0];
        _showAmbientGlow = prefs.getBool('showAmbientGlow') ?? true;
        _keepAwake = prefs.getBool('keepAwake') ?? true;
        _onboardingDismissed = prefs.getBool('onboardingDismissed') ?? false;
        
        final savedColorVal = prefs.getInt('accentColor');
        if (savedColorVal != null) {
          _accentColor = Color(savedColorVal);
        }

        // Apply loaded wakelock setting
        if (_keepAwake) {
          WakelockPlus.enable();
        } else {
          WakelockPlus.disable();
        }
      });
    } catch (_) {
      // Fallback silently to defaults
    }
  }

  Future<void> _savePreference(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  Future<void> _saveBoolPreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _applyDrift() {
    final newDriftX = (_random.nextDouble() * 4.0) - 2.0;
    final newDriftY = (_random.nextDouble() * 4.0) - 2.0;

    setState(() {
      _driftXAnimation = Tween<double>(begin: _driftX, end: newDriftX).animate(
        CurvedAnimation(parent: _driftAnimController, curve: Curves.easeInOut),
      );
      _driftYAnimation = Tween<double>(begin: _driftY, end: newDriftY).animate(
        CurvedAnimation(parent: _driftAnimController, curve: Curves.easeInOut),
      );
      _driftX = newDriftX;
      _driftY = newDriftY;
    });

    _driftAnimController.forward(from: 0.0);
  }

  void _triggerSettingsIconReveal() {
    setState(() {
      _showSettingsIcon = true;
    });
    _settingsIconTimer?.cancel();
    _settingsIconTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isSettingsOpen) {
        setState(() {
          _showSettingsIcon = false;
        });
      }
    });
  }

  void _toggleZenMode() {
    setState(() {
      _isZenMode = !_isZenMode;
    });
  }

  void _startAlarmGlow() {
    setState(() {
      _isAlarmActive = true;
    });
    _alarmController.repeat(reverse: true);
  }

  void _stopAlarmGlow() {
    _alarmController.stop();
    setState(() {
      _isAlarmActive = false;
    });
  }

  @override
  void dispose() {
    _driftTimer?.cancel();
    _mediaSubscription?.cancel();
    _settingsIconTimer?.cancel();
    _driftAnimController.dispose();
    _alarmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    final effectiveAccentColor = _accentColor;
    if (_metadata.error == 'PERMISSION_REQUIRED' && !_onboardingDismissed) {
      return _buildOnboardingScreen(effectiveAccentColor);
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final halfWidth = screenWidth / 2;

          // Determine layouts while taking Zen Mode into account
          final activeLayout = _isZenMode ? LayoutMode.clockOnly : _layoutMode;

          double clockLeft = 0;
          double clockWidth = halfWidth;
          double clockOpacity = 1.0;

          double mediaLeft = halfWidth;
          double mediaWidth = halfWidth;
          double mediaOpacity = 1.0;

          double dividerLeft = halfWidth;
          double dividerOpacity = 1.0;

          switch (activeLayout) {
            case LayoutMode.split:
              clockLeft = 0;
              clockWidth = halfWidth;
              mediaLeft = halfWidth;
              mediaWidth = halfWidth;
              dividerLeft = halfWidth;
              break;
            case LayoutMode.swap:
              clockLeft = halfWidth;
              clockWidth = halfWidth;
              mediaLeft = 0;
              mediaWidth = halfWidth;
              dividerLeft = halfWidth;
              break;
            case LayoutMode.clockOnly:
              clockLeft = 0;
              clockWidth = screenWidth;
              mediaLeft = screenWidth;
              mediaWidth = halfWidth;
              clockOpacity = 1.0;
              mediaOpacity = 0.0;
              dividerLeft = screenWidth;
              dividerOpacity = 0.0;
              break;
            case LayoutMode.mediaOnly:
              clockLeft = -halfWidth;
              clockWidth = halfWidth;
              mediaLeft = 0;
              mediaWidth = screenWidth;
              clockOpacity = 0.0;
              mediaOpacity = 1.0;
              dividerLeft = 0;
              dividerOpacity = 0.0;
              break;
          }

          final mainStack = Stack(
            clipBehavior: Clip.antiAlias,
            children: [
              // 1. Ambient Background Glow (Artwork Aura)
              if (_showAmbientGlow && _metadata.hasSession && _metadata.artworkBytes != null && !_isZenMode)
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 1000),
                    child: Image.memory(
                      _metadata.artworkBytes!,
                      key: ValueKey('${_metadata.title}_${_metadata.artist}'),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
              // Dim / Blur overlay for background glow
              if (_showAmbientGlow && _metadata.hasSession && _metadata.artworkBytes != null && !_isZenMode)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.82),
                    ),
                  ),
                ),

              // 2. Main Content Stack (with micro-drift applied)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    if (_isSettingsOpen) {
                      setState(() {
                        _isSettingsOpen = false;
                      });
                      _triggerSettingsIconReveal();
                    } else {
                      _triggerSettingsIconReveal();
                    }
                  },
                  child: AnimatedBuilder(
                    animation: _driftAnimController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(
                          _driftXAnimation.value,
                          _driftYAnimation.value,
                        ),
                        child: child,
                      );
                    },
                    child: Stack(
                      children: [
                        // Clock Panel (with Zen Mode double tap gesture)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeInOutCubic,
                          left: clockLeft,
                          width: clockWidth,
                          top: 0,
                          bottom: 0,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 450),
                            opacity: clockOpacity,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onDoubleTap: _toggleZenMode,
                              child: ClockPanel(
                                accentColor: effectiveAccentColor,
                                clockStyle: _clockStyle,
                              ),
                            ),
                          ),
                        ),

                        // Vertical Divider
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeInOutCubic,
                          left: dividerLeft,
                          width: 1,
                          top: 0,
                          bottom: 0,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 400),
                            opacity: dividerOpacity,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 40),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    effectiveAccentColor.withValues(alpha: 0.0),
                                    effectiveAccentColor.withValues(alpha: 0.08),
                                    effectiveAccentColor.withValues(alpha: 0.08),
                                    effectiveAccentColor.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Media / Utility Panel
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeInOutCubic,
                          left: mediaLeft,
                          width: mediaWidth,
                          top: 0,
                          bottom: 0,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 450),
                            opacity: mediaOpacity,
                            child: _buildRightUtilityPanel(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Settings Trigger Button (Auto-fade)
              Positioned(
                top: 20,
                right: 20,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _showSettingsIcon ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !_showSettingsIcon,
                    child: FloatingActionButton.small(
                      heroTag: 'settings_btn',
                      backgroundColor: Colors.black.withValues(alpha: 0.5),
                      foregroundColor: effectiveAccentColor,
                      shape: CircleBorder(
                        side: BorderSide(
                          color: effectiveAccentColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _isSettingsOpen = true;
                          _showSettingsIcon = true;
                        });
                        _settingsIconTimer?.cancel();
                      },
                      child: const Icon(Icons.settings_rounded),
                    ),
                  ),
                ),
              ),

              // 4. Outside Tap dismisser overlay for settings panel
              if (_isSettingsOpen)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      setState(() {
                        _isSettingsOpen = false;
                      });
                      _triggerSettingsIconReveal();
                    },
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ),

              // 5. Glassmorphic Settings Drawer Panel
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                top: 0,
                bottom: 0,
                right: _isSettingsOpen ? 0 : -320,
                width: 300,
                child: Stack(
                  children: [
                    // Glass filter background
                    Positioned.fill(
                      child: ClipRRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              border: Border(
                                left: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Scrollable configuration settings content
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'STANDBY SETTINGS',
                                style: TextStyle(
                                  color: effectiveAccentColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const Divider(color: Colors.white10, height: 24),
                              
                              // SECTION: Clock style selection
                              _buildSectionTitle('Clock Face'),
                              const SizedBox(height: 8),
                              _buildGridOptions([
                                _buildSettingsChip('Minimal', ClockStyle.minimalist, _clockStyle, () {
                                  setState(() => _clockStyle = ClockStyle.minimalist);
                                  _savePreference('clockStyle', ClockStyle.minimalist.index);
                                }),
                                _buildSettingsChip('Bold Tech', ClockStyle.bold, _clockStyle, () {
                                  setState(() => _clockStyle = ClockStyle.bold);
                                  _savePreference('clockStyle', ClockStyle.bold.index);
                                }),
                                _buildSettingsChip('Flip Card', ClockStyle.flip, _clockStyle, () {
                                  setState(() => _clockStyle = ClockStyle.flip);
                                  _savePreference('clockStyle', ClockStyle.flip.index);
                                }),
                                _buildSettingsChip('Analog Face', ClockStyle.analog, _clockStyle, () {
                                  setState(() => _clockStyle = ClockStyle.analog);
                                  _savePreference('clockStyle', ClockStyle.analog.index);
                                }),
                              ]),
                              const SizedBox(height: 20),

                              // SECTION: Utility Selection
                              _buildSectionTitle('Right Panel Utility'),
                              const SizedBox(height: 8),
                              _buildGridOptions([
                                _buildSettingsChip('Media Player', RightPanelUtility.media, _utilityMode, () {
                                  setState(() => _utilityMode = RightPanelUtility.media);
                                  _savePreference('utilityMode', RightPanelUtility.media.index);
                                }),
                                _buildSettingsChip('Stopwatch', RightPanelUtility.stopwatch, _utilityMode, () {
                                  setState(() => _utilityMode = RightPanelUtility.stopwatch);
                                  _savePreference('utilityMode', RightPanelUtility.stopwatch.index);
                                }),
                                _buildSettingsChip('Timer', RightPanelUtility.timer, _utilityMode, () {
                                  setState(() => _utilityMode = RightPanelUtility.timer);
                                  _savePreference('utilityMode', RightPanelUtility.timer.index);
                                }),
                                _buildSettingsChip('Calendar', RightPanelUtility.calendar, _utilityMode, () {
                                  setState(() => _utilityMode = RightPanelUtility.calendar);
                                  _savePreference('utilityMode', RightPanelUtility.calendar.index);
                                }),
                                _buildSettingsChip('To-Do List', RightPanelUtility.todo, _utilityMode, () {
                                  setState(() => _utilityMode = RightPanelUtility.todo);
                                  _savePreference('utilityMode', RightPanelUtility.todo.index);
                                }),
                                _buildSettingsChip('Pomodoro', RightPanelUtility.pomodoro, _utilityMode, () {
                                  setState(() => _utilityMode = RightPanelUtility.pomodoro);
                                  _savePreference('utilityMode', RightPanelUtility.pomodoro.index);
                                }),
                                _buildSettingsChip('World Clock', RightPanelUtility.worldClock, _utilityMode, () {
                                  setState(() => _utilityMode = RightPanelUtility.worldClock);
                                  _savePreference('utilityMode', RightPanelUtility.worldClock.index);
                                }),
                                _buildSettingsChip('Sticky Note', RightPanelUtility.notes, _utilityMode, () {
                                  setState(() => _utilityMode = RightPanelUtility.notes);
                                  _savePreference('utilityMode', RightPanelUtility.notes.index);
                                }),
                                _buildSettingsChip('Zen Breath', RightPanelUtility.zen, _utilityMode, () {
                                  setState(() => _utilityMode = RightPanelUtility.zen);
                                  _savePreference('utilityMode', RightPanelUtility.zen.index);
                                }),
                              ]),
                              const SizedBox(height: 20),

                              // SECTION: Layout selection
                              _buildSectionTitle('Screen Layout'),
                              const SizedBox(height: 8),
                              _buildGridOptions([
                                _buildSettingsChip('Split View', LayoutMode.split, _layoutMode, () {
                                  setState(() => _layoutMode = LayoutMode.split);
                                  _savePreference('layoutMode', LayoutMode.split.index);
                                }),
                                _buildSettingsChip('Swap Side', LayoutMode.swap, _layoutMode, () {
                                  setState(() => _layoutMode = LayoutMode.swap);
                                  _savePreference('layoutMode', LayoutMode.swap.index);
                                }),
                                _buildSettingsChip('Clock Only', LayoutMode.clockOnly, _layoutMode, () {
                                  setState(() => _layoutMode = LayoutMode.clockOnly);
                                  _savePreference('layoutMode', LayoutMode.clockOnly.index);
                                }),
                                _buildSettingsChip('Media Only', LayoutMode.mediaOnly, _layoutMode, () {
                                  setState(() => _layoutMode = LayoutMode.mediaOnly);
                                  _savePreference('layoutMode', LayoutMode.mediaOnly.index);
                                }),
                              ]),
                              const SizedBox(height: 20),

                              // SECTION: Color selection dots
                              _buildSectionTitle('Accent Theme'),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: _accentColors.map((color) {
                                  final isSelected = color == _accentColor;
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() => _accentColor = color);
                                      _savePreference('accentColor', color.toARGB32());
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: color,
                                        border: Border.all(
                                          color: isSelected ? Colors.white : Colors.transparent,
                                          width: 1.5,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: color.withValues(alpha: 0.5),
                                                  blurRadius: 6,
                                                  spreadRadius: 1,
                                                )
                                              ]
                                            : null,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 20),

                              // SECTION: Ambient glow backdrop
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: _buildSectionTitle('Ambient Backdrop Glow'),
                                  ),
                                  Switch(
                                    activeThumbColor: effectiveAccentColor,
                                    activeTrackColor: effectiveAccentColor.withValues(alpha: 0.5),
                                    inactiveTrackColor: Colors.white12,
                                    value: _showAmbientGlow,
                                    onChanged: (val) {
                                      setState(() => _showAmbientGlow = val);
                                      _saveBoolPreference('showAmbientGlow', val);
                                    },
                                  ),
                                ],
                              ),

                              // SECTION: Keep Screen Awake
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: _buildSectionTitle('Keep Screen Awake'),
                                  ),
                                  Switch(
                                    activeThumbColor: effectiveAccentColor,
                                    activeTrackColor: effectiveAccentColor.withValues(alpha: 0.5),
                                    inactiveTrackColor: Colors.white12,
                                    value: _keepAwake,
                                    onChanged: (val) {
                                      setState(() => _keepAwake = val);
                                      _saveBoolPreference('keepAwake', val);
                                      if (val) {
                                        WakelockPlus.enable();
                                      } else {
                                        WakelockPlus.disable();
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              // SECTION: About Developer
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline_rounded,
                                          size: 16,
                                          color: effectiveAccentColor,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'ABOUT PROJECT',
                                          style: TextStyle(
                                            color: effectiveAccentColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Standby Dock for Android is an open-source screensaver project inspired by iOS Standby.',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        fontSize: 11,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Developer:',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.3),
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              'Probal',
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.8),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Connect:',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.3),
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            GestureDetector(
                                              onTap: () => _launchURL('https://github.com/Probal-Khanra/standbydock'),
                                              child: Text(
                                                'GitHub Repo',
                                                style: TextStyle(
                                                  color: effectiveAccentColor.withValues(alpha: 0.8),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  decoration: TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            GestureDetector(
                                              onTap: () => _launchURL('https://www.linkedin.com/in/probal-khanra/'),
                                              child: Text(
                                                'LinkedIn',
                                                style: TextStyle(
                                                  color: effectiveAccentColor.withValues(alpha: 0.8),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  decoration: TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'App Version:',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.3),
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              'v1.0.0',
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.6),
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(color: Colors.white10, height: 24),
                              Text(
                                'Double-tap Clock to toggle Zen mode\nTap outside to close settings',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 6. Breathing Alarm Edge Glow (Visual alert for countdown completion)
              if (_isAlarmActive)
                IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _alarmController,
                    builder: (context, _) {
                      final val = _alarmController.value;
                      return Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: effectiveAccentColor.withValues(alpha: val * 0.45),
                            width: 14,
                          ),
                        ),
                      );
                    },
                  ),
                ),

            ],
          );
          return mainStack;
        },
      ),
    );
  }

  Widget _buildRightUtilityPanel() {
    final effectiveAccentColor = _accentColor;
    switch (_utilityMode) {
      case RightPanelUtility.media:
        return MediaPanel(
          metadata: _metadata,
          accentColor: effectiveAccentColor,
        );
      case RightPanelUtility.stopwatch:
        return StopwatchWidget(
          accentColor: effectiveAccentColor,
        );
      case RightPanelUtility.timer:
        return TimerWidget(
          accentColor: effectiveAccentColor,
          onAlarmTriggered: _startAlarmGlow,
          onAlarmCleared: _stopAlarmGlow,
        );
      case RightPanelUtility.calendar:
        return CalendarWidget(
          accentColor: effectiveAccentColor,
        );
      case RightPanelUtility.todo:
        return TodoWidget(
          accentColor: effectiveAccentColor,
        );
      case RightPanelUtility.pomodoro:
        return PomodoroWidget(
          accentColor: effectiveAccentColor,
        );
      case RightPanelUtility.worldClock:
        return WorldClockWidget(
          accentColor: effectiveAccentColor,
        );
      case RightPanelUtility.notes:
        return StickyNoteWidget(
          accentColor: effectiveAccentColor,
        );
      case RightPanelUtility.zen:
        return ZenBreathingWidget(
          accentColor: effectiveAccentColor,
        );
    }
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.55),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildGridOptions(List<Widget> children) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.2,
      children: children,
    );
  }

  Widget _buildSettingsChip<T>(
      String label, T value, T groupValue, VoidCallback onTap) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? _accentColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: isSelected ? _accentColor.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? _accentColor : Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  Widget _buildOnboardingScreen(Color accentColor) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            padding: const EdgeInsets.all(32),
            constraints: const BoxConstraints(maxWidth: 550),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.1),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.music_note_rounded,
                    size: 40,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Welcome to Standby Dock',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'To display real-time music updates, album art, and controls on your dashboard, Standby Dock requires Notification Access.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.5,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.security_rounded,
                        color: accentColor.withValues(alpha: 0.8),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your privacy matters: No personal data or notifications are ever read, saved, or sent off your device.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            height: 1.4,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.settings_suggest_rounded, size: 18),
                      label: Text(
                        'Enable Notification Access',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      onPressed: () {
                        _mediaService.openNotificationSettings();
                      },
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.7),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Explore Standby',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      onPressed: () async {
                        setState(() {
                          _onboardingDismissed = true;
                        });
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('onboardingDismissed', true);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
