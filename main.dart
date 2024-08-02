import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

late SharedPreferences prefs;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();
  print('SharedPreferences initialized');
  runApp(AlarmApp());
}

class AlarmApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alarms',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: ColorScheme.dark(
          primary: Colors.grey[400]!,
          secondary: Colors.red,
          surface: Colors.grey[900]!,
          background: Colors.transparent,
          onPrimary: Colors.black,
          onSecondary: Colors.black,
          onSurface: Colors.white,
          onBackground: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.white;
            }
            return Colors.grey[400];
          }),
          trackColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.red;
            }
            return Colors.grey[800];
          }),
          trackOutlineColor: MaterialStateProperty.all(Colors.transparent),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.red[300];
            }
            return Colors.grey[800];
          }),
          checkColor: MaterialStateProperty.all(Colors.black),
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(letterSpacing: -0.5),
          bodyMedium: TextStyle(letterSpacing: -0.5),
          titleLarge: TextStyle(letterSpacing: -0.5),
        ),
        timePickerTheme: TimePickerThemeData(
          backgroundColor: Colors.black,
          hourMinuteColor: MaterialStateColor.resolveWith((states) =>
              states.contains(MaterialState.selected)
                  ? Colors.grey[800]!
                  : Colors.grey[900]!),
          hourMinuteTextColor: MaterialStateColor.resolveWith((states) =>
              states.contains(MaterialState.selected)
                  ? Colors.white
                  : Colors.grey[400]!),
          dialHandColor: Colors.red,
          dialBackgroundColor: Colors.grey[800],
          dialTextColor: MaterialStateColor.resolveWith((states) =>
              states.contains(MaterialState.selected)
                  ? Colors.white
                  : Colors.grey[400]!),
          entryModeIconColor: Colors.grey,
        ),
      ),
      home: AlarmScreen(),
    );
  }
}

class AlarmScreen extends StatefulWidget {
  @override
  _AlarmScreenState createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  List<AlarmData> alarms = [];
  int _expandedIndex = -1;
  Timer? _debounceTimer;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _loadAlarms();
    _startUpdateTimer();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _updateTimer?.cancel();
    super.dispose();
  }

  void _startUpdateTimer() {
    _updateTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      setState(() {
        _updateAlarmStates();
      });
    });
  }

  void _updateAlarmStates() {
    final now = DateTime.now();
    for (int i = 0; i < alarms.length; i++) {
      if (alarms[i].isActive) {
        if (alarms[i].selectedDays.isEmpty) {
          // For one-time alarms
          DateTime alarmDateTime =
              _combineDateTimeWithTimeOfDay(now, alarms[i].time);
          if (alarmDateTime.isBefore(now)) {
            // Turn off one-time alarms that have passed
            _updateAlarm(i, isActive: false);
          }
        } else if (alarms[i].nextDismissedAlarm != null &&
            alarms[i].nextDismissedAlarm!.isBefore(now)) {
          // Clear dismissed state if the dismissed alarm time has passed
          alarms[i].undoDismissal();
        }
      }
    }
  }

  DateTime _combineDateTimeWithTimeOfDay(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _loadAlarms() {
    List<String>? alarmsData = prefs.getStringList('alarms');
    if (alarmsData != null) {
      setState(() {
        alarms = alarmsData.map((json) => AlarmData.fromJson(json)).toList();
      });
      print('Loaded alarms: $alarmsData');
    } else {
      print('No alarms found in SharedPreferences');
    }
  }

  void _saveAlarms() async {
    List<String> alarmsData = alarms.map((alarm) => alarm.toJson()).toList();
    await prefs.setStringList('alarms', alarmsData);
    print('Saved alarms: $alarmsData');
  }

  String _getTimeDifference(DateTime alarmTime) {
    final now = DateTime.now();
    Duration difference = alarmTime.difference(now);
    int days = difference.inDays;
    int hours = difference.inHours % 24;
    int minutes = difference.inMinutes % 60;

    List<String> parts = [];
    if (days > 0) parts.add('$days day${days > 1 ? 's' : ''}');
    if (hours > 0) parts.add('$hours hour${hours > 1 ? 's' : ''}');
    if (minutes > 0) parts.add('$minutes minute${minutes > 1 ? 's' : ''}');

    return parts.join(', ');
  }

  void _showAlarmMessage(String message) {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    _debounceTimer = Timer(Duration(milliseconds: 300), () {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.fixed,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
        ),
      );
    });
  }

  void _addAlarm(TimeOfDay time) {
    setState(() {
      alarms.add(AlarmData(time: time, selectedDays: [0, 1, 2, 3, 4, 5, 6]));
      _expandedIndex = alarms.length - 1;
      _saveAlarms();
    });

    DateTime nextAlarmTime = alarms.last.getNextAlarmTime();
    String timeDifference = _getTimeDifference(nextAlarmTime);
    _showAlarmMessage('Alarm is set for $timeDifference from now.');
  }

  void _updateAlarm(int index,
      {bool? isActive, bool? isDismissed, List<int>? selectedDays}) {
    setState(() {
      if (isActive != null) {
        alarms[index].isActive = isActive;
        if (!isActive) {
          // Reset dismissal info when alarm is turned off
          alarms[index].resetDismissalInfo();
        }
      }
      if (isDismissed != null) {
        if (isDismissed) {
          alarms[index].dismissNextAlarm();
        } else {
          alarms[index].undoDismissal();
        }
      }
      if (selectedDays != null) {
        alarms[index].selectedDays = selectedDays;
      }
      _saveAlarms();
    });

    if (isActive == true ||
        (selectedDays != null && alarms[index].isActive) ||
        isDismissed != null) {
      DateTime nextAlarmTime = alarms[index].getNextAlarmTime();
      Duration timeDifference = nextAlarmTime.difference(DateTime.now());

      String message;
      if (timeDifference.inMinutes < 1) {
        message = 'Alarm is set for less than 1 minute from now.';
      } else {
        String formattedTimeDifference = _getTimeDifference(nextAlarmTime);
        if (isDismissed == true) {
          DateTime nextNextAlarmTime =
              alarms[index].getNextAlarmTime(afterDismissal: true);
          String nextNextTimeDifference = _getTimeDifference(nextNextAlarmTime);
          message =
              'Next alarm dismissed. Alarm is set for $nextNextTimeDifference from now.';
        } else if (isDismissed == false) {
          message =
              'Dismissal revoked. Alarm is set for $formattedTimeDifference from now.';
        } else {
          message = 'Alarm is set for $formattedTimeDifference from now.';
        }
      }
      _showAlarmMessage(message);
    }
  }

  void _deleteAlarm(int index) {
    setState(() {
      alarms.removeAt(index);
      if (_expandedIndex == index) {
        _expandedIndex = -1;
      } else if (_expandedIndex > index) {
        _expandedIndex--;
      }
      _saveAlarms();
    });
  }

  void _handleExpansion(int index) {
    setState(() {
      if (_expandedIndex == index) {
        _expandedIndex = -1;
      } else {
        _expandedIndex = index;
      }
    });
  }

  Future<void> _selectNewAlarmTime(BuildContext context) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: true,
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      _addAlarm(pickedTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Alarms',
            style: TextStyle(
              fontSize: 22,
              letterSpacing: -0.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: Colors.grey[400]),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: ReorderableListView(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        physics: ClampingScrollPhysics(),
        children: [
          for (int index = 0; index < alarms.length; index++)
            AlarmTile(
              key: ValueKey(alarms[index]),
              data: alarms[index],
              onDelete: () => _deleteAlarm(index),
              onExpand: () => _handleExpansion(index),
              isExpanded: _expandedIndex == index,
              onUpdate: (isActive, isDismissed, selectedDays) => _updateAlarm(
                index,
                isActive: isActive,
                isDismissed: isDismissed,
                selectedDays: selectedDays,
              ),
            ),
        ],
        onReorder: (int oldIndex, int newIndex) {
          setState(() {
            if (newIndex > oldIndex) {
              newIndex -= 1;
            }
            final item = alarms.removeAt(oldIndex);
            alarms.insert(newIndex, item);
            _saveAlarms();
          });
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _selectNewAlarmTime(context),
        child: Icon(Icons.add, color: Colors.black),
        backgroundColor: Colors.grey[400],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class AlarmData {
  TimeOfDay _time;
  bool isActive;
  List<int> selectedDays;
  bool isVibrateOn;
  String sound;
  DateTime? nextDismissedAlarm;
  DateTime? _nextOneTimeAlarm;

  AlarmData({
    required TimeOfDay time,
    this.isActive = true,
    List<int>? selectedDays,
    this.isVibrateOn = true,
    this.sound = 'Default Sound',
    this.nextDismissedAlarm,
  })  : _time = time,
        selectedDays = selectedDays ?? [0, 1, 2, 3, 4, 5, 6],
        _nextOneTimeAlarm = null {
    _updateNextOneTimeAlarm();
  }

  // Getter for time
  TimeOfDay get time => _time;

  // Setter for time that resets dismissal state and updates next one-time alarm
  set time(TimeOfDay newTime) {
    if (_time != newTime) {
      _time = newTime;
      resetDismissalInfo();
      _updateNextOneTimeAlarm();
    }
  }

  void _updateNextOneTimeAlarm() {
    if (selectedDays.isEmpty) {
      DateTime now = DateTime.now();
      DateTime alarmDateTime =
          DateTime(now.year, now.month, now.day, _time.hour, _time.minute);
      if (alarmDateTime.isBefore(now)) {
        alarmDateTime = alarmDateTime.add(Duration(days: 1));
      }
      _nextOneTimeAlarm = alarmDateTime;
    } else {
      _nextOneTimeAlarm = null;
    }
  }

  String toJson() {
    return jsonEncode({
      'time': '${_time.hour}:${_time.minute}',
      'isActive': isActive,
      'selectedDays': selectedDays,
      'isVibrateOn': isVibrateOn,
      'sound': sound,
      'nextDismissedAlarm': nextDismissedAlarm?.toIso8601String(),
      'nextOneTimeAlarm': _nextOneTimeAlarm?.toIso8601String(),
    });
  }

  static AlarmData fromJson(String json) {
    try {
      Map<String, dynamic> data = jsonDecode(json);
      List<String> timeParts = data['time'].split(':');

      if (timeParts.length != 2) {
        throw FormatException('Invalid time format');
      }

      int hour = int.tryParse(timeParts[0]) ?? 0;
      int minute = int.tryParse(timeParts[1]) ?? 0;

      hour = hour.clamp(0, 23);
      minute = minute.clamp(0, 59);

      AlarmData alarm = AlarmData(
        time: TimeOfDay(hour: hour, minute: minute),
        isActive: data['isActive'] as bool? ?? true,
        selectedDays: (data['selectedDays'] as List<dynamic>?)
                ?.map((e) => int.tryParse(e.toString()) ?? 0)
                .where((e) => e >= 0 && e <= 6)
                .toList() ??
            [],
        isVibrateOn: data['isVibrateOn'] as bool? ?? true,
        sound: data['sound'] as String? ?? 'Default Sound',
        nextDismissedAlarm: data['nextDismissedAlarm'] != null
            ? DateTime.parse(data['nextDismissedAlarm'])
            : null,
      );

      if (data['nextOneTimeAlarm'] != null) {
        alarm._nextOneTimeAlarm = DateTime.parse(data['nextOneTimeAlarm']);
      }

      return alarm;
    } catch (e) {
      print('Error parsing AlarmData: $e');
      return AlarmData(time: TimeOfDay.now());
    }
  }

  String getDisplayDays() {
    if (selectedDays.isEmpty) {
      // One-time alarm logic
      if (!isActive) {
        return 'Not scheduled';
      }
      DateTime now = DateTime.now();
      DateTime todayAlarmTime =
          DateTime(now.year, now.month, now.day, _time.hour, _time.minute);
      if (todayAlarmTime.isAfter(now)) {
        return 'Today';
      } else {
        return 'Tomorrow';
      }
    }

    // Recurring alarm logic
    return _getRecurringDaysDisplay();
  }

  String _getRecurringDaysDisplay() {
    final Set<int> allDays = {0, 1, 2, 3, 4, 5, 6};
    final Set<int> weekdays = {1, 2, 3, 4, 5};
    final Set<int> weekends = {0, 6};

    if (selectedDays.toSet().containsAll(allDays)) {
      return 'Every day';
    } else if (selectedDays.toSet().containsAll(weekends) &&
        selectedDays.length == 2) {
      return 'Weekends';
    } else if (selectedDays.toSet().containsAll(weekdays) &&
        selectedDays.length == 5) {
      return 'Weekdays';
    } else if (selectedDays.length == 1) {
      return 'Every ${_fullDayNames[selectedDays.first]}';
    } else {
      List<int> sortedDays = List.from(selectedDays)..sort();
      return sortedDays.map((i) => _dayNames[i].substring(0, 3)).join(', ');
    }
  }

  DateTime getNextAlarmTime({bool afterDismissal = false}) {
    DateTime now = DateTime.now();
    DateTime baseTime =
        DateTime(now.year, now.month, now.day, _time.hour, _time.minute);

    if (selectedDays.isEmpty) {
      // For one-time alarms
      return baseTime.isBefore(now)
          ? baseTime.add(Duration(days: 1))
          : baseTime;
    } else {
      // For recurring alarms
      int currentDayOfWeek = now.weekday % 7;
      List<int> sortedDays = List.from(selectedDays)..sort();

      for (int i = 0; i < 14; i++) {
        // Check up to two weeks
        int checkDay = (currentDayOfWeek + i) % 7;
        if (sortedDays.contains(checkDay)) {
          DateTime checkAlarm = baseTime.add(Duration(days: i));
          if (checkAlarm.isAfter(now) &&
              (!afterDismissal || checkAlarm != nextDismissedAlarm)) {
            return checkAlarm;
          }
        }
      }

      // If we've looped through all days and haven't found a future time,
      // the next alarm will be in the following week
      return baseTime.add(Duration(days: 7));
    }
  }

  bool isWithin12Hours() {
    final now = DateTime.now();
    final nextAlarm = getNextAlarmTime();
    final difference = nextAlarm.difference(now);
    return difference.inHours >= 0 && difference.inHours < 12;
  }

  void dismissNextAlarm() {
    nextDismissedAlarm = getNextAlarmTime();
  }

  void undoDismissal() {
    nextDismissedAlarm = null;
  }

  void resetDismissalInfo() {
    nextDismissedAlarm = null;
  }

  static const List<String> _dayNames = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat'
  ];

  static const List<String> _fullDayNames = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday'
  ];
}

class AlarmTile extends StatefulWidget {
  final AlarmData data;
  final Function onDelete;
  final Function onExpand;
  final bool isExpanded;
  final Function(bool?, bool?, List<int>?) onUpdate;

  AlarmTile({
    required Key key,
    required this.data,
    required this.onDelete,
    required this.onExpand,
    required this.isExpanded,
    required this.onUpdate,
  }) : super(key: key);

  @override
  _AlarmTileState createState() => _AlarmTileState();
}

class _AlarmTileState extends State<AlarmTile> {
  void _toggleExpand() {
    widget.onExpand();
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: widget.data.time,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: true,
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() {
        widget.data.time =
            time; // This will now reset the dismissal state and update next one-time alarm
        widget.onUpdate(widget.data.isActive, null, widget.data.selectedDays);
      });
    }
  }

  Widget _buildDismissButton() {
    bool isWithin12Hours = widget.data.isWithin12Hours();
    bool isDismissed = widget.data.nextDismissedAlarm != null;
    bool isOneTimeAlarm = widget.data.selectedDays.isEmpty;

    // Don't show dismiss button for one-time alarms or inactive alarms
    if (!widget.data.isActive || !isWithin12Hours || isOneTimeAlarm) {
      return SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 0, bottom: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () {
              setState(() {
                widget.onUpdate(null, !isDismissed, null);
              });
            },
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDismissed ? Icons.close_outlined : Icons.check,
                    color: isDismissed ? Colors.grey : Colors.red,
                  ),
                  SizedBox(width: 12),
                  Text(
                    isDismissed ? 'Dismissed' : 'Dismiss next',
                    style: TextStyle(
                      color: isDismissed ? Colors.grey : Colors.red,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.grey[900],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: _toggleExpand,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () => _selectTime(context),
                              child: Text(
                                _formatTimeOfDay(widget.data.time),
                                style: TextStyle(
                                  fontSize: 48,
                                  color: widget.data.isActive
                                      ? Colors.white
                                      : Colors.grey[600],
                                  letterSpacing: -1.5,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 3),
                              child: Text(
                                widget.data.getDisplayDays(),
                                style: TextStyle(
                                  color: widget.data.isActive
                                      ? Colors.white
                                      : Colors.grey[600],
                                  fontSize: 14,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: widget.data.isActive,
                        onChanged: (value) {
                          setState(() {
                            widget.onUpdate(
                                value, null, widget.data.selectedDays);
                          });
                        },
                      ),
                    ],
                  ),
                ),
                AnimatedSize(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: Container(
                    height: widget.isExpanded ? null : 0,
                    child: _buildExpandedContent(),
                  ),
                ),
                _buildDismissButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedContent() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (int i = 0; i < 7; i++)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      List<int> newSelectedDays =
                          List.from(widget.data.selectedDays);
                      if (newSelectedDays.contains(i)) {
                        newSelectedDays.remove(i);
                      } else {
                        newSelectedDays.add(i);
                      }
                      widget.onUpdate(null, null, newSelectedDays);
                    });
                  },
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: widget.data.selectedDays.contains(i)
                        ? Colors.red[300]
                        : Colors.grey[800],
                    child: Text(
                      _dayInitials[i],
                      style: TextStyle(
                        color: widget.data.selectedDays.contains(i)
                            ? Colors.black
                            : Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 32),
          Row(
            children: [
              Icon(Icons.music_note_outlined, color: Colors.grey),
              SizedBox(width: 12),
              Text(widget.data.sound, style: TextStyle(color: Colors.grey)),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.vibration, color: Colors.grey),
                  SizedBox(width: 12),
                  Text('Vibrate', style: TextStyle(color: Colors.grey)),
                ],
              ),
              Checkbox(
                value: widget.data.isVibrateOn,
                onChanged: (bool? value) {
                  setState(() {
                    widget.data.isVibrateOn = value ?? false;
                    widget.onUpdate(null, null, null);
                  });
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              widget.onDelete();
            },
            child: Row(
              children: [
                Icon(Icons.delete_outline, color: Colors.grey),
                SizedBox(width: 12),
                Text('Delete', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const List<String> _dayInitials = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
}

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int silenceAfter = 5;
  int snoozeLength = 7;
  double alarmVolume = 0.5;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  void _loadPreferences() {
    setState(() {
      silenceAfter = prefs.getInt('silenceAfter') ?? 5;
      snoozeLength = prefs.getInt('snoozeLength') ?? 7;
      alarmVolume = prefs.getDouble('alarmVolume') ?? 0.5;
    });
    print(
        'Loaded settings: silenceAfter=$silenceAfter, snoozeLength=$snoozeLength, alarmVolume=$alarmVolume');
  }

  void _savePreferences() {
    prefs.setInt('silenceAfter', silenceAfter);
    prefs.setInt('snoozeLength', snoozeLength);
    prefs.setDouble('alarmVolume', alarmVolume);
    print(
        'Saved settings: silenceAfter=$silenceAfter, snoozeLength=$snoozeLength, alarmVolume=$alarmVolume');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: TextStyle(
                fontSize: 22,
                letterSpacing: -0.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        titleSpacing: 0,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSettingsOption(
              title: 'Silence after',
              value: '$silenceAfter minutes',
              onTap: () async {
                int? result = await _showPicker(context, silenceAfter, 2, 10);
                if (result != null) {
                  setState(() {
                    silenceAfter = result;
                    _savePreferences();
                  });
                }
              },
            ),
            SizedBox(height: 20),
            _buildSettingsOption(
              title: 'Snooze length',
              value: '$snoozeLength minutes',
              onTap: () async {
                int? result = await _showPicker(context, snoozeLength, 2, 15);
                if (result != null) {
                  setState(() {
                    snoozeLength = result;
                    _savePreferences();
                  });
                }
              },
            ),
            SizedBox(height: 20),
            Text('Alarm volume', style: TextStyle(fontSize: 20)),
            Slider(
              value: alarmVolume,
              onChanged: (value) {
                setState(() {
                  alarmVolume = value;
                  _savePreferences();
                });
              },
              min: 0.0,
              max: 1.0,
              activeColor: Colors.red,
              inactiveColor: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsOption({
    required String title,
    required String value,
    required Function onTap,
  }) {
    return InkWell(
      onTap: () => onTap(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: Colors.white, fontSize: 20)),
            SizedBox(height: 5),
            Text(value,
                style: TextStyle(color: Colors.redAccent, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Future<int?> _showPicker(
      BuildContext context, int currentValue, int min, int max) {
    return showDialog<int>(
      context: context,
      builder: (context) {
        int tempValue = currentValue;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.black,
              title: Text(
                'Select time',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 40),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.red,
                      thumbColor: Colors.red,
                      valueIndicatorColor: Colors.red,
                      valueIndicatorTextStyle: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                    child: Slider(
                      value: tempValue.toDouble(),
                      min: min.toDouble(),
                      max: max.toDouble(),
                      divisions: max - min,
                      label: '$tempValue',
                      onChanged: (value) {
                        setState(() {
                          tempValue = value.toInt();
                        });
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, currentValue),
                  child: Text('Cancel', style: TextStyle(color: Colors.white)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, tempValue),
                  child: Text('OK', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
