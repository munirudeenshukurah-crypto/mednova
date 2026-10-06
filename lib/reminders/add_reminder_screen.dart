import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'reminders_screen.dart';

class AddReminderScreen extends StatefulWidget {
  final Reminder? reminder;

  const AddReminderScreen({
    super.key,
    this.reminder,
  });

  bool get isEditing => reminder != null;

  @override
  State<AddReminderScreen> createState() =>
      _AddReminderScreenState();
}

class _AddReminderScreenState
    extends State<AddReminderScreen> {
  final Color primaryPurple =
  const Color(0xFF6C3CE9);

  final Color backgroundColor =
  const Color(0xFFF9F7FC);

  late final TextEditingController
  titleController;

  late final TextEditingController
  descriptionController;

  TimeOfDay selectedTime =
  const TimeOfDay(
    hour: 14,
    minute: 0,
  );

  DateTime selectedDate = DateTime.now();

  String selectedCategory = 'Medication';

  bool notificationEnabled = true;

  IconData selectedIcon =
      Icons.medication_outlined;

  Color selectedIconColor =
  const Color(0xFF6C3CE9);

  Color selectedIconBackground =
  const Color(0xFFEDE7FF);

  @override
  void initState() {
    super.initState();

    titleController =
        TextEditingController(
          text: widget.reminder?.title ?? '',
        );

    descriptionController =
        TextEditingController(
          text:
          widget.reminder?.description ?? '',
        );

    if (widget.reminder != null) {
      selectedTime =
          _parseTime(widget.reminder!.time);

      selectedDate =
          widget.reminder!.dateTime;

      selectedCategory =
          widget.reminder!.category;

      notificationEnabled =
          widget.reminder!.notificationEnabled;

      selectedIcon =
          widget.reminder!.icon;

      selectedIconColor =
          widget.reminder!.iconColor;

      selectedIconBackground =
          widget.reminder!.iconBackground;
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            context.pop();
          },
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: Color(0xFF222222),
          ),
        ),
        centerTitle: true,
        title: Text(
          widget.isEditing
              ? 'Edit Reminder'
              : 'Add Reminder',
          style: const TextStyle(
            color: Color(0xFF222222),
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          physics:
          const BouncingScrollPhysics(),
          padding:
          const EdgeInsets.fromLTRB(
            20,
            10,
            20,
            35,
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              _buildPageHeader(),

              const SizedBox(height: 25),

              _buildTitleField(),

              const SizedBox(height: 18),

              _buildDescriptionField(),

              const SizedBox(height: 22),

              _buildCategorySection(),

              const SizedBox(height: 22),

              _buildDateSection(),

              const SizedBox(height: 22),

              _buildTimeSection(),

              const SizedBox(height: 22),

              _buildNotificationSection(),

              const SizedBox(height: 30),

              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildPageHeader() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          widget.isEditing
              ? 'Update your reminder'
              : 'Create a reminder',
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w700,
            color: Color(0xFF202020),
          ),
        ),

        const SizedBox(height: 7),

        Text(
          widget.isEditing
              ? 'Make changes to your health reminder below.'
              : 'Set a reminder so you never miss an important health task.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TITLE
  // ============================================================

  Widget _buildTitleField() {
    return _buildInputContainer(
      child: TextField(
        controller: titleController,
        textInputAction:
        TextInputAction.next,
        decoration:
        const InputDecoration(
          border: InputBorder.none,
          hintText: 'Reminder title',
          prefixIcon: Icon(
            Icons.edit_outlined,
            color: Color(0xFF6C3CE9),
          ),
          contentPadding:
          EdgeInsets.symmetric(
            vertical: 16,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DESCRIPTION
  // ============================================================

  Widget _buildDescriptionField() {
    return _buildInputContainer(
      child: TextField(
        controller:
        descriptionController,
        maxLines: 3,
        textInputAction:
        TextInputAction.newline,
        decoration:
        const InputDecoration(
          border: InputBorder.none,
          hintText: 'Description',
          prefixIcon: Padding(
            padding:
            EdgeInsets.only(bottom: 38),
            child: Icon(
              Icons.notes_outlined,
              color: Color(0xFF6C3CE9),
            ),
          ),
          contentPadding:
          EdgeInsets.symmetric(
            vertical: 16,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INPUT CONTAINER
  // ============================================================

  Widget _buildInputContainer({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE9E4F1),
        ),
      ),
      child: child,
    );
  }

  // ============================================================
  // CATEGORY
  // ============================================================

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(
          'Reminder Type',
        ),

        const SizedBox(height: 12),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildCategoryChip(
              label: 'Medication',
              icon:
              Icons.medication_outlined,
              iconColor:
              const Color(0xFF6C3CE9),
              iconBackground:
              const Color(0xFFEDE7FF),
            ),

            _buildCategoryChip(
              label: 'Health Check',
              icon: Icons.favorite,
              iconColor:
              const Color(0xFFFF4D6D),
              iconBackground:
              const Color(0xFFFFE8EC),
            ),

            _buildCategoryChip(
              label: 'Appointment',
              icon:
              Icons.calendar_month_outlined,
              iconColor:
              const Color(0xFF6C3CE9),
              iconBackground:
              const Color(0xFFEDE7FF),
            ),

            _buildCategoryChip(
              label: 'Other',
              icon:
              Icons.notifications_none_rounded,
              iconColor:
              const Color(0xFF6C3CE9),
              iconBackground:
              const Color(0xFFEDE7FF),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
  }) {
    final bool selected =
        selectedCategory == label;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedCategory = label;
          selectedIcon = icon;
          selectedIconColor = iconColor;
          selectedIconBackground =
              iconBackground;
        });
      },
      child: AnimatedContainer(
        duration:
        const Duration(milliseconds: 200),
        padding:
        const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFEDE7FF)
              : Colors.white,
          borderRadius:
          BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? primaryPurple
                : const Color(0xFFE6E1EC),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius:
                BorderRadius.circular(9),
              ),
              child: Icon(
                icon,
                size: 17,
                color: iconColor,
              ),
            ),

            const SizedBox(width: 8),

            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected
                    ? FontWeight.w700
                    : FontWeight.w500,
                color:
                const Color(0xFF333333),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DATE
  // ============================================================

  Widget _buildDateSection() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Date'),

        const SizedBox(height: 12),

        GestureDetector(
          onTap: _selectDate,
          child: Container(
            width: double.infinity,
            height: 58,
            padding:
            const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.circular(16),
              border: Border.all(
                color:
                const Color(0xFFE6E1EC),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration:
                  BoxDecoration(
                    color:
                    const Color(0xFFEDE7FF),
                    borderRadius:
                    BorderRadius.circular(
                      11,
                    ),
                  ),
                  child: const Icon(
                    Icons.calendar_today_outlined,
                    color:
                    Color(0xFF6C3CE9),
                    size: 20,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    _displaySelectedDate(),
                    style:
                    const TextStyle(
                      fontSize: 15,
                      fontWeight:
                      FontWeight.w600,
                      color:
                      Color(0xFF333333),
                    ),
                  ),
                ),

                Icon(
                  Icons
                      .keyboard_arrow_down_rounded,
                  color:
                  Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _displaySelectedDate() {
    final DateTime today =
    _dateOnly(DateTime.now());

    final DateTime tomorrow =
    today.add(
      const Duration(days: 1),
    );

    final DateTime selected =
    _dateOnly(selectedDate);

    if (selected == today) {
      return 'Today';
    }

    if (selected == tomorrow) {
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

    return '${months[selected.month - 1]} '
        '${selected.day}, '
        '${selected.year}';
  }

  Future<void> _selectDate() async {
    final DateTime today =
    _dateOnly(DateTime.now());

    final DateTime? picked =
    await showDatePicker(
      context: context,
      initialDate:
      selectedDate.isBefore(today)
          ? today
          : selectedDate,
      firstDate: today,
      lastDate: DateTime(
        today.year + 5,
        12,
        31,
      ),
      builder: (context, child) {
        return Theme(
          data:
          Theme.of(context).copyWith(
            colorScheme:
            const ColorScheme.light(
              primary: Color(0xFF6C3CE9),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      selectedDate = _dateOnly(picked);
    });
  }

  // ============================================================
  // TIME
  // ============================================================

  Widget _buildTimeSection() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Time'),

        const SizedBox(height: 12),

        GestureDetector(
          onTap: _selectTime,
          child: Container(
            width: double.infinity,
            height: 58,
            padding:
            const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.circular(16),
              border: Border.all(
                color:
                const Color(0xFFE6E1EC),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration:
                  BoxDecoration(
                    color:
                    const Color(0xFFEDE7FF),
                    borderRadius:
                    BorderRadius.circular(
                      11,
                    ),
                  ),
                  child: Icon(
                    Icons.access_time_rounded,
                    color: primaryPurple,
                    size: 21,
                  ),
                ),

                const SizedBox(width: 12),

                Text(
                  selectedTime.format(context),
                  style:
                  const TextStyle(
                    fontSize: 15,
                    fontWeight:
                    FontWeight.w600,
                    color:
                    Color(0xFF333333),
                  ),
                ),

                const Spacer(),

                Icon(
                  Icons
                      .keyboard_arrow_down_rounded,
                  color:
                  Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // NOTIFICATION
  // ============================================================

  Widget _buildNotificationSection() {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE6E1EC),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color:
              const Color(0xFFEDE7FF),
              borderRadius:
              BorderRadius.circular(12),
            ),
            child: Icon(
              notificationEnabled
                  ? Icons
                  .notifications_active_outlined
                  : Icons
                  .notifications_off_outlined,
              color: primaryPurple,
              size: 22,
            ),
          ),

          const SizedBox(width: 12),

          const Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Notification',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                    FontWeight.w700,
                    color:
                    Color(0xFF292929),
                  ),
                ),

                SizedBox(height: 3),

                Text(
                  'Notify me when it is time',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                    Color(0xFF777777),
                  ),
                ),
              ],
            ),
          ),

          Switch(
            value: notificationEnabled,
            activeColor: Colors.white,
            activeTrackColor:
            Color(0xFF6C3CE9),
            inactiveThumbColor:
            Colors.white,
            inactiveTrackColor:
            Color(0xFFD5D1DB),
            onChanged: (value) {
              setState(() {
                notificationEnabled =
                    value;
              });
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SAVE BUTTON
  // ============================================================

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _saveReminder,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(16),
          ),
        ),
        child: Text(
          widget.isEditing
              ? 'Save Changes'
              : 'Save Reminder',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SAVE
  // ============================================================

  void _saveReminder() {
    final String title =
    titleController.text.trim();

    final String description =
    descriptionController.text.trim();

    if (title.isEmpty) {
      _showError(
        'Please enter a reminder title.',
      );
      return;
    }

    if (description.isEmpty) {
      _showError(
        'Please enter a description.',
      );
      return;
    }

    final DateTime reminderDateTime =
    DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    final Reminder reminder =
    Reminder(
      id: widget.reminder?.id ??
          DateTime.now()
              .millisecondsSinceEpoch
              .toString(),
      title: title,
      description: description,
      time:
      selectedTime.format(context),
      date:
      _displaySelectedDate(),
      dateTime: reminderDateTime,
      category: selectedCategory,
      icon: selectedIcon,
      iconColor: selectedIconColor,
      iconBackground:
      selectedIconBackground,
      notificationEnabled:
      notificationEnabled,
      isAutomatic: false,
      sourceType: 'manual',
    );

    context.pop(reminder);
  }

  // ============================================================
  // TIME PICKER
  // ============================================================

  Future<void> _selectTime() async {
    final TimeOfDay? pickedTime =
    await showTimePicker(
      context: context,
      initialTime: selectedTime,
      builder: (context, child) {
        return Theme(
          data:
          Theme.of(context).copyWith(
            colorScheme:
            const ColorScheme.light(
              primary: Color(0xFF6C3CE9),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null) {
      return;
    }

    setState(() {
      selectedTime = pickedTime;
    });
  }

  // ============================================================
  // PARSE EXISTING TIME
  // ============================================================

  TimeOfDay _parseTime(
      String time,
      ) {
    try {
      final String cleaned =
      time.trim().toUpperCase();

      final RegExp pattern = RegExp(
        r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$',
      );

      final Match? match =
      pattern.firstMatch(cleaned);

      if (match == null) {
        return const TimeOfDay(
          hour: 14,
          minute: 0,
        );
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

      return TimeOfDay(
        hour: hour,
        minute: minute,
      );
    } catch (_) {
      return const TimeOfDay(
        hour: 14,
        minute: 0,
      );
    }
  }

  // ============================================================
  // DATE ONLY
  // ============================================================

  DateTime _dateOnly(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  // ============================================================
  // SECTION LABEL
  // ============================================================

  Widget _buildSectionLabel(
      String text,
      ) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Color(0xFF292929),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
        Colors.red.shade600,
        behavior:
        SnackBarBehavior.floating,
        margin:
        const EdgeInsets.all(16),
        shape:
        RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(12),
        ),
      ),
    );
  }
}