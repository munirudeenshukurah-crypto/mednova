import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mednova/services/notification_service.dart';
import 'package:mednova/services/offline_database.dart';

const Color medNovaPurple = Color(0xFF6C3CE9);
const Color lightPurple = Color(0xFFEDE7FF);
const Color background = Color(0xFFF9F7FC);

class Reminder {
  final String id;
  final String title;
  final String description;
  final String time;
  final String date;
  final DateTime dateTime;
  final String category;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final bool notificationEnabled;

  /// True when this reminder came automatically from
  /// a medication or appointment.
  final bool isAutomatic;

  /// appointment / medication / manual
  final String sourceType;

  /// ID of the original appointment or medication.
  final String? sourceId;

  Reminder({
    required this.id,
    required this.title,
    required this.description,
    required this.time,
    required this.date,
    required this.dateTime,
    required this.category,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    this.notificationEnabled = true,
    this.isAutomatic = false,
    this.sourceType = 'manual',
    this.sourceId,
  });

  Reminder copyWith({
    String? id,
    String? title,
    String? description,
    String? time,
    String? date,
    DateTime? dateTime,
    String? category,
    IconData? icon,
    Color? iconColor,
    Color? iconBackground,
    bool? notificationEnabled,
    bool? isAutomatic,
    String? sourceType,
    String? sourceId,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      time: time ?? this.time,
      date: date ?? this.date,
      dateTime: dateTime ?? this.dateTime,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      iconBackground: iconBackground ?? this.iconBackground,
      notificationEnabled:
      notificationEnabled ?? this.notificationEnabled,
      isAutomatic: isAutomatic ?? this.isAutomatic,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
    );
  }
}

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final Color primaryPurple = const Color(0xFF6C3CE9);
  final Color backgroundColor = const Color(0xFFF9F7FC);

  final SupabaseClient supabase = Supabase.instance.client;

  final List<Reminder> reminders = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  // ============================================================
  // LOAD ALL REMINDERS
  // ============================================================

  Future<void> _loadReminders() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    final user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        reminders.clear();
        isLoading = false;
      });

      return;
    }

    final List<Reminder> loadedReminders = [];

    try {
      // ==========================================================
      // ONLINE: LOAD FROM SUPABASE AND UPDATE LOCAL CACHE
      // ==========================================================

      final appointmentResponse = await supabase
          .from('appointments')
          .select()
          .eq('user_id', user.id);

      final medicationResponse = await supabase
          .from('medications')
          .select()
          .eq('user_id', user.id);

      final appointmentRows = (appointmentResponse as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      final medicationRows = (medicationResponse as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      // Cache the latest remote data locally so the Reminders screen
      // can still build appointment and medication reminders offline.
      for (final row in appointmentRows) {
        await OfflineDatabase.instance.saveAppointment({
          ...row,
          'user_id': user.id,
        });
      }

      for (final row in medicationRows) {
        await OfflineDatabase.instance.saveMedication({
          ...row,
          'user_id': user.id,
        });
      }

      // Build reminders from the fresh Supabase data.
      for (final map in appointmentRows) {
        final Reminder? reminder = _appointmentToReminder(map);

        if (reminder != null) {
          loadedReminders.add(reminder);
        }
      }

      for (final map in medicationRows) {
        loadedReminders.addAll(_medicationToReminders(map));
      }
    } catch (e) {
      // ==========================================================
      // OFFLINE / SUPABASE ERROR: LOAD FROM LOCAL CACHE
      // ==========================================================

      try {
        final cachedAppointments =
        await OfflineDatabase.instance.getAppointments(user.id);

        final cachedMedications =
        await OfflineDatabase.instance.getMedications(user.id);

        for (final item in cachedAppointments) {
          final map = Map<String, dynamic>.from(item);
          final Reminder? reminder = _appointmentToReminder(map);

          if (reminder != null) {
            loadedReminders.add(reminder);
          }
        }

        for (final item in cachedMedications) {
          final map = Map<String, dynamic>.from(item);
          loadedReminders.addAll(_medicationToReminders(map));
        }
      } catch (cacheError) {
        if (!mounted) return;

        setState(() {
          reminders.clear();
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not load reminders. Please reconnect to the internet and try again.',
            ),
          ),
        );

        debugPrint('Reminders cache error: $cacheError');
        return;
      }

      debugPrint('Reminders loaded from offline cache: $e');
    }

    // ==========================================================
    // SORT BY DATE + TIME
    // ==========================================================

    loadedReminders.sort(
          (a, b) => a.dateTime.compareTo(b.dateTime),
    );

    if (!mounted) return;

    setState(() {
      reminders
        ..clear()
        ..addAll(loadedReminders);
      isLoading = false;
    });
  }

  // ============================================================
  // APPOINTMENT -> REMINDER
  // ============================================================

  Reminder? _appointmentToReminder(
      Map<String, dynamic> map,
      ) {
    final String dateString =
        map['date']?.toString() ?? '';

    final String timeString =
        map['time']?.toString() ?? '';

    final DateTime? appointmentDateTime =
    _parseDateAndTime(
      dateString,
      timeString,
    );

    if (appointmentDateTime == null) {
      return null;
    }

    if (appointmentDateTime.isBefore(
      DateTime.now().subtract(
        const Duration(minutes: 1),
      ),
    )) {
      return null;
    }

    final String appointmentId =
        map['id']?.toString() ??
            'appointment-${dateString}-${timeString}';

    final String title =
    map['title']?.toString().trim().isNotEmpty == true
        ? map['title'].toString()
        : "Doctor's Appointment";

    final String doctor =
        map['doctor']?.toString() ?? '';

    final String hospital =
        map['hospital']?.toString() ?? '';

    String description = doctor;

    if (hospital.isNotEmpty && doctor.isNotEmpty) {
      description = '$doctor • $hospital';
    } else if (hospital.isNotEmpty) {
      description = hospital;
    }

    if (description.isEmpty) {
      description = 'Healthcare appointment';
    }

    return Reminder(
      id: 'appointment_$appointmentId',
      title: title,
      description: description,
      time: _formatTime(appointmentDateTime),
      date: _displayDate(appointmentDateTime),
      dateTime: appointmentDateTime,
      category: 'Appointment',
      icon: Icons.calendar_month_outlined,
      iconColor: const Color(0xFF6C3CE9),
      iconBackground: const Color(0xFFEDE7FF),
      notificationEnabled: true,
      isAutomatic: true,
      sourceType: 'appointment',
      sourceId: appointmentId,
    );
  }

  // ============================================================
  // MEDICATION -> REMINDERS
  // ============================================================

  List<Reminder> _medicationToReminders(
      Map<String, dynamic> map,
      ) {
    final List<Reminder> result = [];

    final String medicationId =
        map['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString();

    final String name =
    map['name']?.toString().trim().isNotEmpty == true
        ? map['name'].toString()
        : 'Medication';

    final String dosage =
        map['dosage']?.toString() ?? '';

    final String instruction =
        map['instruction']?.toString() ?? '';

    final DateTime? startDate =
    _parseDatabaseDate(
      map['start_date'],
    );

    DateTime? endDate =
    _parseDatabaseDate(
      map['end_date'],
    );

    int? durationDays;

    if (map['duration_days'] != null) {
      durationDays = int.tryParse(
        map['duration_days'].toString(),
      );
    }

    final DateTime effectiveStart =
    _dateOnly(
      startDate ?? DateTime.now(),
    );

    if (endDate == null && durationDays != null) {
      endDate = effectiveStart.add(
        Duration(
          days: durationDays - 1,
        ),
      );
    }

    final DateTime effectiveEnd =
    _dateOnly(
      endDate ?? effectiveStart,
    );

    // ----------------------------------------------------------
    // MEDICATION TIMES
    // ----------------------------------------------------------

    List<String> times = [];

    final dynamic rawTimes = map['times'];

    if (rawTimes is List) {
      times = rawTimes
          .map(
            (item) => item.toString(),
      )
          .where(
            (item) => item.trim().isNotEmpty,
      )
          .toList();
    } else if (rawTimes is String &&
        rawTimes.trim().isNotEmpty) {
      times = rawTimes
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    // Fallback in case an older medication record uses
    // a single "time" column.
    if (times.isEmpty &&
        map['time'] != null &&
        map['time'].toString().trim().isNotEmpty) {
      times = [
        map['time'].toString(),
      ];
    }

    if (times.isEmpty) {
      return result;
    }

    final DateTime today =
    _dateOnly(DateTime.now());

    DateTime currentDate = effectiveStart;

    // We only display future/current reminders.
    if (currentDate.isBefore(today)) {
      currentDate = today;
    }

    while (!currentDate.isAfter(effectiveEnd)) {
      for (final String timeString in times) {
        final TimeOfDay? parsedTime =
        _parseTimeOfDay(timeString);

        if (parsedTime == null) {
          continue;
        }

        final DateTime reminderDateTime =
        DateTime(
          currentDate.year,
          currentDate.month,
          currentDate.day,
          parsedTime.hour,
          parsedTime.minute,
        );

        // Do not display old medication doses.
        if (reminderDateTime.isBefore(
          DateTime.now().subtract(
            const Duration(minutes: 1),
          ),
        )) {
          continue;
        }

        String description = dosage;

        if (instruction.isNotEmpty &&
            dosage.isNotEmpty) {
          description = '$dosage • $instruction';
        } else if (instruction.isNotEmpty) {
          description = instruction;
        }

        if (description.isEmpty) {
          description = 'Take your medication';
        }

        result.add(
          Reminder(
            id:
            'medication_${medicationId}_${_dateKey(currentDate)}_${_timeKey(parsedTime)}',
            title: 'Take $name',
            description: description,
            time: _formatTime(reminderDateTime),
            date: _displayDate(reminderDateTime),
            dateTime: reminderDateTime,
            category: 'Medication',
            icon: Icons.medication_outlined,
            iconColor: const Color(0xFF6C3CE9),
            iconBackground: const Color(0xFFEDE7FF),
            notificationEnabled: true,
            isAutomatic: true,
            sourceType: 'medication',
            sourceId: medicationId,
          ),
        );
      }

      currentDate =
          currentDate.add(const Duration(days: 1));
    }

    return result;
  }

  // ============================================================
  // DATE HELPERS
  // ============================================================

  DateTime _dateOnly(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  DateTime? _parseDatabaseDate(
      dynamic value,
      ) {
    if (value == null) {
      return null;
    }

    final String valueString =
    value.toString().trim();

    if (valueString.isEmpty) {
      return null;
    }

    final DateTime? direct =
    DateTime.tryParse(valueString);

    if (direct != null) {
      return _dateOnly(direct);
    }

    return _parseFlexibleDate(
      valueString,
    );
  }

  DateTime? _parseFlexibleDate(
      String value,
      ) {
    final String cleaned =
    value.trim();

    // yyyy-MM-dd
    final RegExp isoPattern = RegExp(
      r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})',
    );

    final Match? isoMatch =
    isoPattern.firstMatch(cleaned);

    if (isoMatch != null) {
      return DateTime(
        int.parse(isoMatch.group(1)!),
        int.parse(isoMatch.group(2)!),
        int.parse(isoMatch.group(3)!),
      );
    }

    // Month names
    final RegExp monthPattern = RegExp(
      r'^([A-Za-z]+)\s+(\d{1,2}),?\s+(\d{4})',
      caseSensitive: false,
    );

    final Match? monthMatch =
    monthPattern.firstMatch(cleaned);

    if (monthMatch != null) {
      final int? month =
      _monthNumber(monthMatch.group(1)!);

      if (month != null) {
        return DateTime(
          int.parse(monthMatch.group(3)!),
          month,
          int.parse(monthMatch.group(2)!),
        );
      }
    }

    // dd/MM/yyyy or MM/dd/yyyy
    final RegExp slashPattern = RegExp(
      r'^(\d{1,2})/(\d{1,2})/(\d{4})',
    );

    final Match? slashMatch =
    slashPattern.firstMatch(cleaned);

    if (slashMatch != null) {
      final int first =
      int.parse(slashMatch.group(1)!);

      final int second =
      int.parse(slashMatch.group(2)!);

      final int year =
      int.parse(slashMatch.group(3)!);

      // If first > 12, it must be day/month/year.
      if (first > 12) {
        return DateTime(
          year,
          second,
          first,
        );
      }

      // Otherwise treat it as month/day/year.
      return DateTime(
        year,
        first,
        second,
      );
    }

    return null;
  }

  int? _monthNumber(String month) {
    const months = {
      'january': 1,
      'jan': 1,
      'february': 2,
      'feb': 2,
      'march': 3,
      'mar': 3,
      'april': 4,
      'apr': 4,
      'may': 5,
      'june': 6,
      'jun': 6,
      'july': 7,
      'jul': 7,
      'august': 8,
      'aug': 8,
      'september': 9,
      'sep': 9,
      'sept': 9,
      'october': 10,
      'oct': 10,
      'november': 11,
      'nov': 11,
      'december': 12,
      'dec': 12,
    };

    return months[month.toLowerCase()];
  }

  DateTime? _parseDateAndTime(
      String date,
      String time,
      ) {
    final DateTime? parsedDate =
    _parseFlexibleDate(date);

    final TimeOfDay? parsedTime =
    _parseTimeOfDay(time);

    if (parsedDate == null ||
        parsedTime == null) {
      return null;
    }

    return DateTime(
      parsedDate.year,
      parsedDate.month,
      parsedDate.day,
      parsedTime.hour,
      parsedTime.minute,
    );
  }

  TimeOfDay? _parseTimeOfDay(
      String value,
      ) {
    try {
      final String cleaned =
      value.trim().toUpperCase();

      final RegExp pattern = RegExp(
        r'^(\d{1,2}):(\d{2})(?:\s*)(AM|PM)?$',
      );

      final Match? match =
      pattern.firstMatch(cleaned);

      if (match == null) {
        return null;
      }

      int hour =
      int.parse(match.group(1)!);

      final int minute =
      int.parse(match.group(2)!);

      final String? period =
      match.group(3);

      if (period == 'PM' && hour != 12) {
        hour += 12;
      }

      if (period == 'AM' && hour == 12) {
        hour = 0;
      }

      if (hour > 23 || minute > 59) {
        return null;
      }

      return TimeOfDay(
        hour: hour,
        minute: minute,
      );
    } catch (_) {
      return null;
    }
  }

  String _formatTime(DateTime dateTime) {
    final int hour24 = dateTime.hour;

    final String period =
    hour24 >= 12 ? 'PM' : 'AM';

    final int hour12 =
    hour24 % 12 == 0
        ? 12
        : hour24 % 12;

    final String minute =
    dateTime.minute
        .toString()
        .padLeft(2, '0');

    return '$hour12:$minute $period';
  }

  String _displayDate(DateTime dateTime) {
    final DateTime today =
    _dateOnly(DateTime.now());

    final DateTime tomorrow =
    today.add(
      const Duration(days: 1),
    );

    final DateTime date =
    _dateOnly(dateTime);

    if (date == today) {
      return 'Today';
    }

    if (date == tomorrow) {
      return 'Tomorrow';
    }

    const months = [
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

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _dateKey(DateTime date) {
    return '${date.year}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _timeKey(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final List<Reminder> todayReminders =
    reminders.where((reminder) {
      return _isSameDay(
        reminder.dateTime,
        DateTime.now(),
      );
    }).toList();

    final List<Reminder> tomorrowReminders =
    reminders.where((reminder) {
      return _isSameDay(
        reminder.dateTime,
        DateTime.now().add(
          const Duration(days: 1),
        ),
      );
    }).toList();

    final List<Reminder> laterReminders =
    reminders.where((reminder) {
      final DateTime today =
      _dateOnly(DateTime.now());

      return _dateOnly(
        reminder.dateTime,
      ).isAfter(
        today.add(
          const Duration(days: 1),
        ),
      );
    }).toList();

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),

            Expanded(
              child: isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: medNovaPurple,
                ),
              )
                  : SingleChildScrollView(
                physics:
                const BouncingScrollPhysics(),
                padding:
                const EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  30,
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    _buildPageHeader(),

                    const SizedBox(height: 28),

                    if (todayReminders
                        .isNotEmpty) ...[
                      _buildSectionTitle(
                        'Today',
                      ),
                      const SizedBox(height: 12),
                      ...todayReminders.map(
                            (reminder) =>
                            Padding(
                              padding:
                              const EdgeInsets
                                  .only(
                                bottom: 12,
                              ),
                              child:
                              _buildReminderCard(
                                reminder,
                              ),
                            ),
                      ),
                    ],

                    if (tomorrowReminders
                        .isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildSectionTitle(
                        'Tomorrow',
                      ),
                      const SizedBox(height: 12),
                      ...tomorrowReminders.map(
                            (reminder) =>
                            Padding(
                              padding:
                              const EdgeInsets
                                  .only(
                                bottom: 12,
                              ),
                              child:
                              _buildReminderCard(
                                reminder,
                              ),
                            ),
                      ),
                    ],

                    if (laterReminders
                        .isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildSectionTitle(
                        'Upcoming',
                      ),
                      const SizedBox(height: 12),
                      ...laterReminders.map(
                            (reminder) =>
                            Padding(
                              padding:
                              const EdgeInsets
                                  .only(
                                bottom: 12,
                              ),
                              child:
                              _buildReminderCard(
                                reminder,
                              ),
                            ),
                      ),
                    ],

                    if (todayReminders.isEmpty &&
                        tomorrowReminders
                            .isEmpty &&
                        laterReminders
                            .isEmpty)
                      _buildEmptyState(),

                    const SizedBox(height: 18),

                    _buildAddReminderButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
      _buildBottomNavigationBar(),
    );
  }

  bool _isSameDay(
      DateTime first,
      DateTime second,
      ) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar() {
    return Padding(
      padding:
      const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: Color(0xFF242424),
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Reminders',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF222222),
                ),
              ),
            ),
          ),
          const SizedBox(width: 42),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildPageHeader() {
    return const Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          'My Reminders',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w700,
            color: Color(0xFF202020),
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Never miss an important health task.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF777777),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Color(0xFF242424),
      ),
    );
  }

  // ============================================================
  // REMINDER CARD
  // ============================================================

  Widget _buildReminderCard(
      Reminder reminder,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: reminder.iconBackground,
              borderRadius:
              BorderRadius.circular(15),
            ),
            child: Icon(
              reminder.icon,
              color: reminder.iconColor,
              size: 25,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.title,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight:
                    FontWeight.w700,
                    color: Color(0xFF242424),
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  reminder.description,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF777777),
                  ),
                ),

                const SizedBox(height: 7),

                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 15,
                      color: primaryPurple,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      reminder.time,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                        FontWeight.w600,
                        color: primaryPurple,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 5),

          _buildMoreMenu(reminder),

          const SizedBox(width: 2),

          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F4FC),
              borderRadius:
              BorderRadius.circular(12),
            ),
            child: Icon(
              reminder.notificationEnabled
                  ? Icons.notifications_none_rounded
                  : Icons.notifications_off_outlined,
              size: 20,
              color: reminder.notificationEnabled
                  ? primaryPurple
                  : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MENU
  // ============================================================

  Widget _buildMoreMenu(
      Reminder reminder,
      ) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: const Icon(
        Icons.more_vert_rounded,
        size: 22,
        color: Color(0xFF666666),
      ),
      shape: RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(14),
      ),
      elevation: 5,
      onSelected: (value) {
        if (value == 'edit') {
          _editReminder(reminder);
        }

        if (value == 'delete') {
          _confirmDeleteReminder(reminder);
        }
      },
      itemBuilder: (context) {
        return [
          const PopupMenuItem<String>(
            value: 'edit',
            child: Row(
              children: [
                Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: Color(0xFF6C3CE9),
                ),
                SizedBox(width: 12),
                Text(
                  'Edit Reminder',
                  style: TextStyle(
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: Colors.red,
                ),
                SizedBox(width: 12),
                Text(
                  'Delete Reminder',
                  style: TextStyle(
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ];
      },
    );
  }

  // ============================================================
  // ADD REMINDER
  // ============================================================

  Widget _buildAddReminderButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _openAddReminder,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(16),
          ),
        ),
        icon: const Icon(
          Icons.add_rounded,
          size: 22,
        ),
        label: const Text(
          'Add Reminder',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> _openAddReminder() async {
    final result =
    await context.push<Reminder>(
      '/reminders/add',
    );

    if (result == null) return;

    setState(() {
      reminders.add(result);
      reminders.sort(
            (a, b) =>
            a.dateTime.compareTo(
              b.dateTime,
            ),
      );
    });

    await _scheduleManualReminderAlarm(result);
  }

  // ============================================================
  // EDIT
  // ============================================================

  Future<void> _editReminder(
      Reminder reminder,
      ) async {
    if (reminder.isAutomatic) {
      if (reminder.sourceType ==
          'appointment') {
        _showMessage(
          'This reminder comes from your appointment. Edit the appointment to change it.',
        );
      } else if (reminder.sourceType ==
          'medication') {
        _showMessage(
          'This reminder comes from your medication. Edit the medication to change it.',
        );
      }

      return;
    }

    final result =
    await context.push<Reminder>(
      '/reminders/add',
      extra: reminder,
    );

    if (result == null) return;

    setState(() {
      final index =
      reminders.indexWhere(
            (item) => item.id == reminder.id,
      );

      if (index != -1) {
        reminders[index] = result;
      }

      reminders.sort(
            (a, b) =>
            a.dateTime.compareTo(
              b.dateTime,
            ),
      );
    });

    await _cancelManualReminderAlarm(reminder);
    await _scheduleManualReminderAlarm(result);
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> _confirmDeleteReminder(
      Reminder reminder,
      ) async {
    if (reminder.isAutomatic) {
      if (reminder.sourceType ==
          'appointment') {
        _showMessage(
          'This reminder is linked to an appointment. Delete the appointment to remove its reminder.',
        );
      } else if (reminder.sourceType ==
          'medication') {
        _showMessage(
          'This reminder is linked to a medication. Delete the medication to remove its reminder.',
        );
      }

      return;
    }

    final bool? shouldDelete =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(20),
          ),
          title: const Text(
            'Delete Reminder?',
            style: TextStyle(
              fontWeight:
              FontWeight.w700,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${reminder.title}"?',
            style: const TextStyle(
              color: Color(0xFF666666),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF666666),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    await _cancelManualReminderAlarm(reminder);

    setState(() {
      reminders.removeWhere(
            (item) => item.id == reminder.id,
      );
    });

    _showMessage('Reminder deleted');
  }

  // ============================================================
  // REMINDER ALARM HELPERS
  // ============================================================

  int _reminderAlarmId(String reminderId) {
    final String value = 'manual_reminder|$reminderId';

    int hash = 2166136261;

    for (final int codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0x7fffffff;
    }

    return hash == 0 ? 1 : hash;
  }

  Future<void> _scheduleManualReminderAlarm(
      Reminder reminder,
      ) async {
    if (reminder.isAutomatic ||
        !reminder.notificationEnabled ||
        reminder.dateTime.isBefore(DateTime.now())) {
      return;
    }

    await NotificationService.instance.scheduleReminder(
      id: _reminderAlarmId(reminder.id),
      title: reminder.title,
      body: reminder.description,
      dateTime: reminder.dateTime,
    );
  }

  Future<void> _cancelManualReminderAlarm(
      Reminder reminder,
      ) async {
    if (reminder.isAutomatic) {
      return;
    }

    await NotificationService.instance.cancelReminder(
      _reminderAlarmId(reminder.id),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        duration:
        const Duration(seconds: 2),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(
        top: 60,
        bottom: 30,
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration:
              const BoxDecoration(
                color: Color(0xFFEDE7FF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                color: primaryPurple,
                size: 38,
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'No reminders yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                FontWeight.w700,
              ),
            ),

            const SizedBox(height: 7),

            const Text(
              'Add a reminder to stay on top of your health tasks.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF777777),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_outlined,
                label: 'Home',
                onTap: () {
                  context.go('/home');
                },
              ),

              _buildNavItem(
                icon:
                Icons.notifications_none_rounded,
                label: 'Reminders',
                isSelected: true,
                onTap: () {},
              ),

              _buildAddNavButton(),

              _buildNavItem(
                icon:
                Icons.calendar_month_outlined,
                label: 'Appointments',
                onTap: () {
                  context.go('/appointments');
                },
              ),

              _buildNavItem(
                icon:
                Icons.person_outline_rounded,
                label: 'Profile',
                onTap: () {
                  context.go('/profile');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior:
      HitTestBehavior.opaque,
      child: SizedBox(
        width: 65,
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 23,
              color: isSelected
                  ? primaryPurple
                  : const Color(0xFF929292),
            ),

            const SizedBox(height: 4),

            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isSelected
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: isSelected
                    ? primaryPurple
                    : const Color(0xFF929292),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddNavButton() {
    return GestureDetector(
      onTap: _openAddReminder,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: primaryPurple,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color:
              primaryPurple.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 27,
        ),
      ),
    );
  }
}