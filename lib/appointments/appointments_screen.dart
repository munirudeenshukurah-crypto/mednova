import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mednova/services/notification_service.dart';
import 'package:mednova/services/offline_database.dart';

const Color medNovaPurple = Color(0xFF6C3CE9);
const Color lightPurple = Color(0xFFF0EAFF);
const Color darkText = Color(0xFF29263A);
const Color greyText = Color(0xFF777383);
const Color background = Color(0xFFF9F7FC);

class Appointment {
  final String? id;
  String title;
  String hospital;
  String doctor;
  String date;
  String time;
  bool upcoming;

  Appointment({
    this.id,
    required this.title,
    required this.hospital,
    required this.doctor,
    required this.date,
    required this.time,
    required this.upcoming,
  });

  factory Appointment.fromMap(Map<String, dynamic> map) {
    final dynamic rawUpcoming = map['upcoming'];

    final bool parsedUpcoming = rawUpcoming == null
        ? true
        : rawUpcoming == true ||
        rawUpcoming == 1 ||
        rawUpcoming.toString().toLowerCase() == 'true';

    return Appointment(
      id: map['id']?.toString(),
      title: map['title']?.toString() ?? '',
      hospital: map['hospital']?.toString() ?? '',
      doctor: map['doctor']?.toString() ?? '',
      date: map['date']?.toString() ?? '',
      time: map['time']?.toString() ?? '',
      upcoming: parsedUpcoming,
    );
  }

  Map<String, dynamic> toMap(String userId) {
    return {
      'user_id': userId,
      'title': title,
      'hospital': hospital,
      'doctor': doctor,
      'date': date,
      'time': time,
      'upcoming': upcoming,
    };
  }

  Map<String, dynamic> toLocalMap(String userId) {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'hospital': hospital,
      'doctor': doctor,
      'date': date,
      'time': time,
      'upcoming': upcoming ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  static const Color purple = Color(0xFF6C3CE9);
  static const Color navGrey = Color(0xFF777383);

  final SupabaseClient supabase = Supabase.instance.client;

  final List<Appointment> appointments = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadAppointments();
  }

  // ============================================================
  // LOAD APPOINTMENTS
  // ============================================================

  Future<void> loadAppointments() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      return;
    }

    try {
      // --------------------------------------------------------
      // ONLINE: LOAD FROM SUPABASE
      // --------------------------------------------------------

      final response = await supabase
          .from('appointments')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: true);

      final remoteRows = (response as List)
          .map(
            (item) => Map<String, dynamic>.from(item),
      )
          .toList();

      // --------------------------------------------------------
      // SAVE REMOTE APPOINTMENTS TO LOCAL SQLITE CACHE
      // --------------------------------------------------------

      for (final row in remoteRows) {
        await OfflineDatabase.instance.saveAppointment({
          ...row,
          'user_id': user.id,
        });
      }

      final loadedAppointments = remoteRows
          .map(
            (item) => Appointment.fromMap(item),
      )
          .toList();

      if (!mounted) return;

      setState(() {
        appointments
          ..clear()
          ..addAll(loadedAppointments);
        isLoading = false;
      });

      // Restore alarms for saved upcoming appointments.
      for (final appointment in loadedAppointments) {
        await _scheduleAppointmentAlarm(appointment);
      }
    } catch (e) {
      // --------------------------------------------------------
      // OFFLINE: LOAD FROM LOCAL SQLITE CACHE
      // --------------------------------------------------------

      try {
        final localRows = await OfflineDatabase.instance
            .getAppointments(user.id);

        final loadedAppointments = localRows
            .map(
              (item) => Appointment.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
            .toList();

        if (!mounted) return;

        setState(() {
          appointments
            ..clear()
            ..addAll(loadedAppointments);
          isLoading = false;
        });

        // Restore alarms for cached upcoming appointments.
        for (final appointment in loadedAppointments) {
          await _scheduleAppointmentAlarm(appointment);
        }
      } catch (localError) {
        if (!mounted) return;

        setState(() {
          isLoading = false;
        });

        _showMessage(
          'Unable to load your appointments.',
        );
      }
    }
  }

  // ============================================================
  // ADD APPOINTMENT
  // ============================================================

  Future<void> addAppointment() async {
    final result = await context.push<Appointment>(
      '/appointments/add',
    );

    if (result == null) return;

    await saveNewAppointment(result);
  }

  Future<void> saveNewAppointment(
      Appointment appointment,
      ) async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        _showMessage(
          'Please log in to save your appointment.',
        );
        return;
      }

      // --------------------------------------------------------
      // SAVE TO SUPABASE
      // --------------------------------------------------------

      final response = await supabase
          .from('appointments')
          .insert(
        appointment.toMap(user.id),
      )
          .select()
          .single();

      final savedAppointment =
      Appointment.fromMap(response);

      // --------------------------------------------------------
      // UPDATE LOCAL CACHE
      // --------------------------------------------------------

      await OfflineDatabase.instance.saveAppointment(
        savedAppointment.toLocalMap(user.id),
      );

      if (!mounted) return;

      setState(() {
        appointments.add(savedAppointment);
      });

      await _scheduleAppointmentAlarm(
        savedAppointment,
      );

      _showMessage(
        'Appointment saved successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Could not save appointment. Please try again.',
      );
    }
  }

  // ============================================================
  // EDIT APPOINTMENT
  // ============================================================

  Future<void> editAppointment(
      Appointment appointment,
      ) async {
    final result = await context.push<Appointment>(
      '/appointments/edit',
      extra: appointment,
    );

    if (result == null) return;

    await updateAppointment(
      oldAppointment: appointment,
      updatedAppointment: result,
    );
  }

  Future<void> updateAppointment({
    required Appointment oldAppointment,
    required Appointment updatedAppointment,
  }) async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        _showMessage(
          'Please log in to update your appointment.',
        );
        return;
      }

      if (oldAppointment.id == null) {
        _showMessage(
          'This appointment cannot be updated because its ID is missing.',
        );
        return;
      }

      // --------------------------------------------------------
      // UPDATE SUPABASE
      // --------------------------------------------------------

      final response = await supabase
          .from('appointments')
          .update({
        'title': updatedAppointment.title,
        'hospital': updatedAppointment.hospital,
        'doctor': updatedAppointment.doctor,
        'date': updatedAppointment.date,
        'time': updatedAppointment.time,
        'upcoming': updatedAppointment.upcoming,
      })
          .eq('id', oldAppointment.id!)
          .eq('user_id', user.id)
          .select()
          .single();

      final savedAppointment =
      Appointment.fromMap(response);

      // --------------------------------------------------------
      // UPDATE LOCAL CACHE
      // --------------------------------------------------------

      await OfflineDatabase.instance.saveAppointment(
        savedAppointment.toLocalMap(user.id),
      );

      if (!mounted) return;

      setState(() {
        final index = appointments.indexOf(
          oldAppointment,
        );

        if (index != -1) {
          appointments[index] = savedAppointment;
        }
      });

      // Cancel old alarm and create the new one.
      await _cancelAppointmentAlarm(
        oldAppointment,
      );

      await _scheduleAppointmentAlarm(
        savedAppointment,
      );

      _showMessage(
        'Appointment updated successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Could not update appointment. Please try again.',
      );
    }
  }

  // ============================================================
  // DELETE APPOINTMENT
  // ============================================================

  Future<void> deleteAppointment(
      Appointment appointment,
      ) async {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Appointment',
          ),
          content: const Text(
            'Are you sure you want to delete this appointment?',
          ),
          actions: [
            TextButton(
              onPressed: () => dialogContext.pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: greyText,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                dialogContext.pop();

                await _deleteAppointmentFromSupabase(
                  appointment,
                );
              },
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.red,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAppointmentFromSupabase(
      Appointment appointment,
      ) async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        _showMessage(
          'Please log in to delete your appointment.',
        );
        return;
      }

      if (appointment.id == null) {
        _showMessage(
          'This appointment cannot be deleted because its ID is missing.',
        );
        return;
      }

      // --------------------------------------------------------
      // DELETE FROM SUPABASE
      // --------------------------------------------------------

      await supabase
          .from('appointments')
          .delete()
          .eq('id', appointment.id!)
          .eq('user_id', user.id);

      // --------------------------------------------------------
      // DELETE FROM LOCAL CACHE
      // --------------------------------------------------------

      await OfflineDatabase.instance.deleteAppointment(
        appointment.id!,
      );

      await _cancelAppointmentAlarm(
        appointment,
      );

      if (!mounted) return;

      setState(() {
        appointments.remove(appointment);
      });

      _showMessage(
        'Appointment deleted',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Could not delete appointment. Please try again.',
      );
    }
  }

  // ============================================================
  // APPOINTMENT ALARM HELPERS
  // ============================================================

  int _appointmentAlarmId(
      String appointmentId,
      ) {
    final String value =
        'appointment|$appointmentId';

    int hash = 2166136261;

    for (final int codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0x7fffffff;
    }

    return hash == 0 ? 1 : hash;
  }

  DateTime? _appointmentDateTime(
      Appointment appointment,
      ) {
    final DateTime? parsedDate =
    _parseAppointmentDate(
      appointment.date,
    );

    final TimeOfDay? parsedTime =
    _parseAppointmentTime(
      appointment.time,
    );

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

  DateTime? _parseAppointmentDate(
      String value,
      ) {
    final String cleaned = value.trim();

    if (cleaned.isEmpty) {
      return null;
    }

    try {
      final DateTime? direct =
      DateTime.tryParse(cleaned);

      if (direct != null) {
        return DateTime(
          direct.year,
          direct.month,
          direct.day,
        );
      }

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

      final RegExp monthPattern = RegExp(
        r'^([A-Za-z]+)\s+(\d{1,2}),?\s+(\d{4})',
        caseSensitive: false,
      );

      final Match? monthMatch =
      monthPattern.firstMatch(cleaned);

      if (monthMatch != null) {
        final int? month =
        _monthNumber(
          monthMatch.group(1)!,
        );

        if (month != null) {
          return DateTime(
            int.parse(monthMatch.group(3)!),
            month,
            int.parse(monthMatch.group(2)!),
          );
        }
      }

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

        if (first > 12) {
          return DateTime(
            year,
            second,
            first,
          );
        }

        return DateTime(
          year,
          first,
          second,
        );
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  int? _monthNumber(
      String month,
      ) {
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

    return months[
    month.toLowerCase()
    ];
  }

  TimeOfDay? _parseAppointmentTime(
      String value,
      ) {
    final String cleaned =
    value.trim().toUpperCase();

    try {
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

      if (hour > 23 ||
          minute > 59) {
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

  Future<void> _scheduleAppointmentAlarm(
      Appointment appointment,
      ) async {
    if (appointment.id == null ||
        !appointment.upcoming) {
      return;
    }

    final DateTime? appointmentDateTime =
    _appointmentDateTime(
      appointment,
    );

    if (appointmentDateTime == null ||
        appointmentDateTime.isBefore(
          DateTime.now(),
        )) {
      return;
    }

    final int alarmId =
    _appointmentAlarmId(
      appointment.id!,
    );

    await NotificationService.instance
        .scheduleReminder(
      id: alarmId,
      title: 'Appointment Reminder',
      body: appointment.doctor.isNotEmpty
          ? '${appointment.title} • ${appointment.doctor}'
          : appointment.title,
      dateTime: appointmentDateTime,
    );
  }

  Future<void> _cancelAppointmentAlarm(
      Appointment appointment,
      ) async {
    if (appointment.id == null) {
      return;
    }

    await NotificationService.instance
        .cancelReminder(
      _appointmentAlarmId(
        appointment.id!,
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
      String message,
      ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        title: const Text(
          'Appointments',
          style: TextStyle(
            color: darkText,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(
              right: 16,
            ),
            child: TextButton.icon(
              onPressed: addAppointment,
              icon: const Icon(
                Icons.add,
                color: medNovaPurple,
              ),
              label: const Text(
                'Add',
                style: TextStyle(
                  color: medNovaPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: medNovaPurple,
        ),
      )
          : appointments.isEmpty
          ? _emptyState()
          : ListView.builder(
        padding:
        const EdgeInsets.all(20),
        itemCount:
        appointments.length,
        itemBuilder:
            (context, index) {
          final appointment =
          appointments[index];

          return _AppointmentCard(
            appointment:
            appointment,
            onTap: () {
              context.push(
                '/appointment-details',
                extra: appointment,
              );
            },
            onEdit: () {
              editAppointment(
                appointment,
              );
            },
            onDelete: () {
              deleteAppointment(
                appointment,
              );
            },
          );
        },
      ),
      bottomNavigationBar:
      _buildBottomNavigation(context),
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomNavigation(
      BuildContext context,
      ) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 15,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 72,
          child: Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceAround,
            children: [
              _bottomNavItem(
                icon: Icons.home_outlined,
                label: 'Home',
                selected: false,
                onTap: () {
                  context.go('/home');
                },
              ),
              _bottomNavItem(
                icon:
                Icons.calendar_month_outlined,
                label: 'Calendar',
                selected: true,
                onTap: () {},
              ),
              GestureDetector(
                onTap: () {
                  context.push(
                    '/medications/add',
                  );
                },
                child: Container(
                  width: 54,
                  height: 54,
                  decoration:
                  const BoxDecoration(
                    color: purple,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              _bottomNavItem(
                icon:
                Icons.chat_bubble_outline,
                label: 'Messages',
                selected: false,
                onTap: () {
                  context.push('/messages');
                },
              ),
              _bottomNavItem(
                icon: Icons.person_outline,
                label: 'Profile',
                selected: false,
                onTap: () {
                  context.push('/profile');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomNavItem({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 55,
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color:
              selected ? purple : navGrey,
              size: 23,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? purple
                    : navGrey,
                fontSize: 10,
                fontWeight: selected
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: lightPurple,
                borderRadius:
                BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: medNovaPurple,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No appointments yet',
              style: TextStyle(
                color: darkText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first appointment to keep track of your healthcare visits.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: greyText,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: addAppointment,
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                medNovaPurple,
                foregroundColor:
                Colors.white,
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Add Appointment',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// APPOINTMENT CARD
// ================================================================

class _AppointmentCard
    extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AppointmentCard({
    required this.appointment,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin:
        const EdgeInsets.only(bottom: 16),
        padding:
        const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color:
              Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset:
              const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: lightPurple,
                borderRadius:
                BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: medNovaPurple,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.title,
                    style:
                    const TextStyle(
                      color: darkText,
                      fontSize: 16,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    appointment.hospital,
                    style:
                    const TextStyle(
                      color: greyText,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons
                            .calendar_today_outlined,
                        size: 14,
                        color: greyText,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          appointment.date,
                          style:
                          const TextStyle(
                            color: greyText,
                            fontSize: 12,
                          ),
                          overflow:
                          TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color: greyText,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        appointment.time,
                        style:
                        const TextStyle(
                          color: greyText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value ==
                    'delete') {
                  onDelete();
                }
              },
              itemBuilder: (context) =>
              const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.red,
                      ),
                      SizedBox(width: 10),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// APPOINTMENT DETAILS
// ================================================================

class AppointmentDetailsScreen
    extends StatelessWidget {
  final Appointment appointment;

  const AppointmentDetailsScreen({
    super.key,
    required this.appointment,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        leading: IconButton(
          onPressed: () =>
              context.pop(),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: darkText,
            size: 20,
          ),
        ),
        title: const Text(
          'Appointment Details',
          style: TextStyle(
            color: darkText,
            fontWeight:
            FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final result =
              await context
                  .push<Appointment>(
                '/appointments/edit',
                extra: appointment,
              );

              if (result != null &&
                  context.mounted) {
                context.pop(result);
              }
            },
            child: const Text(
              'Edit',
              style: TextStyle(
                color: medNovaPurple,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding:
        const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient:
                const LinearGradient(
                  colors: [
                    Color(0xFF7D52E8),
                    Color(0xFF6C3CE9),
                  ],
                  begin:
                  Alignment.topLeft,
                  end: Alignment
                      .bottomRight,
                ),
                borderRadius:
                BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration:
                    BoxDecoration(
                      color: Colors.white
                          .withOpacity(0.18),
                      borderRadius:
                      BorderRadius
                          .circular(14),
                    ),
                    child: const Icon(
                      Icons
                          .calendar_month_rounded,
                      color:
                      Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  Text(
                    appointment.title,
                    style:
                    const TextStyle(
                      color:
                      Colors.white,
                      fontSize: 21,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 6,
                  ),
                  Text(
                    appointment.hospital,
                    style: TextStyle(
                      color: Colors.white
                          .withOpacity(
                        0.85,
                      ),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(
                    height: 18,
                  ),
                  Container(
                    padding:
                    const EdgeInsets
                        .symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration:
                    BoxDecoration(
                      color: Colors.white
                          .withOpacity(
                        0.18,
                      ),
                      borderRadius:
                      BorderRadius
                          .circular(20),
                    ),
                    child: Text(
                      appointment.upcoming
                          ? 'Upcoming'
                          : 'Completed',
                      style:
                      const TextStyle(
                        color:
                        Colors.white,
                        fontSize: 12,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.all(20),
              decoration:
              BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons
                        .calendar_today_outlined,
                    title: 'Date',
                    value:
                    appointment.date,
                  ),
                  const Divider(
                    height: 28,
                  ),
                  _InfoRow(
                    icon:
                    Icons.access_time,
                    title: 'Time',
                    value:
                    appointment.time,
                  ),
                  const Divider(
                    height: 28,
                  ),
                  _InfoRow(
                    icon:
                    Icons.person_outline,
                    title: 'Doctor',
                    value:
                    appointment.doctor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.all(18),
              decoration:
              BoxDecoration(
                color: lightPurple,
                borderRadius:
                BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons
                        .notifications_none_rounded,
                    color:
                    medNovaPurple,
                    size: 26,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You will receive a reminder before your appointment.',
                      style:
                      TextStyle(
                        color: darkText,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// INFO ROW
// ================================================================

class _InfoRow
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration:
          BoxDecoration(
            color: lightPurple,
            borderRadius:
            BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: medNovaPurple,
            size: 21,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                const TextStyle(
                  color: greyText,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style:
                const TextStyle(
                  color: darkText,
                  fontSize: 15,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}