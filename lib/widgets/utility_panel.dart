import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';


/// Panel containing utility tools: Stopwatch, Countdown Timer, or Satisfying Patterns.
class StopwatchWidget extends StatefulWidget {
  final Color accentColor;

  const StopwatchWidget({super.key, required this.accentColor});

  @override
  State<StopwatchWidget> createState() => _StopwatchWidgetState();
}

class _StopwatchWidgetState extends State<StopwatchWidget> {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  final List<String> _laps = [];
  final ScrollController _scrollController = ScrollController();

  void _startPause() {
    setState(() {
      if (_stopwatch.isRunning) {
        _stopwatch.stop();
        _timer?.cancel();
      } else {
        _stopwatch.start();
        _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick()); // ~60fps readout
      }
    });
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  void _resetLap() {
    setState(() {
      if (_stopwatch.isRunning) {
        // Record Lap
        _laps.insert(0, _formatTime(_stopwatch.elapsedMilliseconds));
        _scrollToTop();
      } else {
        // Reset
        _stopwatch.reset();
        _laps.clear();
      }
    });
  }

  void _scrollToTop() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  String _formatTime(int milliseconds) {
    final hundreds = (milliseconds / 10).truncate() % 100;
    final seconds = (milliseconds / 1000).truncate() % 60;
    final minutes = (milliseconds / 60000).truncate() % 60;

    final minStr = minutes.toString().padLeft(2, '0');
    final secStr = seconds.toString().padLeft(2, '0');
    final hundStr = hundreds.toString().padLeft(2, '0');

    return '$minStr:$secStr.$hundStr';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayTime = _formatTime(_stopwatch.elapsedMilliseconds);

    return LayoutBuilder(
      builder: (context, constraints) {
        final showLaps = constraints.maxHeight > 220;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'STOPWATCH',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            // Time Readout
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                displayTime,
                style: GoogleFonts.orbitron(
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  color: widget.accentColor,
                  letterSpacing: 2,
                  shadows: [
                    Shadow(
                      color: widget.accentColor.withValues(alpha: 0.25),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
            if (showLaps) const SizedBox(height: 12),

            // Laps List
            if (showLaps)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _laps.isEmpty
                        ? Center(
                            child: Text(
                              'No Laps Recorded',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.15),
                                fontSize: 12,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            itemCount: _laps.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Lap ${_laps.length - index}',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.35),
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      _laps[index],
                                      style: GoogleFonts.orbitron(
                                        color: widget.accentColor.withValues(alpha: 0.85),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _UtilityActionButton(
                  icon: _stopwatch.isRunning ? Icons.flag_rounded : Icons.replay_rounded,
                  color: widget.accentColor,
                  onPressed: _resetLap,
                ),
                const SizedBox(width: 24),
                _PlayPauseButton(
                  isPlaying: _stopwatch.isRunning,
                  color: widget.accentColor,
                  onPressed: _startPause,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Countdown Timer Panel with Presets, Increment Customizer, and edge-glow triggers.
class TimerWidget extends StatefulWidget {
  final Color accentColor;
  final VoidCallback onAlarmTriggered;
  final VoidCallback onAlarmCleared;

  const TimerWidget({
    super.key,
    required this.accentColor,
    required this.onAlarmTriggered,
    required this.onAlarmCleared,
  });

  @override
  State<TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget> {
  int _secondsRemaining = 0;
  Timer? _countdownTimer;
  bool _isRunning = false;
  bool _isAlarm = false;

  void _addMinutes(int minutes) {
    if (_isAlarm) _clearAlarm();
    setState(() {
      _secondsRemaining += minutes * 60;
    });
  }

  void _toggleStartPause() {
    if (_secondsRemaining <= 0 && !_isAlarm) return;
    if (_isAlarm) {
      _clearAlarm();
      return;
    }

    setState(() {
      if (_isRunning) {
        _countdownTimer?.cancel();
        _isRunning = false;
      } else {
        _isRunning = true;
        _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      }
    });
  }

  void _tick() {
    if (_secondsRemaining > 0) {
      setState(() {
        _secondsRemaining--;
      });
      if (_secondsRemaining == 0) {
        _triggerAlarm();
      }
    }
  }

  void _triggerAlarm() {
    _countdownTimer?.cancel();
    setState(() {
      _isRunning = false;
      _isAlarm = true;
    });
    widget.onAlarmTriggered();
  }

  void _clearAlarm() {
    setState(() {
      _isAlarm = false;
      _secondsRemaining = 0;
    });
    widget.onAlarmCleared();
  }

  void _resetTimer() {
    _countdownTimer?.cancel();
    setState(() {
      _isRunning = false;
      _secondsRemaining = 0;
      if (_isAlarm) _clearAlarm();
    });
  }

  String _formatDuration(int totalSeconds) {
    final hours = (totalSeconds / 3600).truncate();
    final minutes = ((totalSeconds % 3600) / 60).truncate();
    final seconds = totalSeconds % 60;

    final hourStr = hours > 0 ? '${hours.toString().padLeft(2, '0')}:' : '';
    final minStr = minutes.toString().padLeft(2, '0');
    final secStr = seconds.toString().padLeft(2, '0');

    return '$hourStr$minStr:$secStr';
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayTime = _formatDuration(_secondsRemaining);

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isAlarm ? 'TIMER COMPLETED' : 'COUNTDOWN TIMER',
                style: TextStyle(
                  color: _isAlarm ? widget.accentColor : Colors.white.withValues(alpha: 0.35),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),

              // Readout
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  displayTime,
                  style: GoogleFonts.orbitron(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: _isAlarm ? Colors.white : widget.accentColor,
                    letterSpacing: 2,
                    shadows: [
                      BoxShadow(
                        color: widget.accentColor.withValues(alpha: _isAlarm ? 0.8 : 0.25),
                        blurRadius: _isAlarm ? 24 : 10,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Preset Rows
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildPresetButton('3m Tea', 3),
                      const SizedBox(width: 8),
                      _buildPresetButton('15m Nap', 15),
                      const SizedBox(width: 8),
                      _buildPresetButton('25m Focus', 25),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildIncrementButton('+1 min', 1),
                      const SizedBox(width: 8),
                      _buildIncrementButton('+5 min', 5),
                      const SizedBox(width: 8),
                      _buildIncrementButton('+10 min', 10),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _UtilityActionButton(
                    icon: Icons.replay_rounded,
                    color: widget.accentColor,
                    onPressed: _resetTimer,
                  ),
                  const SizedBox(width: 24),
                  _PlayPauseButton(
                    isPlaying: _isRunning,
                    color: widget.accentColor,
                    onPressed: _toggleStartPause,
                    overrideIcon: _isAlarm ? Icons.notifications_off_rounded : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetButton(String label, int minutes) {
    return _PresetButton(
      label: label,
      color: widget.accentColor,
      onPressed: () => _addMinutes(minutes),
    );
  }

  Widget _buildIncrementButton(String label, int minutes) {
    return _PresetButton(
      label: label,
      color: widget.accentColor.withValues(alpha: 0.5),
      onPressed: () => _addMinutes(minutes),
      outlined: true,
    );
  }
}



// ---------------- Helper Components ----------------

class _PresetButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final bool outlined;

  const _PresetButton({
    required this.label,
    required this.color,
    required this.onPressed,
    this.outlined = false,
  });

  @override
  State<_PresetButton> createState() => _PresetButtonState();
}

class _PresetButtonState extends State<_PresetButton>
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.90).animate(
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
          borderRadius: BorderRadius.circular(20),
          splashColor: widget.color.withValues(alpha: 0.2),
          highlightColor: widget.color.withValues(alpha: 0.1),
          onTapDown: (_) => _animController.forward(),
          onTapUp: (_) {
            _animController.reverse();
            widget.onPressed();
          },
          onTapCancel: () => _animController.reverse(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: widget.outlined ? Colors.transparent : widget.color.withValues(alpha: 0.12),
              border: Border.all(
                color: widget.color.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color: widget.outlined ? Colors.white.withValues(alpha: 0.65) : widget.color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UtilityActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _UtilityActionButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  State<_UtilityActionButton> createState() => _UtilityActionButtonState();
}

class _UtilityActionButtonState extends State<_UtilityActionButton>
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
          splashColor: widget.color.withValues(alpha: 0.15),
          highlightColor: widget.color.withValues(alpha: 0.08),
          onTapDown: (_) => _animController.forward(),
          onTapUp: (_) {
            _animController.reverse();
            widget.onPressed();
          },
          onTapCancel: () => _animController.reverse(),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              widget.icon,
              size: 32,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final VoidCallback onPressed;
  final IconData? overrideIcon;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.color,
    required this.onPressed,
    this.overrideIcon,
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.4),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              widget.overrideIcon ?? (widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
              size: 36,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// 8 New Premium Utilities for the Dashboard
// ----------------------------------------------------

class CalendarWidget extends StatelessWidget {
  final Color accentColor;

  const CalendarWidget({super.key, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final startWeekday = firstDayOfMonth.weekday; // 1 = Monday, 7 = Sunday

    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    final weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    final gridItems = <Widget>[];
    final emptyCells = startWeekday - 1;
    for (int i = 0; i < emptyCells; i++) {
      gridItems.add(const SizedBox());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final isToday = day == now.day;
      gridItems.add(
        Center(
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isToday ? accentColor.withValues(alpha: 0.18) : Colors.transparent,
              border: isToday ? Border.all(color: accentColor, width: 1.5) : null,
            ),
            child: Text(
              '$day',
              style: TextStyle(
                color: isToday ? accentColor : Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.02),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${monthNames[now.month - 1].toUpperCase()} ${now.year}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: weekDays.map((day) => Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )).toList(),
              ),
              const Divider(color: Colors.white10, height: 8),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                children: gridItems,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TodoWidget extends StatefulWidget {
  final Color accentColor;

  const TodoWidget({super.key, required this.accentColor});

  @override
  State<TodoWidget> createState() => _TodoWidgetState();
}

class _TodoWidgetState extends State<TodoWidget> {
  final List<Map<String, dynamic>> _todoItems = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadTodoItems();
  }

  Future<void> _loadTodoItems() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('todo_items') ?? [];
    setState(() {
      _todoItems.clear();
      for (var item in list) {
        try {
          _todoItems.add(Map<String, dynamic>.from(jsonDecode(item)));
        } catch (_) {}
      }
    });
  }

  Future<void> _saveTodoItems() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _todoItems.map((item) => jsonEncode(item)).toList();
    await prefs.setStringList('todo_items', list);
  }

  void _addTodoItem() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _todoItems.add({'title': text, 'done': false});
      _textController.clear();
      _saveTodoItems();
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleTodoItem(int index) {
    setState(() {
      _todoItems[index]['done'] = !_todoItems[index]['done'];
      _saveTodoItems();
    });
  }

  void _deleteTodoItem(int index) {
    setState(() {
      _todoItems.removeAt(index);
      _saveTodoItems();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: widget.accentColor.withValues(alpha: 0.02),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'DAILY TASKS',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  onSubmitted: (_) => _addTodoItem(),
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'New task...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 13),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: widget.accentColor.withValues(alpha: 0.4)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: widget.accentColor.withValues(alpha: 0.15),
                  foregroundColor: widget.accentColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                onPressed: _addTodoItem,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _todoItems.isEmpty
                ? Center(
                    child: Text(
                      'All caught up!',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.zero,
                    itemCount: _todoItems.length,
                    itemBuilder: (context, index) {
                      final item = _todoItems[index];
                      final isDone = item['done'] as bool? ?? false;
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.01),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              activeColor: widget.accentColor,
                              value: isDone,
                              onChanged: (_) => _toggleTodoItem(index),
                            ),
                            Expanded(
                              child: Text(
                                item['title'] as String? ?? '',
                                style: TextStyle(
                                  color: isDone ? Colors.white.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13,
                                  decoration: isDone ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close_rounded, size: 18, color: Colors.white.withValues(alpha: 0.2)),
                              onPressed: () => _deleteTodoItem(index),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class PomodoroWidget extends StatefulWidget {
  final Color accentColor;

  const PomodoroWidget({super.key, required this.accentColor});

  @override
  State<PomodoroWidget> createState() => _PomodoroWidgetState();
}

class _PomodoroWidgetState extends State<PomodoroWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int _secondsRemaining = 25 * 60;
  bool _isBreak = false;
  bool _isRunning = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25 * 60),
    );
  }

  void _toggleStart() {
    setState(() {
      if (_isRunning) {
        _timer?.cancel();
        _isRunning = false;
      } else {
        _isRunning = true;
        _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      }
    });
  }

  void _tick() {
    if (_secondsRemaining > 0) {
      setState(() {
        _secondsRemaining--;
        final total = _isBreak ? 5 * 60 : 25 * 60;
        _animController.value = 1.0 - (_secondsRemaining / total);
      });
    } else {
      _timer?.cancel();
      setState(() {
        _isBreak = !_isBreak;
        _secondsRemaining = _isBreak ? 5 * 60 : 25 * 60;
        _animController.duration = Duration(seconds: _secondsRemaining);
        _animController.value = 0.0;
        _isRunning = false;
      });
    }
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _isBreak = false;
      _secondsRemaining = 25 * 60;
      _animController.value = 0.0;
      _isRunning = false;
    });
  }

  String _formatTime() {
    final m = (_secondsRemaining / 60).truncate().toString().padLeft(2, '0');
    final s = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: widget.accentColor.withValues(alpha: 0.02),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _isBreak ? 'BREAK CYCLE' : 'FOCUS CYCLE',
            style: TextStyle(
              color: _isBreak ? Colors.greenAccent : widget.accentColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _animController.value,
                      backgroundColor: Colors.white.withValues(alpha: 0.03),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isBreak ? Colors.greenAccent : widget.accentColor,
                      ),
                      strokeWidth: 6,
                    ),
                    Text(
                      _formatTime(),
                      style: GoogleFonts.orbitron(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.replay_rounded, color: Colors.white.withValues(alpha: 0.5)),
                onPressed: _reset,
              ),
              const SizedBox(width: 16),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: widget.accentColor.withValues(alpha: 0.15),
                  foregroundColor: widget.accentColor,
                ),
                icon: Icon(_isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded),
                onPressed: _toggleStart,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class WorldClockWidget extends StatefulWidget {
  final Color accentColor;

  const WorldClockWidget({super.key, required this.accentColor});

  @override
  State<WorldClockWidget> createState() => _WorldClockWidgetState();
}

class _WorldClockWidgetState extends State<WorldClockWidget> {
  Timer? _timer;
  late DateTime _utcTime;

  @override
  void initState() {
    super.initState();
    _utcTime = DateTime.now().toUtc();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _utcTime = DateTime.now().toUtc();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _buildCityTime(String name, int offsetHours, String flag) {
    final local = _utcTime.add(Duration(hours: offsetHours));
    final timeStr = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                name,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Text(
            timeStr,
            style: GoogleFonts.orbitron(
              color: widget.accentColor.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: widget.accentColor.withValues(alpha: 0.02),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'WORLD TIME',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildCityTime('London', 1, '🇬🇧'),
                  _buildCityTime('New York', -4, '🇺🇸'),
                  _buildCityTime('San Francisco', -7, '🇺🇸'),
                  _buildCityTime('Tokyo', 9, '🇯🇵'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StickyNoteWidget extends StatefulWidget {
  final Color accentColor;

  const StickyNoteWidget({super.key, required this.accentColor});

  @override
  State<StickyNoteWidget> createState() => _StickyNoteWidgetState();
}

class _StickyNoteWidgetState extends State<StickyNoteWidget> {
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  Future<void> _loadNote() async {
    final prefs = await SharedPreferences.getInstance();
    _noteController.text = prefs.getString('sticky_note') ?? '';
  }

  Future<void> _saveNote() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sticky_note', _noteController.text);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: widget.accentColor.withValues(alpha: 0.02),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'STICKY NOTE',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _noteController,
              maxLines: null,
              onChanged: (_) => _saveNote(),
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
                height: 1.4,
              ),
              decoration: const InputDecoration(
                hintText: 'Type your ideas here...',
                hintStyle: TextStyle(
                  color: Colors.white12,
                  fontSize: 13,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ZenBreathingWidget extends StatefulWidget {
  final Color accentColor;

  const ZenBreathingWidget({super.key, required this.accentColor});

  @override
  State<ZenBreathingWidget> createState() => _ZenBreathingWidgetState();
}

class _ZenBreathingWidgetState extends State<ZenBreathingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  String _breathingText = 'Inhale';
  Color _circleColor = Colors.cyan;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.35, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 33.3,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 33.3,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.35).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 33.4,
      ),
    ]).animate(_animController);

    _animController.addListener(() {
      final value = _animController.value;
      if (!mounted) return;
      setState(() {
        if (value < 0.33) {
          _breathingText = 'Inhale';
          _circleColor = widget.accentColor;
        } else if (value < 0.66) {
          _breathingText = 'Hold';
          _circleColor = Colors.amberAccent;
        } else {
          _breathingText = 'Exhale';
          _circleColor = Colors.greenAccent;
        }
      });
    });

    _animController.repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: widget.accentColor.withValues(alpha: 0.02),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'ZEN BREATHING',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, _) {
                final scale = _scaleAnimation.value;
                return Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _circleColor.withValues(alpha: 0.12),
                              border: Border.all(color: _circleColor, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: _circleColor.withValues(alpha: 0.3),
                                  blurRadius: 36 * scale,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          _breathingText,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
