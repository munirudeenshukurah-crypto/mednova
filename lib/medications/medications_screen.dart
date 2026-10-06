import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mednova/services/notification_service.dart';
import 'package:mednova/services/offline_database.dart';

const Color medNovaPurple = Color(0xFF6C3CE9);
const Color lightPurple = Color(0xFFF3EEFF);
const Color darkText = Color(0xFF29263A);
const Color greyText = Color(0xFF777383);

// =============================================================
// MEDICATION MODEL
// =============================================================

class Medication {
  final String? id;
  final String name;
  final String dosage;
  final String instruction;
  final List<String> times;
  final int takenIndex;
  final bool reminderEnabled;

  final DateTime? startDate;
  final int? durationDays;
  final DateTime? endDate;

  Medication({
    this.id,
    required this.name,
    required this.dosage,
    required this.instruction,
    required this.times,
    required this.takenIndex,
    required this.reminderEnabled,
    this.startDate,
    this.durationDays,
    this.endDate,
  });

  factory Medication.fromMap(Map<String, dynamic> map) {
    DateTime? parsedStartDate;
    DateTime? parsedEndDate;

    if (map['start_date'] != null) {
      parsedStartDate = DateTime.tryParse(
        map['start_date'].toString(),
      );
    }

    if (map['end_date'] != null) {
      parsedEndDate = DateTime.tryParse(
        map['end_date'].toString(),
      );
    }

    List<String> medicationTimes = [];

    final dynamic rawTimes = map['times'];

    if (rawTimes is List) {
      medicationTimes = rawTimes
          .map((item) => item.toString())
          .toList();
    } else if (rawTimes != null) {
      final String timesString = rawTimes.toString().trim();
      if (timesString.startsWith('[') && timesString.endsWith(']')) {
        final String inner = timesString.substring(1, timesString.length - 1).trim();
        if (inner.isNotEmpty) {
          medicationTimes = inner
              .split(',')
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList();
        }
      }
    }

    final dynamic rawTakenIndex = map['taken_index'];
    final int parsedTakenIndex = rawTakenIndex is int
        ? rawTakenIndex
        : int.tryParse(rawTakenIndex?.toString() ?? '') ?? -1;

    final dynamic rawReminder = map['reminder_enabled'];
    final bool parsedReminderEnabled = rawReminder == null
        ? true
        : rawReminder == true ||
        rawReminder == 1 ||
        rawReminder.toString().toLowerCase() == 'true';

    return Medication(
      id: map['id']?.toString(),
      name: map['name']?.toString() ?? '',
      dosage: map['dosage']?.toString() ?? '',
      instruction:
      map['instruction']?.toString() ?? 'As prescribed',
      times: medicationTimes,
      takenIndex: parsedTakenIndex,
      reminderEnabled: parsedReminderEnabled,
      startDate: parsedStartDate,
      durationDays: map['duration_days'] is int
          ? map['duration_days'] as int
          : int.tryParse(
        map['duration_days']?.toString() ?? '',
      ),
      endDate: parsedEndDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dosage': dosage,
      'instruction': instruction,
      'times': times,
      'taken_index': takenIndex,
      'reminder_enabled': reminderEnabled,
      'start_date': startDate == null
          ? null
          : _dateToString(startDate!),
      'duration_days': durationDays,
      'end_date': endDate == null
          ? null
          : _dateToString(endDate!),
    };
  }
}


// =============================================================
// MEDICATION DOSE MODEL
// =============================================================

class MedicationDose {
  final String id;
  final String medicationId;
  final DateTime scheduledDate;
  final String scheduledTime;
  final String status;
  final DateTime? takenAt;

  MedicationDose({
    required this.id,
    required this.medicationId,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.status,
    this.takenAt,
  });

  factory MedicationDose.fromMap(
      Map<String, dynamic> map,
      ) {
    return MedicationDose(
      id: map['id'].toString(),
      medicationId:
      map['medication_id'].toString(),
      scheduledDate: DateTime.parse(
        map['scheduled_date'].toString(),
      ),
      scheduledTime:
      map['scheduled_time']?.toString() ?? '',
      status:
      map['status']?.toString() ?? 'pending',
      takenAt: map['taken_at'] == null
          ? null
          : DateTime.tryParse(
        map['taken_at'].toString(),
      ),
    );
  }
}


// =============================================================
// DATE HELPERS
// =============================================================

String _dateToString(DateTime date) {
  final String month =
  date.month.toString().padLeft(2, '0');

  final String day =
  date.day.toString().padLeft(2, '0');

  return '${date.year}-$month-$day';
}

DateTime _dateOnly(DateTime date) {
  return DateTime(
    date.year,
    date.month,
    date.day,
  );
}


// =============================================================
// MEDICATIONS SCREEN
// =============================================================

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() =>
      _MedicationsScreenState();
}

class _MedicationsScreenState
    extends State<MedicationsScreen> {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  int selectedTab = 0;

  List<Medication> medications = [];

  List<MedicationDose> todayDoses = [];

  bool isLoading = true;
  bool isSaving = false;

  String? get currentUserId =>
      _supabase.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  // =========================================================
  // LOAD MEDICATIONS
  // =========================================================

  Future<void> _loadMedications() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await _supabase
          .from('medications')
          .select()
          .eq('user_id', user.id)
          .order(
        'created_at',
        ascending: false,
      );

      final remoteRows = (response as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      for (final row in remoteRows) {
        await OfflineDatabase.instance.saveMedication({
          ...row,
          'user_id': user.id,
        });
      }

      final loadedMedications = remoteRows
          .map(Medication.fromMap)
          .toList();

      if (!mounted) return;

      setState(() {
        medications = loadedMedications;
        isLoading = false;
      });

      await _prepareTodayDoses();
    } catch (_) {
      try {
        final localRows = await OfflineDatabase.instance
            .getMedications(user.id);

        final loadedMedications = localRows
            .map((item) => Medication.fromMap(
          Map<String, dynamic>.from(item),
        ))
            .toList();

        if (!mounted) return;

        setState(() {
          medications = loadedMedications;
          isLoading = false;
        });

        await _loadTodayDoses();
      } catch (_) {
        if (!mounted) return;

        setState(() {
          isLoading = false;
        });

        _showMessage(
          'Unable to load your medications.',
        );
      }
    }
  }

  // =========================================================
  // PREPARE TODAY'S DOSES
  // =========================================================

  Future<void> _prepareTodayDoses() async {
    final userId = currentUserId;

    if (userId == null) return;

    final DateTime today = _dateOnly(
      DateTime.now(),
    );

    for (final medication in medications) {
      if (medication.id == null) continue;

      final DateTime? startDate =
      medication.startDate == null
          ? null
          : _dateOnly(medication.startDate!);

      final DateTime? endDate =
      medication.endDate == null
          ? null
          : _dateOnly(medication.endDate!);

      // Do not create doses before treatment begins.
      if (startDate != null &&
          today.isBefore(startDate)) {
        continue;
      }

      // Do not create doses after treatment ends.
      if (endDate != null &&
          today.isAfter(endDate)) {
        continue;
      }

      for (final time in medication.times) {
        try {
          await _supabase
              .from('medication_doses')
              .upsert(
            {
              'medication_id':
              medication.id,
              'user_id': userId,
              'scheduled_date':
              _dateToString(today),
              'scheduled_time': time,
              'status': 'pending',
            },
            onConflict:
            'medication_id,scheduled_date,scheduled_time',
            ignoreDuplicates: true,
          );
        } catch (_) {
          // Keep the medication screen working
          // even if one dose fails to create.
        }
      }
    }

    await _loadTodayDoses();
  }

  // =========================================================
  // LOAD TODAY'S DOSES
  // =========================================================

  Future<void> _loadTodayDoses() async {
    final userId = currentUserId;

    if (userId == null) return;

    final DateTime today = _dateOnly(
      DateTime.now(),
    );

    try {
      final response = await _supabase
          .from('medication_doses')
          .select()
          .eq('user_id', userId)
          .eq(
        'scheduled_date',
        _dateToString(today),
      )
          .order(
        'scheduled_time',
        ascending: true,
      );

      final remoteRows = (response as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      for (final row in remoteRows) {
        await OfflineDatabase.instance.saveMedicationDose({
          ...row,
          'user_id': userId,
        });
      }

      final loadedDoses = remoteRows
          .map(MedicationDose.fromMap)
          .toList();

      if (!mounted) return;

      setState(() {
        todayDoses = loadedDoses;
      });

      await _markPastDosesAsMissed();
    } catch (_) {
      try {
        final localRows = await OfflineDatabase.instance
            .getMedicationDoses(userId);

        final todayString = _dateToString(today);

        final loadedDoses = localRows
            .where((item) =>
        item['scheduled_date']?.toString() == todayString)
            .map((item) => MedicationDose.fromMap(
          Map<String, dynamic>.from(item),
        ))
            .toList();

        if (!mounted) return;

        setState(() {
          todayDoses = loadedDoses;
        });
      } catch (_) {
        // No local dose cache is available yet.
      }
    }
  }

  // =========================================================
  // MARK PAST DOSES AS MISSED
  // =========================================================

  Future<void> _markPastDosesAsMissed() async {
    final now = DateTime.now();

    for (final dose in todayDoses) {
      if (dose.status != 'pending') {
        continue;
      }

      final TimeOfDay? scheduledTime =
      _parseTime(dose.scheduledTime);

      if (scheduledTime == null) {
        continue;
      }

      final DateTime scheduledDateTime =
      DateTime(
        now.year,
        now.month,
        now.day,
        scheduledTime.hour,
        scheduledTime.minute,
      );

      if (now.isAfter(scheduledDateTime)) {
        try {
          await _supabase
              .from('medication_doses')
              .update({
            'status': 'missed',
          }).eq('id', dose.id);
        } catch (_) {}
      }
    }

    await _reloadDosesSilently();
  }

  // =========================================================
  // SILENT DOSE RELOAD
  // =========================================================

  Future<void> _reloadDosesSilently() async {
    final userId = currentUserId;

    if (userId == null) return;

    final DateTime today = _dateOnly(
      DateTime.now(),
    );

    try {
      final response = await _supabase
          .from('medication_doses')
          .select()
          .eq('user_id', userId)
          .eq(
        'scheduled_date',
        _dateToString(today),
      )
          .order(
        'scheduled_time',
        ascending: true,
      );

      final loadedDoses =
      (response as List)
          .map(
            (item) => MedicationDose.fromMap(
          Map<String, dynamic>.from(item),
        ),
      )
          .toList();

      if (!mounted) return;

      setState(() {
        todayDoses = loadedDoses;
      });
    } catch (_) {}
  }

  // =========================================================
  // MARK DOSE AS TAKEN
  // =========================================================

  Future<void> _markDoseAsTaken(
      MedicationDose dose,
      ) async {
    try {
      await _supabase
          .from('medication_doses')
          .update({
        'status': 'taken',
        'taken_at':
        DateTime.now().toIso8601String(),
      }).eq('id', dose.id);

      await _reloadDosesSilently();

      if (!mounted) return;

      _showMessage(
        'Medication marked as taken.',
      );
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Unable to update medication status.',
      );
    }
  }

  // =========================================================
  // UNDO TAKEN
  // =========================================================

  Future<void> _undoDose(
      MedicationDose dose,
      ) async {
    try {
      await _supabase
          .from('medication_doses')
          .update({
        'status': 'pending',
        'taken_at': null,
      }).eq('id', dose.id);

      await _reloadDosesSilently();

      if (!mounted) return;

      _showMessage(
        'Medication changed back to pending.',
      );
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Unable to update medication status.',
      );
    }
  }

  // =========================================================
  // ADD MEDICATION
  // =========================================================

  Future<void> _addMedication() async {
    final result =
    await Navigator.push<Medication>(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const AddMedicationScreen(),
      ),
    );

    if (result == null) return;

    await _insertMedication(result);
  }

  // =========================================================
  // INSERT MEDICATION
  // =========================================================

  Future<void> _insertMedication(
      Medication medication,
      ) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    try {
      setState(() {
        isSaving = true;
      });

      final response = await _supabase
          .from('medications')
          .insert({
        ...medication.toMap(),
        'user_id': user.id,
      })
          .select()
          .single();

      final savedMedication = Medication.fromMap(
        Map<String, dynamic>.from(response),
      );

      // Schedule phone notifications only after the medication
      // has been successfully saved and has a database ID.
      await _scheduleMedicationNotifications(
        savedMedication,
      );

      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      _showMessage(
        'Medication added successfully.',
      );

      await _loadMedications();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      _showMessage(
        'Unable to save medication. Please try again.',
      );
    }
  }

  // =========================================================
  // EDIT MEDICATION
  // =========================================================

  Future<void> _editMedication(
      Medication medication,
      int index,
      ) async {
    final result =
    await Navigator.push<Medication>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddMedicationScreen(
              medication: medication,
            ),
      ),
    );

    if (result == null) return;

    await _updateMedication(
      result,
      index,
    );
  }

  // =========================================================
  // UPDATE MEDICATION
  // =========================================================

  Future<void> _updateMedication(
      Medication medication,
      int index,
      ) async {
    if (medication.id == null) {
      return;
    }

    final Medication? oldMedication =
    index >= 0 && index < medications.length
        ? medications[index]
        : null;

    try {
      setState(() {
        isSaving = true;
      });

      await _supabase
          .from('medications')
          .update(
        medication.toMap(),
      )
          .eq('id', medication.id!);

      // Remove the previous schedule first. This is important when
      // the user changes the time, treatment dates, or reminder toggle.
      if (oldMedication != null) {
        await _cancelMedicationNotifications(
          oldMedication,
        );
      }

      // Schedule the new medication times/dates.
      await _scheduleMedicationNotifications(
        medication,
      );

      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      _showMessage(
        'Medication updated successfully.',
      );

      await _loadMedications();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      _showMessage(
        'Unable to update medication.',
      );
    }
  }

  // =========================================================
  // DELETE MEDICATION
  // =========================================================

  Future<void> _deleteMedication(
      Medication medication,
      int index,
      ) async {
    final bool? confirmed =
    await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete Medication',
            style: TextStyle(
              color: darkText,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete ${medication.name}?',
            style: const TextStyle(
              color: greyText,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(18),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: greyText,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                Colors.red,
                foregroundColor:
                Colors.white,
                elevation: 0,
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(10),
                ),
              ),
              child:
              const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      if (medication.id != null) {
        await _supabase
            .from('medications')
            .delete()
            .eq(
          'id',
          medication.id!,
        );

        // Delete all future phone notifications belonging to this
        // medication as well.
        await _cancelMedicationNotifications(
          medication,
        );
      }

      if (!mounted) return;

      _showMessage(
        '${medication.name} deleted successfully.',
      );

      await _loadMedications();
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Unable to delete medication.',
      );
    }
  }

  // =========================================================
  // MEDICATION NOTIFICATION HELPERS
  // =========================================================

  /// Creates a stable notification ID from the medication ID, date,
  /// and time. Dart's String.hashCode is intentionally not used because
  /// it is not guaranteed to stay the same between app launches.
  int _medicationNotificationId(
      String medicationId,
      DateTime date,
      String time,
      ) {
    final String value =
        'medication|$medicationId|${_dateToString(date)}|$time';

    int hash = 2166136261;

    for (final int codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0x7fffffff;
    }

    // Keep the ID positive and inside Android's safe integer range.
    return hash == 0 ? 1 : hash;
  }

  DateTime? _buildMedicationDateTime(
      DateTime date,
      String time,
      ) {
    final TimeOfDay? parsedTime = _parseTime(time);

    if (parsedTime == null) {
      return null;
    }

    return DateTime(
      date.year,
      date.month,
      date.day,
      parsedTime.hour,
      parsedTime.minute,
    );
  }

  DateTime _notificationStartDate(
      Medication medication,
      ) {
    return _dateOnly(
      medication.startDate ?? DateTime.now(),
    );
  }

  DateTime _notificationEndDate(
      Medication medication,
      ) {
    final DateTime start =
    _notificationStartDate(medication);

    return _dateOnly(
      medication.endDate ??
          (medication.durationDays != null &&
              medication.durationDays! > 0
              ? start.add(
            Duration(
              days: medication.durationDays! - 1,
            ),
          )
              : start),
    );
  }

  /// Schedule one notification for every medication time on every
  /// treatment day. For example, 3 times daily for 7 days creates
  /// 21 scheduled phone notifications.
  Future<void> _scheduleMedicationNotifications(
      Medication medication,
      ) async {
    if (!medication.reminderEnabled ||
        medication.id == null ||
        medication.times.isEmpty) {
      return;
    }

    final DateTime start =
    _notificationStartDate(medication);
    final DateTime end =
    _notificationEndDate(medication);

    if (end.isBefore(start)) {
      return;
    }

    DateTime currentDate = start;

    while (!currentDate.isAfter(end)) {
      for (final String time in medication.times) {
        final DateTime? dateTime =
        _buildMedicationDateTime(
          currentDate,
          time,
        );

        if (dateTime == null) {
          continue;
        }

        final int notificationId =
        _medicationNotificationId(
          medication.id!,
          currentDate,
          time,
        );

        try {
          await NotificationService.instance
              .scheduleReminder(
            id: notificationId,
            title: 'Medication Reminder',
            body: '${medication.name} • ${medication.dosage}',
            dateTime: dateTime,
          );
        } catch (_) {
          // The medication is already saved in Supabase. A notification
          // failure should not make the medication disappear from the UI.
        }
      }

      currentDate = currentDate.add(
        const Duration(days: 1),
      );
    }
  }

  /// Cancel all notifications belonging to one medication.
  /// The same deterministic IDs are used when scheduling and cancelling.
  Future<void> _cancelMedicationNotifications(
      Medication medication,
      ) async {
    if (medication.id == null ||
        medication.times.isEmpty) {
      return;
    }

    final DateTime start =
    _notificationStartDate(medication);
    final DateTime end =
    _notificationEndDate(medication);

    if (end.isBefore(start)) {
      return;
    }

    DateTime currentDate = start;

    while (!currentDate.isAfter(end)) {
      for (final String time in medication.times) {
        final int notificationId =
        _medicationNotificationId(
          medication.id!,
          currentDate,
          time,
        );

        try {
          await NotificationService.instance
              .cancelReminder(notificationId);
        } catch (_) {}
      }

      currentDate = currentDate.add(
        const Duration(days: 1),
      );
    }
  }

  // =========================================================
  // MESSAGE
  // =========================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
        SnackBarBehavior.floating,
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: darkText,
            size: 20,
          ),
          onPressed: () =>
              Navigator.pop(context),
        ),

        title: const Text(
          'Medications',
          style: TextStyle(
            color: darkText,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          Padding(
            padding:
            const EdgeInsets.only(
              right: 16,
            ),
            child: TextButton.icon(
              onPressed: isSaving
                  ? null
                  : _addMedication,
              icon: const Icon(
                Icons.add,
                color: medNovaPurple,
                size: 20,
              ),
              label: const Text(
                'Add',
                style: TextStyle(
                  color: medNovaPurple,
                  fontSize: 15,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          const SizedBox(height: 10),

          // =================================================
          // TABS
          // =================================================

          Padding(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 20,
            ),
            child: Container(
              height: 48,
              padding:
              const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color:
                const Color(0xFFF5F3F8),
                borderRadius:
                BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _buildTab(
                    title:
                    'All Medications',
                    index: 0,
                  ),
                  _buildTab(
                    title:
                    'Taken / Missed',
                    index: 1,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: isLoading
                ? const Center(
              child:
              CircularProgressIndicator(
                color:
                medNovaPurple,
              ),
            )
                : RefreshIndicator(
              color: medNovaPurple,
              onRefresh:
              _loadMedications,
              child:
              selectedTab == 0
                  ? _buildAllMedications()
                  : _buildTakenMissed(),
            ),
          ),
        ],
      ),

      // =======================================================
      // BOTTOM NAVIGATION
      // =======================================================

      bottomNavigationBar:
      _buildBottomNavigationBar(),
    );
  }

  // =========================================================
  // ALL MEDICATIONS
  // =========================================================

  Widget _buildAllMedications() {
    return ListView(
      physics:
      const AlwaysScrollableScrollPhysics(),
      padding:
      const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      children: [
        if (medications.isEmpty)
          _buildEmptyState()
        else
          ...medications
              .asMap()
              .entries
              .map(
                (entry) {
              return _buildMedicationCard(
                entry.value,
                entry.key,
              );
            },
          ),

        const SizedBox(height: 10),

        if (medications.isNotEmpty)
          _buildNextReminder(),

        const SizedBox(height: 30),
      ],
    );
  }

  // =========================================================
  // TAKEN / MISSED
  // =========================================================

  Widget _buildTakenMissed() {
    final List<MedicationDose>
    relevantDoses = todayDoses;

    return ListView(
      physics:
      const AlwaysScrollableScrollPhysics(),
      padding:
      const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      children: [
        _buildTodayHeader(),

        const SizedBox(height: 14),

        if (relevantDoses.isEmpty)
          _buildNoDosesState()
        else
          ...relevantDoses.map(
                (dose) {
              return _buildDoseCard(dose);
            },
          ),

        const SizedBox(height: 30),
      ],
    );
  }

  // =========================================================
  // TODAY HEADER
  // =========================================================

  Widget _buildTodayHeader() {
    final DateTime today =
    DateTime.now();

    return Container(
      padding:
      const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightPurple,
        borderRadius:
        BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.calendar_today_outlined,
              color: medNovaPurple,
              size: 22,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today',
                  style: TextStyle(
                    color: darkText,
                    fontSize: 15,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatDate(today),
                  style: const TextStyle(
                    color: greyText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          Text(
            '${todayDoses.length} dose${todayDoses.length == 1 ? '' : 's'}',
            style: const TextStyle(
              color: medNovaPurple,
              fontSize: 12,
              fontWeight:
              FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // DOSE CARD
  // =========================================================

  Widget _buildDoseCard(
      MedicationDose dose,
      ) {
    Medication? medication;

    for (final item in medications) {
      if (item.id == dose.medicationId) {
        medication = item;
        break;
      }
    }

    if (medication == null) {
      return const SizedBox.shrink();
    }

    final bool isTaken =
        dose.status == 'taken';

    final bool isMissed =
        dose.status == 'missed';

    final bool isPending =
        dose.status == 'pending';

    Color statusColor = greyText;
    Color statusBackground =
    const Color(0xFFF3F2F5);
    IconData statusIcon =
        Icons.access_time;

    if (isTaken) {
      statusColor =
      const Color(0xFF38A169);
      statusBackground =
      const Color(0xFFE8F7EF);
      statusIcon =
          Icons.check_circle;
    }

    if (isMissed) {
      statusColor =
      const Color(0xFFE53E3E);
      statusBackground =
      const Color(0xFFFFEEEE);
      statusIcon =
          Icons.cancel_outlined;
    }

    return Container(
      margin:
      const EdgeInsets.only(
        bottom: 14,
      ),
      padding:
      const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color:
          const Color(0xFFEDEAF2),
        ),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(
              0.04,
            ),
            blurRadius: 10,
            offset:
            const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration:
                BoxDecoration(
                  color: lightPurple,
                  borderRadius:
                  BorderRadius.circular(
                    13,
                  ),
                ),
                child: const Icon(
                  Icons
                      .medication_outlined,
                  color:
                  medNovaPurple,
                  size: 25,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      medication.name,
                      style:
                      const TextStyle(
                        color: darkText,
                        fontSize: 16,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      '${medication.dosage} • ${dose.scheduledTime}',
                      style:
                      const TextStyle(
                        color: greyText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration:
                BoxDecoration(
                  color:
                  statusBackground,
                  borderRadius:
                  BorderRadius.circular(
                    20,
                  ),
                ),
                child: Row(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [
                    Icon(
                      statusIcon,
                      size: 13,
                      color:
                      statusColor,
                    ),
                    const SizedBox(
                      width: 4,
                    ),
                    Text(
                      isTaken
                          ? 'Taken'
                          : isMissed
                          ? 'Missed'
                          : 'Pending',
                      style:
                      TextStyle(
                        color:
                        statusColor,
                        fontSize: 11,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (isPending) ...[
            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () =>
                    _markDoseAsTaken(
                      dose,
                    ),
                style:
                ElevatedButton.styleFrom(
                  backgroundColor:
                  medNovaPurple,
                  foregroundColor:
                  Colors.white,
                  elevation: 0,
                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(
                      12,
                    ),
                  ),
                ),
                child: const Text(
                  'Mark as Taken',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],

          if (isTaken) ...[
            const SizedBox(height: 10),

            Align(
              alignment:
              Alignment.centerRight,
              child: TextButton(
                onPressed: () =>
                    _undoDose(dose),
                child: const Text(
                  'Undo',
                  style: TextStyle(
                    color:
                    medNovaPurple,
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================
  // MEDICATION CARD
  // =========================================================

  Widget _buildMedicationCard(
      Medication medication,
      int index,
      ) {
    return Container(
      margin:
      const EdgeInsets.only(
        bottom: 14,
      ),
      padding:
      const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color:
          const Color(0xFFEDEAF2),
        ),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(
              0.04,
            ),
            blurRadius: 10,
            offset:
            const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration:
                BoxDecoration(
                  color: lightPurple,
                  borderRadius:
                  BorderRadius.circular(
                    14,
                  ),
                ),
                child: const Icon(
                  Icons
                      .medication_outlined,
                  color:
                  medNovaPurple,
                  size: 26,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      medication.name,
                      style:
                      const TextStyle(
                        color: darkText,
                        fontSize: 17,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      medication.dosage,
                      style:
                      const TextStyle(
                        color: greyText,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      medication.instruction,
                      style:
                      const TextStyle(
                        color: greyText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: greyText,
                ),
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(
                    14,
                  ),
                ),
                onSelected: (value) {
                  if (value == 'edit') {
                    _editMedication(
                      medication,
                      index,
                    );
                  }

                  if (value == 'delete') {
                    _deleteMedication(
                      medication,
                      index,
                    );
                  }
                },
                itemBuilder:
                    (context) => [
                  const PopupMenuItem<
                      String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(
                          Icons
                              .edit_outlined,
                          color:
                          medNovaPurple,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<
                      String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons
                              .delete_outline,
                          color: Colors.red,
                          size: 20,
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

          const SizedBox(height: 16),

          // =================================================
          // REMINDER TIMES
          // =================================================

          Align(
            alignment:
            Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: medication.times
                  .asMap()
                  .entries
                  .map(
                    (entry) {
                  final int timeIndex =
                      entry.key;

                  final String time =
                      entry.value;

                  final bool isTaken =
                      medication
                          .takenIndex ==
                          timeIndex;

                  return _buildTimeBadge(
                    time,
                    isTaken,
                  );
                },
              ).toList(),
            ),
          ),

          // =================================================
          // TREATMENT PERIOD
          // =================================================

          if (medication.startDate !=
              null ||
              medication.durationDays !=
                  null ||
              medication.endDate !=
                  null) ...[
            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding:
              const EdgeInsets
                  .symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color:
                const Color(0xFFF8F7FA),
                borderRadius:
                BorderRadius.circular(
                  12,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons
                        .calendar_month_outlined,
                    color:
                    medNovaPurple,
                    size: 18,
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      _buildTreatmentPeriodText(
                        medication,
                      ),
                      style:
                      const TextStyle(
                        color: greyText,
                        fontSize: 11,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================
  // TIME BADGE
  // =========================================================

  Widget _buildTimeBadge(
      String time,
      bool isTaken,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: isTaken
            ? const Color(0xFFE8F7EF)
            : const Color(0xFFF3F2F5),
        borderRadius:
        BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Icon(
            isTaken
                ? Icons.check_circle
                : Icons.access_time,
            size: 13,
            color: isTaken
                ? const Color(0xFF38A169)
                : greyText,
          ),

          const SizedBox(width: 5),

          Text(
            time,
            style: TextStyle(
              color: isTaken
                  ? const Color(
                0xFF38A169,
              )
                  : greyText,
              fontSize: 11,
              fontWeight:
              FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // TREATMENT PERIOD TEXT
  // =========================================================

  String _buildTreatmentPeriodText(
      Medication medication,
      ) {
    final String duration =
    medication.durationDays != null
        ? '${medication.durationDays} day${medication.durationDays == 1 ? '' : 's'}'
        : '';

    final String start =
    medication.startDate != null
        ? _shortDate(
      medication.startDate!,
    )
        : '';

    final String end =
    medication.endDate != null
        ? _shortDate(
      medication.endDate!,
    )
        : '';

    if (start.isNotEmpty &&
        end.isNotEmpty &&
        duration.isNotEmpty) {
      return '$duration • $start - $end';
    }

    if (start.isNotEmpty &&
        end.isNotEmpty) {
      return '$start - $end';
    }

    if (duration.isNotEmpty) {
      return duration;
    }

    return 'Treatment period not set';
  }

  // =========================================================
  // EMPTY STATE
  // =========================================================

  Widget _buildEmptyState() {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 50,
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration:
            BoxDecoration(
              color: lightPurple,
              borderRadius:
              BorderRadius.circular(
                20,
              ),
            ),
            child: const Icon(
              Icons
                  .medication_outlined,
              color:
              medNovaPurple,
              size: 35,
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'No medications found',
            style: TextStyle(
              color: darkText,
              fontSize: 17,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Add a medication to start tracking it.',
            style: TextStyle(
              color: greyText,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // NO DOSES STATE
  // =========================================================

  Widget _buildNoDosesState() {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 50,
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration:
            BoxDecoration(
              color: lightPurple,
              borderRadius:
              BorderRadius.circular(
                20,
              ),
            ),
            child: const Icon(
              Icons
                  .check_circle_outline,
              color:
              medNovaPurple,
              size: 35,
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'No doses for today',
            style: TextStyle(
              color: darkText,
              fontSize: 17,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Your medication schedule is clear for today.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: greyText,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // NEXT REMINDER
  // =========================================================

  Widget _buildNextReminder() {
    Medication? nextMedication;
    String? nextTime;

    final now = DateTime.now();

    DateTime? nearestDateTime;

    for (final medication in medications) {
      if (medication.times.isEmpty) {
        continue;
      }

      for (final time in medication.times) {
        final parsed =
        _parseTime(time);

        if (parsed == null) continue;

        final dateTime = DateTime(
          now.year,
          now.month,
          now.day,
          parsed.hour,
          parsed.minute,
        );

        if (dateTime.isBefore(now)) {
          continue;
        }

        if (nearestDateTime == null ||
            dateTime.isBefore(
              nearestDateTime,
            )) {
          nearestDateTime =
              dateTime;
          nextMedication =
              medication;
          nextTime = time;
        }
      }
    }

    if (nextMedication == null) {
      nextMedication =
      medications.isNotEmpty
          ? medications.first
          : null;

      nextTime =
      nextMedication != null &&
          nextMedication.times.isNotEmpty
          ? nextMedication.times.first
          : null;
    }

    if (nextMedication == null ||
        nextTime == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding:
      const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: lightPurple,
        borderRadius:
        BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration:
            BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.circular(
                13,
              ),
            ),
            child: const Icon(
              Icons.notifications_none,
              color:
              medNovaPurple,
              size: 25,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                const Text(
                  'Next reminder',
                  style: TextStyle(
                    color: greyText,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '${nextMedication.name} ${nextMedication.dosage} at $nextTime',
                  style:
                  const TextStyle(
                    color: darkText,
                    fontSize: 13,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // BOTTOM NAVIGATION
  // =========================================================

  Widget _buildBottomNavigationBar() {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(
              0.06,
            ),
            blurRadius: 15,
            offset:
            const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment:
        MainAxisAlignment
            .spaceAround,
        children: [
          _buildBottomNavItem(
            icon: Icons.home_outlined,
            label: 'Home',
            onTap: () =>
                context.go('/home'),
          ),

          _buildBottomNavItem(
            icon:
            Icons.calendar_today_outlined,
            label: 'Calendar',
            onTap: () =>
                context.go('/appointments'),
          ),

          GestureDetector(
            onTap: _addMedication,
            child: Container(
              width: 54,
              height: 54,
              decoration:
              BoxDecoration(
                color:
                medNovaPurple,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: medNovaPurple
                        .withOpacity(
                      0.25,
                    ),
                    blurRadius: 12,
                    offset:
                    const Offset(
                      0,
                      5,
                    ),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),

          _buildBottomNavItem(
            icon:
            Icons.chat_bubble_outline,
            label: 'Messages',
            onTap: () =>
                context.go('/messages'),
          ),

          _buildBottomNavItem(
            icon:
            Icons.person_outline,
            label: 'Profile',
            onTap: () =>
                context.go('/profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior:
      HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: greyText,
              size: 23,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style:
              const TextStyle(
                color: greyText,
                fontSize: 10,
                fontWeight:
                FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // TAB
  // =========================================================

  Widget _buildTab({
    required String title,
    required int index,
  }) {
    final bool isSelected =
        selectedTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedTab = index;
          });

          if (index == 1) {
            _prepareTodayDoses();
          }
        },
        child: Container(
          decoration:
          BoxDecoration(
            color: isSelected
                ? medNovaPurple
                : Colors.transparent,
            borderRadius:
            BorderRadius.circular(
              11,
            ),
          ),
          alignment:
          Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : greyText,
              fontSize: 13,
              fontWeight:
              FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // DATE PICKER
  // =========================================================

  Future<void> _selectDate() async {
    // Reserved for future date-by-date
    // medication history.
  }

  // =========================================================
  // PARSE TIME
  // =========================================================

  TimeOfDay? _parseTime(
      String time,
      ) {
    try {
      final parts =
      time.trim().split(' ');

      if (parts.isEmpty) {
        return null;
      }

      final timeParts =
      parts[0].split(':');

      if (timeParts.length != 2) {
        return null;
      }

      int hour =
      int.parse(timeParts[0]);

      final int minute =
      int.parse(timeParts[1]);

      final String period =
      parts.length > 1
          ? parts[1].toUpperCase()
          : 'AM';

      if (period == 'PM' &&
          hour != 12) {
        hour += 12;
      }

      if (period == 'AM' &&
          hour == 12) {
        hour = 0;
      }

      return TimeOfDay(
        hour: hour,
        minute: minute,
      );
    } catch (_) {
      return null;
    }
  }

  // =========================================================
  // DATE FORMATTING
  // =========================================================

  String _formatDate(
      DateTime date,
      ) {
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

  String _shortDate(
      DateTime date,
      ) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[date.month - 1]} ${date.day}';
  }
}


// =============================================================
// ADD / EDIT MEDICATION SCREEN
// =============================================================

class AddMedicationScreen
    extends StatefulWidget {
  final Medication? medication;

  const AddMedicationScreen({
    super.key,
    this.medication,
  });

  @override
  State<AddMedicationScreen>
  createState() =>
      _AddMedicationScreenState();
}

class _AddMedicationScreenState
    extends State<AddMedicationScreen> {
  late final TextEditingController
  nameController;

  late final TextEditingController
  dosageController;

  late final TextEditingController
  instructionController;

  // =========================================================
  // FREQUENCY
  // =========================================================

  String frequency = 'Once daily';

  // We keep three possible time fields.
  // Only the number required by the
  // selected frequency will be shown.
  List<TimeOfDay> selectedTimes = [
    const TimeOfDay(
      hour: 8,
      minute: 0,
    ),
  ];

  // =========================================================
  // TREATMENT PERIOD
  // =========================================================

  DateTime selectedStartDate =
  DateTime.now();

  int selectedDuration = 7;

  bool reminderEnabled = true;

  bool get isEditing =>
      widget.medication != null;

  // =========================================================
  // INIT
  // =========================================================

  @override
  void initState() {
    super.initState();

    nameController =
        TextEditingController(
          text:
          widget.medication?.name ?? '',
        );

    dosageController =
        TextEditingController(
          text:
          widget.medication?.dosage ?? '',
        );

    instructionController =
        TextEditingController(
          text:
          widget.medication?.instruction ??
              '',
        );

    reminderEnabled =
        widget.medication
            ?.reminderEnabled ??
            true;

    // -------------------------------------------------------
    // EXISTING TIMES
    // -------------------------------------------------------

    if (widget.medication != null &&
        widget.medication!.times
            .isNotEmpty) {
      selectedTimes =
          widget.medication!.times
              .map(
                (time) =>
                _parseTime(time),
          )
              .whereType<
              TimeOfDay>()
              .toList();

      if (selectedTimes.isEmpty) {
        selectedTimes = [
          const TimeOfDay(
            hour: 8,
            minute: 0,
          ),
        ];
      }

      _setFrequencyFromTimes();
    }

    // -------------------------------------------------------
    // EXISTING START DATE
    // -------------------------------------------------------

    if (widget.medication
        ?.startDate !=
        null) {
      selectedStartDate =
          _dateOnly(
            widget.medication!
                .startDate!,
          );
    }

    // -------------------------------------------------------
    // EXISTING DURATION
    // -------------------------------------------------------

    if (widget.medication
        ?.durationDays !=
        null &&
        widget.medication!
            .durationDays! >
            0) {
      selectedDuration =
      widget.medication!
          .durationDays!;
    }
  }

  // =========================================================
  // SET FREQUENCY FROM EXISTING TIMES
  // =========================================================

  void _setFrequencyFromTimes() {
    switch (selectedTimes.length) {
      case 1:
        frequency =
        'Once daily';
        break;

      case 2:
        frequency =
        'Twice daily';
        break;

      default:
        frequency =
        'Three times daily';

        if (selectedTimes.length >
            3) {
          selectedTimes =
              selectedTimes
                  .take(3)
                  .toList();
        }

        break;
    }
  }

  // =========================================================
  // SELECT FREQUENCY
  // =========================================================

  void _selectFrequency(
      String value,
      ) {
    setState(() {
      frequency = value;

      final int requiredTimes =
      _frequencyCount(value);

      while (selectedTimes.length <
          requiredTimes) {
        selectedTimes.add(
          _defaultTimeForIndex(
            selectedTimes.length,
          ),
        );
      }

      if (selectedTimes.length >
          requiredTimes) {
        selectedTimes =
            selectedTimes
                .take(requiredTimes)
                .toList();
      }
    });
  }

  int _frequencyCount(
      String value,
      ) {
    if (value == 'Twice daily') {
      return 2;
    }

    if (value ==
        'Three times daily') {
      return 3;
    }

    return 1;
  }

  TimeOfDay _defaultTimeForIndex(
      int index,
      ) {
    if (index == 1) {
      return const TimeOfDay(
        hour: 14,
        minute: 0,
      );
    }

    if (index == 2) {
      return const TimeOfDay(
        hour: 20,
        minute: 0,
      );
    }

    return const TimeOfDay(
      hour: 8,
      minute: 0,
    );
  }

  // =========================================================
  // SELECT TIME
  // =========================================================

  Future<void> _selectTime(
      int index,
      ) async {
    final TimeOfDay? picked =
    await showTimePicker(
      context: context,
      initialTime:
      selectedTimes[index],
    );

    if (picked == null) {
      return;
    }

    setState(() {
      selectedTimes[index] =
          picked;
    });
  }

  // =========================================================
  // SELECT START DATE
  // =========================================================

  Future<void> _selectStartDate()
  async {
    final DateTime today =
    _dateOnly(
      DateTime.now(),
    );

    final DateTime? picked =
    await showDatePicker(
      context: context,
      initialDate:
      selectedStartDate,
      firstDate: today,
      lastDate: DateTime(
        today.year + 5,
      ),
      builder:
          (context, child) {
        return Theme(
          data: Theme.of(context)
              .copyWith(
            colorScheme:
            const ColorScheme.light(
              primary:
              medNovaPurple,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedStartDate =
            _dateOnly(picked);
      });
    }
  }

  // =========================================================
  // END DATE
  // =========================================================

  DateTime get calculatedEndDate {
    return _dateOnly(
      selectedStartDate.add(
        Duration(
          days:
          selectedDuration - 1,
        ),
      ),
    );
  }

  // =========================================================
  // SAVE MEDICATION
  // =========================================================

  void _saveMedication() {
    if (nameController.text
        .trim()
        .isEmpty ||
        dosageController.text
            .trim()
            .isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter the medication name and dosage.',
          ),
        ),
      );

      return;
    }

    final int requiredTimes =
    _frequencyCount(
      frequency,
    );

    if (selectedTimes.length !=
        requiredTimes) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Please set all medication times.',
          ),
        ),
      );

      return;
    }

    final Medication medication =
    Medication(
      id: widget.medication?.id,

      name:
      nameController.text.trim(),

      dosage:
      dosageController.text.trim(),

      instruction:
      instructionController
          .text
          .trim()
          .isEmpty
          ? 'As prescribed'
          : instructionController
          .text
          .trim(),

      times: selectedTimes
          .map(
            (time) =>
            _formatTime(time),
      )
          .toList(),

      takenIndex:
      widget.medication
          ?.takenIndex ??
          -1,

      reminderEnabled:
      reminderEnabled,

      startDate:
      _dateOnly(
        selectedStartDate,
      ),

      durationDays:
      selectedDuration,

      endDate:
      calculatedEndDate,
    );

    Navigator.pop(
      context,
      medication,
    );
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    nameController.dispose();
    dosageController.dispose();
    instructionController.dispose();

    super.dispose();
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      Colors.white,

      appBar: AppBar(
        backgroundColor:
        Colors.white,
        elevation: 0,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: darkText,
            size: 20,
          ),
          onPressed: () =>
              Navigator.pop(context),
        ),

        title: Text(
          isEditing
              ? 'Edit Medication'
              : 'Add Medication',
          style:
          const TextStyle(
            color: darkText,
            fontSize: 21,
            fontWeight:
            FontWeight.bold,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding:
        const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            // =================================================
            // MEDICATION NAME
            // =================================================

            _buildLabel(
              'Medication Name',
            ),

            _buildTextField(
              controller:
              nameController,
              hint:
              'e.g. Amoxicillin',
              icon: Icons
                  .medication_outlined,
            ),

            const SizedBox(height: 20),

            // =================================================
            // DOSAGE
            // =================================================

            _buildLabel('Dosage'),

            _buildTextField(
              controller:
              dosageController,
              hint: 'e.g. 500mg',
              icon: Icons
                  .medication_liquid_outlined,
            ),

            const SizedBox(height: 20),

            // =================================================
            // INSTRUCTIONS
            // =================================================

            _buildLabel(
              'Instructions',
            ),

            _buildTextField(
              controller:
              instructionController,
              hint:
              'e.g. After Food',
              icon:
              Icons.info_outline,
            ),

            const SizedBox(height: 24),

            // =================================================
            // FREQUENCY
            // =================================================

            _buildLabel(
              'How often?',
            ),

            Container(
              height: 56,
              padding:
              const EdgeInsets
                  .symmetric(
                horizontal: 16,
              ),
              decoration:
              BoxDecoration(
                color:
                const Color(
                  0xFFF8F7FA,
                ),
                borderRadius:
                BorderRadius.circular(
                  14,
                ),
                border: Border.all(
                  color:
                  const Color(
                    0xFFE5E1EA,
                  ),
                ),
              ),
              child:
              DropdownButtonHideUnderline(
                child:
                DropdownButton<String>(
                  value: frequency,
                  isExpanded: true,
                  icon:
                  const Icon(
                    Icons
                        .keyboard_arrow_down,
                    color:
                    greyText,
                  ),
                  items: const [
                    DropdownMenuItem<
                        String>(
                      value:
                      'Once daily',
                      child: Text(
                        'Once daily',
                      ),
                    ),
                    DropdownMenuItem<
                        String>(
                      value:
                      'Twice daily',
                      child: Text(
                        'Twice daily',
                      ),
                    ),
                    DropdownMenuItem<
                        String>(
                      value:
                      'Three times daily',
                      child: Text(
                        'Three times daily',
                      ),
                    ),
                  ],
                  onChanged:
                      (value) {
                    if (value !=
                        null) {
                      _selectFrequency(
                        value,
                      );
                    }
                  },
                  style:
                  const TextStyle(
                    color: darkText,
                    fontSize: 15,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // =================================================
            // REMINDER TIMES
            // =================================================

            _buildLabel(
              frequency ==
                  'Once daily'
                  ? 'Reminder Time'
                  : 'Reminder Times',
            ),

            ...List.generate(
              selectedTimes.length,
                  (index) {
                return Padding(
                  padding:
                  const EdgeInsets
                      .only(
                    bottom: 12,
                  ),
                  child:
                  _buildTimeSelector(
                    index,
                  ),
                );
              },
            ),

            const SizedBox(height: 8),

            // =================================================
            // START DATE
            // =================================================

            _buildLabel(
              'Start Date',
            ),

            GestureDetector(
              onTap:
              _selectStartDate,
              child: Container(
                height: 56,
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal: 16,
                ),
                decoration:
                BoxDecoration(
                  color:
                  const Color(
                    0xFFF8F7FA,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    14,
                  ),
                  border: Border.all(
                    color:
                    const Color(
                      0xFFE5E1EA,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons
                          .calendar_today_outlined,
                      color:
                      medNovaPurple,
                    ),

                    const SizedBox(
                      width: 12,
                    ),

                    Text(
                      _formatDate(
                        selectedStartDate,
                      ),
                      style:
                      const TextStyle(
                        color: darkText,
                        fontSize: 15,
                      ),
                    ),

                    const Spacer(),

                    const Icon(
                      Icons
                          .keyboard_arrow_down,
                      color:
                      greyText,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // =================================================
            // DURATION
            // =================================================

            _buildLabel(
              'Treatment Duration',
            ),

            Container(
              height: 56,
              padding:
              const EdgeInsets
                  .symmetric(
                horizontal: 16,
              ),
              decoration:
              BoxDecoration(
                color:
                const Color(
                  0xFFF8F7FA,
                ),
                borderRadius:
                BorderRadius.circular(
                  14,
                ),
                border: Border.all(
                  color:
                  const Color(
                    0xFFE5E1EA,
                  ),
                ),
              ),
              child:
              DropdownButtonHideUnderline(
                child:
                DropdownButton<int>(
                  value:
                  selectedDuration,
                  isExpanded: true,
                  icon:
                  const Icon(
                    Icons
                        .keyboard_arrow_down,
                    color:
                    greyText,
                  ),
                  items: const [
                    DropdownMenuItem<
                        int>(
                      value: 3,
                      child:
                      Text('3 days'),
                    ),
                    DropdownMenuItem<
                        int>(
                      value: 5,
                      child:
                      Text('5 days'),
                    ),
                    DropdownMenuItem<
                        int>(
                      value: 7,
                      child:
                      Text('7 days'),
                    ),
                    DropdownMenuItem<
                        int>(
                      value: 10,
                      child:
                      Text('10 days'),
                    ),
                    DropdownMenuItem<
                        int>(
                      value: 14,
                      child:
                      Text('14 days'),
                    ),
                    DropdownMenuItem<
                        int>(
                      value: 21,
                      child:
                      Text('21 days'),
                    ),
                    DropdownMenuItem<
                        int>(
                      value: 30,
                      child:
                      Text('30 days'),
                    ),
                  ],
                  onChanged:
                      (value) {
                    if (value !=
                        null) {
                      setState(() {
                        selectedDuration =
                            value;
                      });
                    }
                  },
                  style:
                  const TextStyle(
                    color: darkText,
                    fontSize: 15,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // =================================================
            // END DATE PREVIEW
            // =================================================

            Container(
              width:
              double.infinity,
              padding:
              const EdgeInsets
                  .symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration:
              BoxDecoration(
                color: lightPurple,
                borderRadius:
                BorderRadius.circular(
                  14,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_available,
                    color:
                    medNovaPurple,
                    size: 20,
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        const Text(
                          'Treatment ends',
                          style:
                          TextStyle(
                            color:
                            greyText,
                            fontSize: 11,
                          ),
                        ),

                        const SizedBox(
                          height: 3,
                        ),

                        Text(
                          _formatDate(
                            calculatedEndDate,
                          ),
                          style:
                          const TextStyle(
                            color:
                            darkText,
                            fontSize: 13,
                            fontWeight:
                            FontWeight
                                .w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // =================================================
            // REMINDER SWITCH
            // =================================================

            Container(
              padding:
              const EdgeInsets
                  .symmetric(
                vertical: 5,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Text(
                          'Medication Reminder',
                          style:
                          TextStyle(
                            color:
                            darkText,
                            fontSize: 15,
                            fontWeight:
                            FontWeight
                                .w600,
                          ),
                        ),

                        SizedBox(
                          height: 4,
                        ),

                        Text(
                          'Receive a reminder when it is time.',
                          style:
                          TextStyle(
                            color:
                            greyText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Switch(
                    value:
                    reminderEnabled,
                    activeColor:
                    medNovaPurple,
                    onChanged:
                        (value) {
                      setState(() {
                        reminderEnabled =
                            value;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 35),

            // =================================================
            // SAVE BUTTON
            // =================================================

            SizedBox(
              width:
              double.infinity,
              height: 55,
              child:
              ElevatedButton(
                onPressed:
                _saveMedication,
                style:
                ElevatedButton.styleFrom(
                  backgroundColor:
                  medNovaPurple,
                  foregroundColor:
                  Colors.white,
                  elevation: 0,
                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius
                        .circular(
                      15,
                    ),
                  ),
                ),
                child: Text(
                  isEditing
                      ? 'Save Changes'
                      : 'Save Medication',
                  style:
                  const TextStyle(
                    fontSize: 15,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // TIME SELECTOR
  // =========================================================

  Widget _buildTimeSelector(
      int index,
      ) {
    return GestureDetector(
      onTap: () =>
          _selectTime(index),
      child: Container(
        height: 56,
        padding:
        const EdgeInsets.symmetric(
          horizontal: 16,
        ),
        decoration:
        BoxDecoration(
          color:
          const Color(0xFFF8F7FA),
          borderRadius:
          BorderRadius.circular(14),
          border: Border.all(
            color:
            const Color(0xFFE5E1EA),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.access_time,
              color:
              medNovaPurple,
            ),

            const SizedBox(
              width: 12,
            ),

            Text(
              selectedTimes[index]
                  .format(context),
              style:
              const TextStyle(
                color: darkText,
                fontSize: 15,
              ),
            ),

            const Spacer(),

            const Icon(
              Icons
                  .keyboard_arrow_down,
              color: greyText,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // LABEL
  // =========================================================

  Widget _buildLabel(
      String label,
      ) {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 8,
      ),
      child: Text(
        label,
        style:
        const TextStyle(
          color: darkText,
          fontSize: 14,
          fontWeight:
          FontWeight.w600,
        ),
      ),
    );
  }

  // =========================================================
  // TEXT FIELD
  // =========================================================

  Widget _buildTextField({
    required TextEditingController
    controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      decoration:
      InputDecoration(
        hintText: hint,
        hintStyle:
        const TextStyle(
          color:
          Color(0xFFA09BA8),
          fontSize: 14,
        ),

        prefixIcon: Icon(
          icon,
          color:
          medNovaPurple,
          size: 21,
        ),

        filled: true,

        fillColor:
        const Color(0xFFF8F7FA),

        border:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
            14,
          ),
          borderSide:
          const BorderSide(
            color:
            Color(0xFFE5E1EA),
          ),
        ),

        enabledBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
            14,
          ),
          borderSide:
          const BorderSide(
            color:
            Color(0xFFE5E1EA),
          ),
        ),

        focusedBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
            14,
          ),
          borderSide:
          const BorderSide(
            color:
            medNovaPurple,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // TIME PARSER
  // =========================================================

  TimeOfDay? _parseTime(
      String time,
      ) {
    try {
      final parts =
      time.trim().split(' ');

      final timeParts =
      parts[0].split(':');

      int hour =
      int.parse(timeParts[0]);

      final int minute =
      int.parse(timeParts[1]);

      final String period =
      parts.length > 1
          ? parts[1].toUpperCase()
          : 'AM';

      if (period == 'PM' &&
          hour != 12) {
        hour += 12;
      }

      if (period == 'AM' &&
          hour == 12) {
        hour = 0;
      }

      return TimeOfDay(
        hour: hour,
        minute: minute,
      );
    } catch (_) {
      return null;
    }
  }

  // =========================================================
  // FORMAT TIME
  // =========================================================

  String _formatTime(
      TimeOfDay time,
      ) {
    final int hour =
    time.hourOfPeriod == 0
        ? 12
        : time.hourOfPeriod;

    final String minute =
    time.minute
        .toString()
        .padLeft(2, '0');

    final String period =
    time.period == DayPeriod.am
        ? 'AM'
        : 'PM';

    return '$hour:$minute $period';
  }

  // =========================================================
  // FORMAT DATE
  // =========================================================

  String _formatDate(
      DateTime date,
      ) {
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

  // =========================================================
  // DATE ONLY
  // =========================================================

  DateTime _dateOnly(
      DateTime date,
      ) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }
}
