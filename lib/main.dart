import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const NilaDanceApp());
}

const Color bgColor = Color(0xFF100D18);
const Color cardColor = Color(0xFF211A30);
const Color purpleColor = Color(0xFF9B6DFF);
const Color mutedColor = Color(0xFFB8AEC9);

const String historyKey = 'nila_dance_practice_history';
const String dailyGoalKey = 'nila_daily_goal_minutes';
const String weeklyGoalKey = 'nila_weekly_goal_minutes';
const String profileNameKey = 'nila_profile_name';
const String defaultStyleKey = 'nila_default_style';
const String customStylesKey = 'nila_custom_styles';

const List<String> danceStyles = [
  'Hip-Hop',
  'Bharatanatyam',
  'Contemporary',
  'Freestyle',
  'Western',
  'K-pop',
  'Other',
];

const List<int> dailyGoalOptions = [15, 30, 45, 60];
const List<int> weeklyGoalOptions = [60, 120, 150, 210, 300];

// -------------------- MODELS --------------------

class PracticeSession {
  final String style;
  final int durationSeconds;
  final DateTime completedAt;

  const PracticeSession({
    required this.style,
    required this.durationSeconds,
    required this.completedAt,
  });

  Map<String, dynamic> toJson() => {
        'style': style,
        'durationSeconds': durationSeconds,
        'completedAt': completedAt.toIso8601String(),
      };

  factory PracticeSession.fromJson(Map<String, dynamic> json) {
    return PracticeSession(
      style: json['style'] as String,
      durationSeconds: json['durationSeconds'] as int,
      completedAt: DateTime.parse(json['completedAt'] as String),
    );
  }
}

class DanceAchievement {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool unlocked;

  const DanceAchievement({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.unlocked,
  });
}

// -------------------- FORMAT HELPERS --------------------

String formatTime(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final secs = seconds % 60;

  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${secs.toString().padLeft(2, '0')}';
}

String formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String formatClock(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';

  return '$hour:$minute $period';
}

/// 45 sec / 12 min / 1h 20m
String humanDuration(int seconds) {
  if (seconds >= 3600) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '${h}h ${m}m';
  }
  if (seconds >= 60) return '${seconds ~/ 60} min';
  return '$seconds sec';
}

/// Short label used on chart bars: 45s / 12m
String shortMinutes(int seconds) {
  if (seconds < 60) return '${seconds}s';
  return '${(seconds / 60).round()}m';
}

// -------------------- DATE / STREAK HELPERS --------------------

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Monday of the week that contains [d].
DateTime startOfWeek(DateTime d) => addDays(dayOnly(d), -(d.weekday - 1));

int totalSecondsOf(List<PracticeSession> sessions) {
  return sessions.fold<int>(0, (total, s) => total + s.durationSeconds);
}

int secondsOnDay(List<PracticeSession> sessions, DateTime day) {
  return sessions
      .where((s) => isSameDay(s.completedAt, day))
      .fold<int>(0, (total, s) => total + s.durationSeconds);
}

/// Seconds practised for Monday..Sunday of the week starting [weekStart].
List<int> weekSeconds(List<PracticeSession> sessions, DateTime weekStart) {
  return List<int>.generate(
    7,
    (i) => secondsOnDay(sessions, addDays(weekStart, i)),
  );
}

Set<DateTime> practiceDaySet(List<PracticeSession> sessions) {
  return sessions.map((s) => dayOnly(s.completedAt)).toSet();
}

/// Current streak. If today has no practice yet, the streak from yesterday
/// stays alive (it only breaks when a full day is missed).
int currentStreakOf(Set<DateTime> days) {
  final today = dayOnly(DateTime.now());
  var cursor = days.contains(today) ? today : addDays(today, -1);
  var streak = 0;

  while (days.contains(cursor)) {
    streak++;
    cursor = addDays(cursor, -1);
  }
  return streak;
}

int bestStreakOf(Set<DateTime> days) {
  if (days.isEmpty) return 0;

  final sorted = days.toList()..sort();
  var best = 1;
  var run = 1;

  for (var i = 1; i < sorted.length; i++) {
    if (sorted[i] == addDays(sorted[i - 1], 1)) {
      run++;
    } else {
      run = 1;
    }
    if (run > best) best = run;
  }
  return best;
}

const List<String> weekdayShort = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

// -------------------- APP --------------------

class NilaDanceApp extends StatelessWidget {
  const NilaDanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Nila's Dance Tracker",
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: bgColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: purpleColor,
          brightness: Brightness.dark,
        ),
      ),
      home: const DanceHomePage(),
    );
  }
}

// -------------------- HOME PAGE --------------------

class DanceHomePage extends StatefulWidget {
  const DanceHomePage({super.key});

  @override
  State<DanceHomePage> createState() => _DanceHomePageState();
}

class _DanceHomePageState extends State<DanceHomePage> {
  Timer? _timer;

  int _seconds = 0;
  bool _isRunning = false;
  bool _hasStarted = false;
  bool _isLoading = true;

  String _selectedStyle = 'Hip-Hop';
  List<String> _customStyles = [];

  // Real clock based, so the time stays correct even if the browser tab
  // is in the background and timers get throttled.
  final Stopwatch _stopwatch = Stopwatch();

  List<String> get _allStyles => [...danceStyles, ..._customStyles];

  // Settings (saved in SharedPreferences)
  String _profileName = 'Nila';
  int _dailyGoalMinutes = 30;
  int _weeklyGoalMinutes = 150;

  List<PracticeSession> _history = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // -------- Load / Save --------

  Future<void> _loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final saved = prefs.getString(historyKey);
      List<PracticeSession> sessions = [];

      if (saved != null) {
        final decoded = jsonDecode(saved) as List<dynamic>;
        sessions = decoded.map((item) {
          return PracticeSession.fromJson(
            Map<String, dynamic>.from(item as Map),
          );
        }).toList();
      }

      final name = prefs.getString(profileNameKey);
      final daily = prefs.getInt(dailyGoalKey);
      final weekly = prefs.getInt(weeklyGoalKey);
      final style = prefs.getString(defaultStyleKey);
      final custom = prefs.getStringList(customStylesKey) ?? <String>[];

      if (!mounted) return;
      setState(() {
        _history = sessions;
        if (name != null && name.trim().isNotEmpty) _profileName = name;
        if (daily != null && dailyGoalOptions.contains(daily)) {
          _dailyGoalMinutes = daily;
        }
        if (weekly != null && weeklyGoalOptions.contains(weekly)) {
          _weeklyGoalMinutes = weekly;
        }
        _customStyles = List<String>.of(custom);
        if (style != null && _allStyles.contains(style)) {
          _selectedStyle = style;
        }
      });
    } catch (e) {
      debugPrint('Could not load saved data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();

    final encoded = jsonEncode(
      _history.map((session) => session.toJson()).toList(),
    );

    final saved = await prefs.setString(historyKey, encoded);

    if (!saved) {
      throw Exception('Could not save practice history.');
    }
  }

  Future<void> _setDailyGoal(int minutes) async {
    setState(() => _dailyGoalMinutes = minutes);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(dailyGoalKey, minutes);
    } catch (e) {
      debugPrint('Could not save daily goal: $e');
    }
  }

  Future<void> _setWeeklyGoal(int minutes) async {
    setState(() => _weeklyGoalMinutes = minutes);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(weeklyGoalKey, minutes);
    } catch (e) {
      debugPrint('Could not save weekly goal: $e');
    }
  }

  Future<void> _setProfileName(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;

    setState(() => _profileName = clean);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(profileNameKey, clean);
    } catch (e) {
      debugPrint('Could not save name: $e');
    }
  }

  Future<void> _setDefaultStyle(String style) async {
    setState(() {
      if (!_hasStarted) _selectedStyle = style;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(defaultStyleKey, style);
    } catch (e) {
      debugPrint('Could not save default style: $e');
    }
  }

  Future<void> _resetHistory() async {
    setState(() => _history = []);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(historyKey);
    } catch (e) {
      debugPrint('Could not reset history: $e');
    }
  }

  Future<void> _saveCustomStyles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(customStylesKey, _customStyles);
    } catch (e) {
      debugPrint('Could not save custom styles: $e');
    }
  }

  /// Returns an error message, or null when the style was added.
  String? _addCustomStyle(String rawName) {
    final name = rawName.trim();
    if (name.isEmpty) return 'Please type a style name.';

    final exists = _allStyles.any(
      (s) => s.toLowerCase() == name.toLowerCase(),
    );
    if (exists) return '"$name" is already in your list.';

    setState(() {
      _customStyles = [..._customStyles, name];
      if (!_hasStarted) _selectedStyle = name;
    });
    _saveCustomStyles();
    return null;
  }

  /// Returns an error message, or null when the style was removed.
  String? _removeCustomStyle(String name) {
    if (_hasStarted && _selectedStyle == name) {
      return 'Finish your current practice before removing "$name".';
    }

    setState(() {
      _customStyles = _customStyles.where((s) => s != name).toList();
      if (_selectedStyle == name) _selectedStyle = danceStyles.first;
    });
    _saveCustomStyles();
    return null;
  }

  Future<void> _showAddStyleDialog() async {
    final controller = TextEditingController();
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void submit() {
              final error = _addCustomStyle(controller.text);
              if (error != null) {
                setDialogState(() => errorText = error);
              } else {
                Navigator.pop(dialogContext);
              }
            }

            return AlertDialog(
              backgroundColor: cardColor,
              title: const Text('Add a dance style'),
              content: TextField(
                controller: controller,
                autofocus: true,
                maxLength: 24,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'e.g. Kuchipudi, Salsa, Garba',
                  errorText: errorText,
                ),
                onSubmitted: (_) => submit(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: submit,
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteSession(PracticeSession session) async {
    setState(() => _history.remove(session));
    try {
      await _saveHistory();
    } catch (e) {
      debugPrint('Could not save after deleting a session: $e');
    }
  }

  // -------- Derived values --------

  int get _totalPracticeSeconds => totalSecondsOf(_history);

  String _formatSessionTime(int seconds) => formatTime(seconds);

  // -------- Timer --------

  void _startTimer() {
    if (_isRunning) return;

    _stopwatch.start();

    setState(() {
      _isRunning = true;
      _hasStarted = true;
    });

    _timer = Timer.periodic(
      const Duration(milliseconds: 500),
      (timer) {
        if (!mounted || !_isRunning) return;

        final elapsed = _stopwatch.elapsed.inSeconds;
        if (elapsed != _seconds) {
          setState(() {
            _seconds = elapsed;
          });
        }
      },
    );
  }

  void _pauseTimer() {
    _timer?.cancel();
    _timer = null;
    _stopwatch.stop();

    setState(() {
      _isRunning = false;
      _seconds = _stopwatch.elapsed.inSeconds;
    });
  }

  Future<void> _finishPractice() async {
    _timer?.cancel();
    _timer = null;

    final completedSeconds = _stopwatch.elapsed.inSeconds;
    _stopwatch
      ..stop()
      ..reset();
    final completedStyle = _selectedStyle;

    setState(() {
      _isRunning = false;
      _hasStarted = false;
      _seconds = 0;
    });

    if (completedSeconds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Practice duration was zero. Try again!'),
        ),
      );
      return;
    }

    final session = PracticeSession(
      style: completedStyle,
      durationSeconds: completedSeconds,
      completedAt: DateTime.now(),
    );

    setState(() {
      _history.insert(0, session);
    });

    try {
      await _saveHistory();

      if (!mounted) return;

      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: cardColor,
          title: Text('Amazing work, $_profileName! 💜'),
          content: Text(
            'Dance style: $completedStyle\n'
            'Practice duration: ${_formatSessionTime(completedSeconds)}\n\n'
            'Your session has been saved to Practice History!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Awesome!'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Session finished, but saving failed: $e'),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  // -------- Navigation --------

  List<PracticeSession> get _snapshot =>
      List<PracticeSession>.unmodifiable(_history);

  void _open(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  void _openHistory() {
    _open(
      PracticeHistoryPage(
        sessions: _snapshot,
        onDelete: _deleteSession,
      ),
    );
  }

  void _openWeekly() {
    _open(
      WeeklyProgressPage(
        sessions: _snapshot,
        dailyGoalMinutes: _dailyGoalMinutes,
        weeklyGoalMinutes: _weeklyGoalMinutes,
      ),
    );
  }

  void _openStreak() => _open(StreakCalendarPage(sessions: _snapshot));

  void _openGoals() {
    _open(
      GoalsPage(
        sessions: _snapshot,
        dailyGoalMinutes: _dailyGoalMinutes,
        weeklyGoalMinutes: _weeklyGoalMinutes,
        onDailyGoalChanged: _setDailyGoal,
        onWeeklyGoalChanged: _setWeeklyGoal,
      ),
    );
  }

  void _openProfile() {
    _open(
      ProfilePage(
        sessions: _snapshot,
        name: _profileName,
        defaultStyle: _selectedStyle,
        customStyles: _customStyles,
        onCustomStyleRemoved: _removeCustomStyle,
        dailyGoalMinutes: _dailyGoalMinutes,
        weeklyGoalMinutes: _weeklyGoalMinutes,
        onNameChanged: _setProfileName,
        onDefaultStyleChanged: _setDefaultStyle,
        onDailyGoalChanged: _setDailyGoal,
        onWeeklyGoalChanged: _setWeeklyGoal,
        onResetHistory: _resetHistory,
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final streak = currentStreakOf(practiceDaySet(_history));
    final weekTotal = weekSeconds(_history, startOfWeek(DateTime.now()))
        .fold<int>(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: bgColor,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.music_note, color: purpleColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                "$_profileName's Dance Tracker",
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Profile & settings',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: _openProfile,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'YOUR DANCE JOURNEY',
                  style: TextStyle(
                    color: purpleColor,
                    fontSize: 12,
                    letterSpacing: 3,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Hey $_profileName! 💜',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Every step takes you closer to your dreams.',
                  style: TextStyle(color: mutedColor, fontSize: 15),
                ),
                const SizedBox(height: 28),

                // Dance style selection.
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: purpleColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.music_note, color: purpleColor),
                          SizedBox(width: 10),
                          Text(
                            'Choose your dance style',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        key: ValueKey(_selectedStyle),
                        initialValue: _selectedStyle,
                        isExpanded: true,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: bgColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        dropdownColor: cardColor,
                        items: _allStyles.map((style) {
                          return DropdownMenuItem<String>(
                            value: style,
                            child: Text(style),
                          );
                        }).toList(),
                        onChanged: _hasStarted
                            ? null
                            : (style) {
                                if (style == null) return;
                                setState(() => _selectedStyle = style);
                              },
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _hasStarted
                                  ? 'Style locked for this session'
                                  : 'Selected: $_selectedStyle',
                              style: const TextStyle(
                                color: mutedColor,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _showAddStyleDialog,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add style'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Practice timer.
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF57309B),
                        Color(0xFF291C43),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.graphic_eq,
                        size: 34,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'YOUR PRACTICE SESSION',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _formatSessionTime(_seconds),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isRunning
                            ? '$_selectedStyle session in progress 🔥'
                            : _hasStarted
                                ? 'Timer paused. Keep going!'
                                : 'Ready for $_selectedStyle?',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: _isRunning ? null : _startTimer,
                            icon: Icon(
                              _hasStarted
                                  ? Icons.play_arrow
                                  : Icons.play_circle_fill,
                            ),
                            label: Text(
                              _hasStarted ? 'Resume' : 'Start Practice',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF57309B),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _isRunning ? _pauseTimer : null,
                            icon: const Icon(Icons.pause),
                            label: const Text('Pause'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _hasStarted ? _finishPractice : null,
                            icon: const Icon(Icons.stop),
                            label: const Text('Finish'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                const Text(
                  'YOUR JOURNEY',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        icon: Icons.timer_outlined,
                        title: 'Current session',
                        value: _seconds >= 60
                            ? '${_seconds ~/ 60} min'
                            : '$_seconds sec',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        icon: Icons.check_circle_outline,
                        title: 'Completed sessions',
                        value: '${_history.length}',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        icon: Icons.hourglass_bottom,
                        title: 'Total practice time',
                        value: _totalPracticeSeconds >= 3600
                            ? '${(_totalPracticeSeconds / 3600).toStringAsFixed(1)} hrs'
                            : '${_totalPracticeSeconds ~/ 60} min',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        icon: Icons.local_fire_department,
                        title: 'Current streak',
                        value: streak == 1 ? '1 day' : '$streak days',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                StatCard(
                  icon: Icons.bar_chart,
                  title: 'This week (target $_weeklyGoalMinutes min)',
                  value: humanDuration(weekTotal),
                ),

                const SizedBox(height: 28),

                const Text(
                  'EXPLORE',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),

                FeatureTile(
                  icon: Icons.insert_chart_outlined,
                  title: 'Weekly progress',
                  subtitle: 'Monday–Sunday chart and weekly total',
                  onTap: _openWeekly,
                ),
                FeatureTile(
                  icon: Icons.local_fire_department,
                  title: 'Dance streak & calendar',
                  subtitle: streak > 0
                      ? '$streak day streak — keep it going!'
                      : 'Practice today to start a streak',
                  onTap: _openStreak,
                ),
                FeatureTile(
                  icon: Icons.calendar_month,
                  title: 'Practice history',
                  subtitle: _isLoading
                      ? 'Loading your sessions...'
                      : _history.isEmpty
                          ? 'Tap to view your history'
                          : '${_history.length} completed session(s)',
                  onTap: _openHistory,
                ),
                FeatureTile(
                  icon: Icons.emoji_events,
                  title: 'Goals & achievements',
                  subtitle: 'Set goals and celebrate your progress',
                  onTap: _openGoals,
                ),
                FeatureTile(
                  icon: Icons.person_outline,
                  title: 'Profile & settings',
                  subtitle: 'Your profile, statistics and preferences',
                  onTap: _openProfile,
                ),

                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'Made with 💜 for your dance journey',
                    style: TextStyle(
                      color: mutedColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== 1. WEEKLY PROGRESS DASHBOARD ====================

class WeeklyProgressPage extends StatefulWidget {
  final List<PracticeSession> sessions;
  final int dailyGoalMinutes;
  final int weeklyGoalMinutes;

  const WeeklyProgressPage({
    super.key,
    required this.sessions,
    required this.dailyGoalMinutes,
    required this.weeklyGoalMinutes,
  });

  @override
  State<WeeklyProgressPage> createState() => _WeeklyProgressPageState();
}

class _WeeklyProgressPageState extends State<WeeklyProgressPage> {
  int _weekOffset = 0; // 0 = this week, -1 = last week ...

  @override
  Widget build(BuildContext context) {
    final today = dayOnly(DateTime.now());
    final weekStart = addDays(startOfWeek(today), _weekOffset * 7);
    final weekEnd = addDays(weekStart, 6);

    final values = weekSeconds(widget.sessions, weekStart);
    final weekTotal = values.fold<int>(0, (a, b) => a + b);
    final weeklyTarget = widget.weeklyGoalMinutes * 60;
    final progress = (weekTotal / weeklyTarget).clamp(0.0, 1.0).toDouble();

    final activeDays = values.where((v) => v > 0).length;
    var bestIndex = 0;
    for (var i = 1; i < 7; i++) {
      if (values[i] > values[bestIndex]) bestIndex = i;
    }
    final average = weekTotal ~/ 7;

    final todayIndex = (_weekOffset == 0) ? today.weekday - 1 : -1;
    final isThisWeek = _weekOffset == 0;

    final rangeLabel =
        '${weekStart.day}/${weekStart.month} – ${weekEnd.day}/${weekEnd.month}';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: bgColor,
        title: const Text(
          'Weekly Progress',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Week selector.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => setState(() => _weekOffset--),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Column(
                      children: [
                        Text(
                          isThisWeek ? 'This week' : 'Week of',
                          style: const TextStyle(
                            color: mutedColor,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rangeLabel,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed:
                          isThisWeek ? null : () => setState(() => _weekOffset++),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Weekly total card.
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF57309B), Color(0xFF291C43)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'WEEKLY TOTAL',
                        style: TextStyle(
                          color: Colors.white70,
                          letterSpacing: 2,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        humanDuration(weekTotal),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Target: ${widget.weeklyGoalMinutes} minutes',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 12,
                          backgroundColor: Colors.white24,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        weekTotal >= weeklyTarget
                            ? 'Weekly target completed! 🏆'
                            : '${(100 * progress).round()}% of weekly target',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // Chart.
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: purpleColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DAILY PRACTICE (MON–SUN)',
                        style: TextStyle(
                          color: purpleColor,
                          fontSize: 12,
                          letterSpacing: 2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      WeeklyBarChart(
                        seconds: values,
                        goalSeconds: widget.dailyGoalMinutes * 60,
                        todayIndex: todayIndex,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Line = daily goal (${widget.dailyGoalMinutes} min)',
                        style: const TextStyle(
                          color: mutedColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        icon: Icons.show_chart,
                        title: 'Daily average',
                        value: humanDuration(average),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        icon: Icons.event_available,
                        title: 'Active days',
                        value: '$activeDays / 7',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StatCard(
                  icon: Icons.star_outline,
                  title: 'Best day this week',
                  value: values[bestIndex] == 0
                      ? 'No practice yet'
                      : '${weekdayShort[bestIndex]} • '
                          '${humanDuration(values[bestIndex])}',
                ),

                const SizedBox(height: 24),

                const Text(
                  'DAY BY DAY',
                  style: TextStyle(
                    color: purpleColor,
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                ...List.generate(7, (i) {
                  final day = addDays(weekStart, i);
                  final secs = values[i];
                  final reached = secs >= widget.dailyGoalMinutes * 60;
                  final isToday = i == todayIndex;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isToday
                            ? purpleColor.withValues(alpha: 0.7)
                            : Colors.white10,
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 46,
                          child: Text(
                            weekdayShort[i],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isToday ? purpleColor : Colors.white,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${day.day}/${day.month}',
                            style: const TextStyle(
                              color: mutedColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          secs == 0 ? '—' : humanDuration(secs),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          reached
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: reached ? purpleColor : Colors.white24,
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WeeklyBarChart extends StatelessWidget {
  final List<int> seconds; // 7 values, Monday first
  final int goalSeconds;
  final int todayIndex; // -1 when not the current week

  const WeeklyBarChart({
    super.key,
    required this.seconds,
    required this.goalSeconds,
    required this.todayIndex,
  });

  @override
  Widget build(BuildContext context) {
    var maxSeconds = goalSeconds;
    for (final s in seconds) {
      if (s > maxSeconds) maxSeconds = s;
    }
    if (maxSeconds < 60) maxSeconds = 60;

    const barArea = 120.0;
    final goalHeight = goalSeconds / maxSeconds * barArea;

    return Column(
      children: [
        SizedBox(
          height: 150,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: goalHeight,
                child: Container(height: 1, color: Colors.white30),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final value = seconds[i];
                  var height = value / maxSeconds * barArea;
                  if (value > 0 && height < 6) height = 6;
                  if (value == 0) height = 3;

                  final isToday = i == todayIndex;
                  final reached = value >= goalSeconds && value > 0;

                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          value == 0 ? '' : shortMinutes(value),
                          style: const TextStyle(
                            fontSize: 11,
                            color: mutedColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: height,
                          margin: const EdgeInsets.symmetric(horizontal: 7),
                          decoration: BoxDecoration(
                            color: value == 0
                                ? Colors.white12
                                : reached
                                    ? purpleColor
                                    : purpleColor.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(8),
                            border: isToday
                                ? Border.all(color: Colors.white, width: 1.5)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(7, (i) {
            return Expanded(
              child: Center(
                child: Text(
                  weekdayShort[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        i == todayIndex ? FontWeight.bold : FontWeight.normal,
                    color: i == todayIndex ? Colors.white : mutedColor,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ==================== 2. DANCE STREAK & CALENDAR ====================

class StreakCalendarPage extends StatefulWidget {
  final List<PracticeSession> sessions;

  const StreakCalendarPage({super.key, required this.sessions});

  @override
  State<StreakCalendarPage> createState() => _StreakCalendarPageState();
}

class _StreakCalendarPageState extends State<StreakCalendarPage> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final days = practiceDaySet(widget.sessions);
    final streak = currentStreakOf(days);
    final best = bestStreakOf(days);
    final today = dayOnly(DateTime.now());

    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leadingBlanks = DateTime(_month.year, _month.month, 1).weekday - 1;

    final monthPracticeDays = days
        .where((d) => d.year == _month.year && d.month == _month.month)
        .length;

    final cells = <Widget>[];

    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(_month.year, _month.month, d);
      final practiced = days.contains(date);
      final isToday = date == today;
      final isFuture = date.isAfter(today);

      cells.add(
        Center(
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: practiced ? purpleColor : Colors.transparent,
              border: isToday
                  ? Border.all(color: Colors.white, width: 1.5)
                  : null,
            ),
            child: Text(
              '$d',
              style: TextStyle(
                fontWeight: practiced ? FontWeight.bold : FontWeight.normal,
                color: practiced
                    ? Colors.white
                    : isFuture
                        ? Colors.white24
                        : mutedColor,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: bgColor,
        title: const Text(
          'Dance Streak',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Streak hero card.
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF57309B), Color(0xFF291C43)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        size: 54,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CURRENT STREAK',
                              style: TextStyle(
                                color: Colors.white70,
                                letterSpacing: 2,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              streak == 1 ? '1 day' : '$streak days',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              streak == 0
                                  ? 'Practice today to start your streak!'
                                  : days.contains(today)
                                      ? 'You danced today. Amazing! 💜'
                                      : 'Practice today to keep it alive!',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        icon: Icons.emoji_events_outlined,
                        title: 'Best streak',
                        value: best == 1 ? '1 day' : '$best days',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        icon: Icons.event_available,
                        title: 'Total practice days',
                        value: '${days.length}',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                // Calendar.
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: purpleColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () => _changeMonth(-1),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text(
                            '${monthNames[_month.month - 1]} ${_month.year}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed:
                                _isCurrentMonth ? null : () => _changeMonth(1),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: weekdayShort.map((label) {
                          return Expanded(
                            child: Center(
                              child: Text(
                                label.substring(0, 1),
                                style: const TextStyle(
                                  color: mutedColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      GridView.count(
                        crossAxisCount: 7,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 6,
                        children: cells,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$monthPracticeDays practice day(s) in '
                        '${monthNames[_month.month - 1]}',
                        style: const TextStyle(
                          color: mutedColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const Text(
                  'Purple circle = you practised that day. '
                  'White ring = today.',
                  style: TextStyle(color: mutedColor, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== PRACTICE HISTORY PAGE ====================

class PracticeHistoryPage extends StatefulWidget {
  final List<PracticeSession> sessions;
  final Future<void> Function(PracticeSession session) onDelete;

  const PracticeHistoryPage({
    super.key,
    required this.sessions,
    required this.onDelete,
  });

  @override
  State<PracticeHistoryPage> createState() => _PracticeHistoryPageState();
}

class _PracticeHistoryPageState extends State<PracticeHistoryPage> {
  late List<PracticeSession> sessions;

  @override
  void initState() {
    super.initState();
    sessions = List<PracticeSession>.of(widget.sessions);
  }

  Future<void> _confirmDelete(PracticeSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text('Delete this session?'),
        content: Text(
          '${session.style} • ${formatDate(session.completedAt)} • '
          '${formatTime(session.durationSeconds)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => sessions.remove(session));
    await widget.onDelete(session);
  }

  @override
  Widget build(BuildContext context) {
    final totalSeconds = totalSecondsOf(sessions);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: bgColor,
        title: const Text(
          'Practice History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: sessions.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.music_note,
                            color: purpleColor,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Your dance journey starts here!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Complete a practice session and press Finish. '
                            'Your saved sessions will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: mutedColor),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Back to practice'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF57309B),
                              Color(0xFF291C43),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'YOUR PROGRESS 💜',
                              style: TextStyle(
                                color: Colors.white70,
                                letterSpacing: 2,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              '${sessions.length} sessions completed',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Total practice: ${formatTime(totalSeconds)}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                      const Text(
                        'PAST SESSIONS',
                        style: TextStyle(
                          color: purpleColor,
                          fontSize: 12,
                          letterSpacing: 2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...sessions.map((session) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: purpleColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(13),
                                decoration: BoxDecoration(
                                  color: purpleColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.music_note,
                                  color: purpleColor,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      session.style,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${formatDate(session.completedAt)} • '
                                      '${formatClock(session.completedAt)}',
                                      style: const TextStyle(
                                        color: mutedColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Icon(
                                    Icons.timer_outlined,
                                    color: purpleColor,
                                    size: 20,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    formatTime(session.durationSeconds),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                tooltip: 'Delete session',
                                onPressed: () => _confirmDelete(session),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: mutedColor,
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ==================== GOALS & ACHIEVEMENTS PAGE ====================

class GoalsPage extends StatefulWidget {
  final List<PracticeSession> sessions;
  final int dailyGoalMinutes;
  final int weeklyGoalMinutes;
  final Future<void> Function(int minutes) onDailyGoalChanged;
  final Future<void> Function(int minutes) onWeeklyGoalChanged;

  const GoalsPage({
    super.key,
    required this.sessions,
    required this.dailyGoalMinutes,
    required this.weeklyGoalMinutes,
    required this.onDailyGoalChanged,
    required this.onWeeklyGoalChanged,
  });

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  late int _dailyGoalMinutes;
  late int _weeklyGoalMinutes;

  @override
  void initState() {
    super.initState();
    _dailyGoalMinutes = widget.dailyGoalMinutes;
    _weeklyGoalMinutes = widget.weeklyGoalMinutes;
  }

  void _changeDaily(int minutes) {
    setState(() => _dailyGoalMinutes = minutes);
    widget.onDailyGoalChanged(minutes);
  }

  void _changeWeekly(int minutes) {
    setState(() => _weeklyGoalMinutes = minutes);
    widget.onWeeklyGoalChanged(minutes);
  }

  int get _todaySeconds =>
      secondsOnDay(widget.sessions, dayOnly(DateTime.now()));

  int get _weekSecondsTotal {
    return weekSeconds(widget.sessions, startOfWeek(DateTime.now()))
        .fold<int>(0, (a, b) => a + b);
  }

  int get _totalSeconds => totalSecondsOf(widget.sessions);

  bool get _dailyGoalComplete => _todaySeconds >= _dailyGoalMinutes * 60;

  bool get _weeklyGoalComplete =>
      _weekSecondsTotal >= _weeklyGoalMinutes * 60;

  @override
  Widget build(BuildContext context) {
    final targetSeconds = _dailyGoalMinutes * 60;
    final progress = (_todaySeconds / targetSeconds).clamp(0.0, 1.0).toDouble();

    final weeklyTarget = _weeklyGoalMinutes * 60;
    final weeklyProgress =
        (_weekSecondsTotal / weeklyTarget).clamp(0.0, 1.0).toDouble();

    final days = practiceDaySet(widget.sessions);
    final streak = currentStreakOf(days);
    final best = bestStreakOf(days);

    final achievements = [
      DanceAchievement(
        title: 'First Step',
        subtitle: 'Complete your first practice',
        icon: Icons.play_circle_fill,
        unlocked: widget.sessions.isNotEmpty,
      ),
      DanceAchievement(
        title: '5 Sessions',
        subtitle: 'Finish 5 practice sessions',
        icon: Icons.stars,
        unlocked: widget.sessions.length >= 5,
      ),
      DanceAchievement(
        title: '1 Hour Dancer',
        subtitle: 'Practice for 60 minutes in total',
        icon: Icons.timer,
        unlocked: _totalSeconds >= 3600,
      ),
      DanceAchievement(
        title: 'Daily Champion',
        subtitle: 'Reach your daily practice goal',
        icon: Icons.emoji_events,
        unlocked: _dailyGoalComplete,
      ),
      DanceAchievement(
        title: 'Weekly Warrior',
        subtitle: 'Reach your weekly practice target',
        icon: Icons.military_tech,
        unlocked: _weeklyGoalComplete,
      ),
      DanceAchievement(
        title: '3-Day Streak',
        subtitle: 'Practice 3 days in a row',
        icon: Icons.local_fire_department,
        unlocked: best >= 3,
      ),
      DanceAchievement(
        title: '7-Day Streak',
        subtitle: 'Practice 7 days in a row',
        icon: Icons.whatshot,
        unlocked: best >= 7,
      ),
    ];

    final unlockedCount = achievements.where((a) => a.unlocked).length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: bgColor,
        title: const Text(
          'Goals & Achievements',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Daily goal progress card.
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF57309B), Color(0xFF291C43)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.flag_circle,
                        size: 38,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'YOUR DAILY GOAL',
                        style: TextStyle(
                          color: Colors.white70,
                          letterSpacing: 2,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_todaySeconds ~/ 60} / $_dailyGoalMinutes minutes',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 12,
                          backgroundColor: Colors.white24,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _dailyGoalComplete
                            ? 'Goal completed! Amazing work! 💜'
                            : '${(100 * progress).round()}% complete — '
                                'keep dancing!',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Weekly target card.
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: purpleColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'WEEKLY TARGET',
                        style: TextStyle(
                          color: purpleColor,
                          fontSize: 12,
                          letterSpacing: 2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_weekSecondsTotal ~/ 60} / '
                        '$_weeklyGoalMinutes minutes this week',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: weeklyProgress,
                          minHeight: 10,
                          backgroundColor: Colors.white12,
                          color: purpleColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _weeklyGoalComplete
                            ? 'Weekly target reached! 🏆'
                            : '${(100 * weeklyProgress).round()}% complete',
                        style: const TextStyle(
                          color: mutedColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        icon: Icons.local_fire_department,
                        title: 'Current streak',
                        value: streak == 1 ? '1 day' : '$streak days',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        icon: Icons.emoji_events_outlined,
                        title: 'Best streak',
                        value: best == 1 ? '1 day' : '$best days',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                const Text(
                  'SET YOUR DAILY TARGET',
                  style: TextStyle(
                    color: purpleColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose how many minutes you want to dance each day.',
                  style: TextStyle(color: mutedColor, fontSize: 13),
                ),
                const SizedBox(height: 14),
                GoalChips(
                  options: dailyGoalOptions,
                  selected: _dailyGoalMinutes,
                  onSelected: _changeDaily,
                ),

                const SizedBox(height: 26),

                const Text(
                  'SET YOUR WEEKLY TARGET',
                  style: TextStyle(
                    color: purpleColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose how many minutes you want to dance each week.',
                  style: TextStyle(color: mutedColor, fontSize: 13),
                ),
                const SizedBox(height: 14),
                GoalChips(
                  options: weeklyGoalOptions,
                  selected: _weeklyGoalMinutes,
                  onSelected: _changeWeekly,
                ),

                const SizedBox(height: 28),

                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'ACHIEVEMENTS',
                        style: TextStyle(
                          color: purpleColor,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    Text(
                      '$unlockedCount/${achievements.length} unlocked',
                      style: const TextStyle(
                        color: mutedColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                ...achievements.map((achievement) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: achievement.unlocked
                            ? purpleColor.withValues(alpha: 0.7)
                            : Colors.white12,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: achievement.unlocked
                              ? purpleColor.withValues(alpha: 0.2)
                              : Colors.white10,
                          child: Icon(
                            achievement.unlocked
                                ? achievement.icon
                                : Icons.lock_outline,
                            color: achievement.unlocked
                                ? purpleColor
                                : mutedColor,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                achievement.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                achievement.subtitle,
                                style: const TextStyle(
                                  color: mutedColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (achievement.unlocked)
                          const Icon(
                            Icons.check_circle,
                            color: purpleColor,
                          ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 12),

                const Text(
                  'Tip: Finish your practice sessions to update your '
                  'progress and unlock achievements. Every minute counts!',
                  style: TextStyle(color: mutedColor, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== 3. PROFILE & SETTINGS ====================

class ProfilePage extends StatefulWidget {
  final List<PracticeSession> sessions;
  final String name;
  final String defaultStyle;
  final List<String> customStyles;
  final String? Function(String name) onCustomStyleRemoved;
  final int dailyGoalMinutes;
  final int weeklyGoalMinutes;
  final Future<void> Function(String name) onNameChanged;
  final Future<void> Function(String style) onDefaultStyleChanged;
  final Future<void> Function(int minutes) onDailyGoalChanged;
  final Future<void> Function(int minutes) onWeeklyGoalChanged;
  final Future<void> Function() onResetHistory;

  const ProfilePage({
    super.key,
    required this.sessions,
    required this.name,
    required this.defaultStyle,
    required this.customStyles,
    required this.onCustomStyleRemoved,
    required this.dailyGoalMinutes,
    required this.weeklyGoalMinutes,
    required this.onNameChanged,
    required this.onDefaultStyleChanged,
    required this.onDailyGoalChanged,
    required this.onWeeklyGoalChanged,
    required this.onResetHistory,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late List<PracticeSession> _sessions;
  late String _name;
  late String _defaultStyle;
  late List<String> _customStyles;
  late int _dailyGoalMinutes;
  late int _weeklyGoalMinutes;

  @override
  void initState() {
    super.initState();
    _sessions = List<PracticeSession>.of(widget.sessions);
    _name = widget.name;
    _defaultStyle = widget.defaultStyle;
    _customStyles = List<String>.of(widget.customStyles);
    _dailyGoalMinutes = widget.dailyGoalMinutes;
    _weeklyGoalMinutes = widget.weeklyGoalMinutes;
  }

  List<String> get _styles => [...danceStyles, ..._customStyles];

  void _removeStyle(String name) {
    final error = widget.onCustomStyleRemoved(name);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    setState(() {
      _customStyles = _customStyles.where((s) => s != name).toList();
      if (_defaultStyle == name) {
        _defaultStyle = danceStyles.first;
        widget.onDefaultStyleChanged(_defaultStyle);
      }
    });
  }

  String get _favouriteStyle {
    if (_sessions.isEmpty) return '—';

    final counts = <String, int>{};
    for (final s in _sessions) {
      counts[s.style] = (counts[s.style] ?? 0) + 1;
    }

    var bestStyle = counts.keys.first;
    counts.forEach((style, count) {
      if (count > counts[bestStyle]!) bestStyle = style;
    });
    return bestStyle;
  }

  int get _longestSessionSeconds {
    var longest = 0;
    for (final s in _sessions) {
      if (s.durationSeconds > longest) longest = s.durationSeconds;
    }
    return longest;
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _name);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Enter your name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null || result.trim().isEmpty) return;

    setState(() => _name = result.trim());
    await widget.onNameChanged(result);
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text('Reset practice history?'),
        content: const Text(
          'This will delete all your saved practice sessions, streaks and '
          'achievements progress. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await widget.onResetHistory();

    if (!mounted) return;
    setState(() => _sessions = []);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Practice history has been reset.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = practiceDaySet(_sessions);
    final best = bestStreakOf(days);
    final streak = currentStreakOf(days);
    final totalSeconds = totalSecondsOf(_sessions);
    final initial = _name.isEmpty ? '?' : _name.substring(0, 1).toUpperCase();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: bgColor,
        title: const Text(
          'Profile & Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Profile card.
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF57309B), Color(0xFF291C43)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: Colors.white24,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Favourite style: $_favouriteStyle',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit name',
                        onPressed: _editName,
                        icon: const Icon(Icons.edit, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 26),

                const Text(
                  'PRACTICE STATISTICS',
                  style: TextStyle(
                    color: purpleColor,
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        icon: Icons.check_circle_outline,
                        title: 'Total sessions',
                        value: '${_sessions.length}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        icon: Icons.hourglass_bottom,
                        title: 'Total practice time',
                        value: humanDuration(totalSeconds),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        icon: Icons.local_fire_department,
                        title: 'Current streak',
                        value: streak == 1 ? '1 day' : '$streak days',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        icon: Icons.emoji_events_outlined,
                        title: 'Best streak',
                        value: best == 1 ? '1 day' : '$best days',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        icon: Icons.event_available,
                        title: 'Practice days',
                        value: '${days.length}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        icon: Icons.timer_outlined,
                        title: 'Longest session',
                        value: _sessions.isEmpty
                            ? '—'
                            : humanDuration(_longestSessionSeconds),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                const Text(
                  'PREFERENCES',
                  style: TextStyle(
                    color: purpleColor,
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: purpleColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Default dance style',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _defaultStyle,
                        isExpanded: true,
                        dropdownColor: cardColor,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: bgColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        items: _styles.map((style) {
                          return DropdownMenuItem<String>(
                            value: style,
                            child: Text(style),
                          );
                        }).toList(),
                        onChanged: (style) {
                          if (style == null) return;
                          setState(() => _defaultStyle = style);
                          widget.onDefaultStyleChanged(style);
                        },
                      ),
                      if (_customStyles.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        const Text(
                          'My custom styles',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _customStyles.map((name) {
                            return InputChip(
                              label: Text(name),
                              onDeleted: () => _removeStyle(name),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 22),
                      const Text(
                        'Daily goal',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      GoalChips(
                        options: dailyGoalOptions,
                        selected: _dailyGoalMinutes,
                        onSelected: (m) {
                          setState(() => _dailyGoalMinutes = m);
                          widget.onDailyGoalChanged(m);
                        },
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Weekly target',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      GoalChips(
                        options: weeklyGoalOptions,
                        selected: _weeklyGoalMinutes,
                        onSelected: (m) {
                          setState(() => _weeklyGoalMinutes = m);
                          widget.onWeeklyGoalChanged(m);
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                const Text(
                  'DANGER ZONE',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reset practice history',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Deletes all saved sessions, streaks and progress. '
                        'Your name and preferences are kept.',
                        style: TextStyle(color: mutedColor, fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _sessions.isEmpty ? null : _confirmReset,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Reset history'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== SHARED WIDGETS ====================

class GoalChips extends StatelessWidget {
  final List<int> options;
  final int selected;
  final ValueChanged<int> onSelected;

  const GoalChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((minutes) {
        return ChoiceChip(
          label: Text('$minutes min'),
          selected: minutes == selected,
          selectedColor: purpleColor,
          onSelected: (_) => onSelected(minutes),
        );
      }).toList(),
    );
  }
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const StatCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: purpleColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: purpleColor, size: 28),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(
              color: mutedColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const FeatureTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: purpleColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: purpleColor,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: mutedColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: mutedColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}