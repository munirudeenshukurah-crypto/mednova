import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'appointments_screen.dart';

const Color formPurple = Color(0xFF6C3CE9);
const Color formDarkText = Color(0xFF29263A);
const Color formGreyText = Color(0xFF777383);
const Color formBackground = Color(0xFFF9F7FC);

class AppointmentFormScreen extends StatefulWidget {
  final Appointment? appointment;

  const AppointmentFormScreen({
    super.key,
    this.appointment,
  });

  @override
  State<AppointmentFormScreen> createState() =>
      _AppointmentFormScreenState();
}

class _AppointmentFormScreenState
    extends State<AppointmentFormScreen> {
  late TextEditingController titleController;
  late TextEditingController hospitalController;
  late TextEditingController doctorController;

  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  bool get isEditing =>
      widget.appointment != null;

  @override
  void initState() {
    super.initState();

    titleController =
        TextEditingController(
          text: widget.appointment?.title ?? '',
        );

    hospitalController =
        TextEditingController(
          text: widget.appointment?.hospital ?? '',
        );

    doctorController =
        TextEditingController(
          text: widget.appointment?.doctor ?? '',
        );
  }

  @override
  void dispose() {
    titleController.dispose();
    hospitalController.dispose();
    doctorController.dispose();
    super.dispose();
  }

  Future<void> selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );

    if (date != null) {
      setState(() {
        selectedDate = date;
      });
    }
  }

  Future<void> selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time != null) {
      setState(() {
        selectedTime = time;
      });
    }
  }

  void saveAppointment() {
    if (titleController.text.trim().isEmpty ||
        hospitalController.text.trim().isEmpty ||
        doctorController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete all appointment details.',
          ),
        ),
      );
      return;
    }

    final appointment = Appointment(
      id: widget.appointment?.id,
      title: titleController.text.trim(),
      hospital:
      hospitalController.text.trim(),
      doctor:
      doctorController.text.trim(),
      date: selectedDate != null
          ? '${selectedDate!.day} '
          '${_monthName(selectedDate!.month)} '
          '${selectedDate!.year}'
          : widget.appointment?.date ??
          'Not selected',
      time: selectedTime != null
          ? selectedTime!.format(context)
          : widget.appointment?.time ??
          'Not selected',
      upcoming:
      widget.appointment?.upcoming ?? true,
    );

    context.pop(appointment);
  }

  String _monthName(int month) {
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

    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: formBackground,

      appBar: AppBar(
        backgroundColor: formBackground,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: formDarkText,
            size: 20,
          ),
        ),
        title: Text(
          isEditing
              ? 'Edit Appointment'
              : 'Add Appointment',
          style: const TextStyle(
            color: formDarkText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          20,
          20,
          20,
          30,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            _label('Appointment Title'),

            _textField(
              controller: titleController,
              hint: 'e.g. Antenatal Check-up',
              icon:
              Icons.calendar_month_outlined,
            ),

            const SizedBox(height: 18),

            _label(
              'Hospital / Health Facility',
            ),

            _textField(
              controller: hospitalController,
              hint: 'e.g. General Hospital',
              icon:
              Icons.local_hospital_outlined,
            ),

            const SizedBox(height: 18),

            _label('Doctor'),

            _textField(
              controller: doctorController,
              hint: 'e.g. Dr. Ahmed',
              icon: Icons.person_outline,
            ),

            const SizedBox(height: 18),

            _label('Date'),

            _pickerField(
              icon:
              Icons.calendar_today_outlined,
              text: selectedDate == null
                  ? widget.appointment?.date ??
                  'Select appointment date'
                  : '${selectedDate!.day} '
                  '${_monthName(selectedDate!.month)} '
                  '${selectedDate!.year}',
              onTap: selectDate,
            ),

            const SizedBox(height: 18),

            _label('Time'),

            _pickerField(
              icon: Icons.access_time,
              text: selectedTime == null
                  ? widget.appointment?.time ??
                  'Select appointment time'
                  : selectedTime!.format(
                context,
              ),
              onTap: selectTime,
            ),

            const SizedBox(height: 35),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: saveAppointment,
                style:
                ElevatedButton.styleFrom(
                  backgroundColor: formPurple,
                  foregroundColor:
                  Colors.white,
                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(
                      16,
                    ),
                  ),
                ),
                child: Text(
                  isEditing
                      ? 'Save Changes'
                      : 'Save Appointment',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // ============================================================
      // MEDNOVA BOTTOM NAVIGATION
      // ============================================================

      bottomNavigationBar:
      _buildBottomNavigation(context),
    );
  }

  // ================================================================
  // BOTTOM NAVIGATION
  // ================================================================

  Widget _buildBottomNavigation(
      BuildContext context,
      ) {
    const Color purple =
    Color(0xFF6C3CE9);
    const Color navGrey =
    Color(0xFF777383);

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
                color: purple,
                greyColor: navGrey,
                onTap: () {
                  context.go('/home');
                },
              ),

              _bottomNavItem(
                icon:
                Icons.calendar_month_outlined,
                label: 'Calendar',
                selected: true,
                color: purple,
                greyColor: navGrey,
                onTap: () {},
              ),

              // CENTER +
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
                color: purple,
                greyColor: navGrey,
                onTap: () {
                  context.push('/messages');
                },
              ),

              _bottomNavItem(
                icon: Icons.person_outline,
                label: 'Profile',
                selected: false,
                color: purple,
                greyColor: navGrey,
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
    required Color color,
    required Color greyColor,
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
              selected ? color : greyColor,
              size: 23,
            ),

            const SizedBox(height: 4),

            Text(
              label,
              style: TextStyle(
                color:
                selected ? color : greyColor,
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

  Widget _label(String text) {
    return Padding(
      padding:
      const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: formDarkText,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(
          icon,
          color: formPurple,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _pickerField({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding:
        const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: formPurple,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: formGreyText,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}