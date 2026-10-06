import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const Color primaryPurple = Color(0xFF6C3CE9);
  static const Color lightPurple = Color(0xFFF0EAFF);
  static const Color backgroundColor = Color(0xFFF9F7FC);
  static const Color darkText = Color(0xFF29263A);
  static const Color greyText = Color(0xFF777383);

  DateTime selectedDate = DateTime.now();
  DateTime displayedMonth = DateTime.now();

  final List<Map<String, dynamic>> appointments = [
    {
      'title': 'General Check-up',
      'doctor': 'Dr. Fatima Ali',
      'time': '10:00 AM',
      'type': 'Hospital Visit',
      'icon': Icons.local_hospital_outlined,
    },
    {
      'title': 'Antenatal Consultation',
      'doctor': 'Dr. Amina Yusuf',
      'time': '2:30 PM',
      'type': 'Consultation',
      'icon': Icons.favorite_border,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCalendarCard(),
                    const SizedBox(height: 24),
                    _buildUpcomingTitle(),
                    const SizedBox(height: 12),
                    _buildAppointmentCards(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
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
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                size: 18,
                color: darkText,
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Calendar',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: darkText,
                ),
              ),
            ),
          ),
          const SizedBox(width: 42),
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _buildMonthHeader(),
          const SizedBox(height: 20),
          _buildWeekDays(),
          const SizedBox(height: 8),
          _buildCalendarDays(),
        ],
      ),
    );
  }

  Widget _buildMonthHeader() {
    final monthName = _monthName(displayedMonth.month);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: _previousMonth,
          icon: const Icon(
            Icons.chevron_left,
            color: primaryPurple,
          ),
        ),
        Text(
          '$monthName ${displayedMonth.year}',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: darkText,
          ),
        ),
        IconButton(
          onPressed: _nextMonth,
          icon: const Icon(
            Icons.chevron_right,
            color: primaryPurple,
          ),
        ),
      ],
    );
  }

  Widget _buildWeekDays() {
    const days = [
      'M',
      'T',
      'W',
      'T',
      'F',
      'S',
      'S',
    ];

    return Row(
      children: days.map((day) {
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: greyText,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarDays() {
    final firstDayOfMonth = DateTime(
      displayedMonth.year,
      displayedMonth.month,
      1,
    );

    final lastDayOfMonth = DateTime(
      displayedMonth.year,
      displayedMonth.month + 1,
      0,
    );

    // Convert Sunday = 7 so Monday = 1.
    int startingWeekday = firstDayOfMonth.weekday;

    final totalDays = lastDayOfMonth.day;

    final List<Widget> dayWidgets = [];

    // Empty spaces before the first day.
    for (int i = 1; i < startingWeekday; i++) {
      dayWidgets.add(const SizedBox(height: 44));
    }

    for (int day = 1; day <= totalDays; day++) {
      final date = DateTime(
        displayedMonth.year,
        displayedMonth.month,
        day,
      );

      dayWidgets.add(_buildDayCell(date));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.9,
      children: dayWidgets,
    );
  }

  Widget _buildDayCell(DateTime date) {
    final bool isSelected = _isSameDay(date, selectedDate);
    final bool isToday = _isSameDay(date, DateTime.now());

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedDate = date;
        });
      },
      child: Center(
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isSelected
                ? primaryPurple
                : Colors.transparent,
            shape: BoxShape.circle,
            border: isToday && !isSelected
                ? Border.all(
              color: primaryPurple,
              width: 1.5,
            )
                : null,
          ),
          child: Center(
            child: Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : darkText,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Upcoming Appointments',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: darkText,
          ),
        ),
        TextButton(
          onPressed: () {
            context.push('/appointments');
          },
          child: const Text(
            'View all',
            style: TextStyle(
              color: primaryPurple,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentCards() {
    return Column(
      children: appointments.map((appointment) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildAppointmentCard(appointment),
        );
      }).toList(),
    );
  }

  Widget _buildAppointmentCard(
      Map<String, dynamic> appointment,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: lightPurple,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              appointment['icon'] as IconData,
              color: primaryPurple,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment['title'] as String,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: darkText,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  appointment['doctor'] as String,
                  style: const TextStyle(
                    fontSize: 13,
                    color: greyText,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 14,
                      color: primaryPurple,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      appointment['time'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        color: greyText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: greyText,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: Offset(0, -2),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              _bottomItem(
                icon: Icons.home_outlined,
                label: 'Home',
                onTap: () => context.go('/home'),
              ),
              _bottomItem(
                icon: Icons.calendar_month_outlined,
                label: 'Calendar',
                selected: true,
                onTap: () {},
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    context.push('/medications/add');
                  },
                  child: Center(
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: primaryPurple,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
              _bottomItem(
                icon: Icons.chat_bubble_outline,
                label: 'Messages',
                onTap: () => context.go('/messages'),
              ),
              _bottomItem(
                icon: Icons.person_outline,
                label: 'Profile',
                onTap: () => context.go('/profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? primaryPurple : greyText,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? primaryPurple : greyText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _previousMonth() {
    setState(() {
      displayedMonth = DateTime(
        displayedMonth.year,
        displayedMonth.month - 1,
        1,
      );
    });
  }

  void _nextMonth() {
    setState(() {
      displayedMonth = DateTime(
        displayedMonth.year,
        displayedMonth.month + 1,
        1,
      );
    });
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
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
}