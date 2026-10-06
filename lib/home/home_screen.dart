import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color purple = Color(0xFF6C3CE9);
  static const Color lightPurple = Color(0xFFF0EAFF);
  static const Color background = Color(0xFFF9F7FC);
  static const Color darkText = Color(0xFF29263A);
  static const Color greyText = Color(0xFF777383);

  final SupabaseClient supabase = Supabase.instance.client;

  String userName = 'User';
  bool isLoadingName = true;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    try {
      final response = await supabase
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        if (response != null &&
            response['full_name'] != null &&
            response['full_name'].toString().trim().isNotEmpty) {
          userName = response['full_name'].toString().trim();
        } else {
          userName = 'User';
        }

        isLoadingName = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        userName = 'User';
        isLoadingName = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // =====================================================
              // HEADER
              // =====================================================

              Row(
                children: [

                  // MENU
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      onPressed: () {
                        // Menu action will be added later
                      },
                      icon: const Icon(
                        Icons.menu,
                        color: darkText,
                        size: 24,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // GREETING
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isLoadingName
                              ? 'Hello 👋'
                              : 'Hello, $userName 👋',
                          style: const TextStyle(
                            color: darkText,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 4),

                        const Text(
                          'Take charge of your health today.',
                          style: TextStyle(
                            color: greyText,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // =================================================
                  // NOTIFICATION BELL → REMINDERS
                  // =================================================

                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      onPressed: () {
                        context.push('/reminders');
                      },
                      icon: const Icon(
                        Icons.notifications_none_outlined,
                        color: darkText,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 27),

              // =====================================================
              // STAY ON TRACK CARD
              // =====================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: purple,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [

                          const Text(
                            'Stay on track',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          const Text(
                            'You have 2 medications\ndue today',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),

                          const SizedBox(height: 15),

                          ElevatedButton(
                            onPressed: () {
                              context.push('/medications');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: purple,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'View Schedule',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // MEDICATION ILLUSTRATION
                    Container(
                      width: 85,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Stack(
                        alignment: Alignment.center,
                        children: [

                          Icon(
                            Icons.assignment_outlined,
                            color: Colors.white,
                            size: 58,
                          ),

                          Positioned(
                            bottom: 14,
                            right: 12,
                            child: Icon(
                              Icons.medication_outlined,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // =====================================================
              // QUICK ACCESS TITLE
              // =====================================================

              const Text(
                'Quick Access',
                style: TextStyle(
                  color: darkText,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              // =====================================================
              // QUICK ACCESS GRID
              // =====================================================

              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics:
                const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.95,
                children: [

                  _quickAccess(
                    context,
                    Icons.menu_book_outlined,
                    'Health\nInformation',
                    '/health-information',
                  ),

                  _quickAccess(
                    context,
                    Icons.medication_outlined,
                    'Medications',
                    '/medications',
                  ),

                  _quickAccess(
                    context,
                    Icons.calendar_month_outlined,
                    'Appointments',
                    '/appointments',
                  ),

                  _quickAccess(
                    context,
                    Icons.local_hospital_outlined,
                    'Health\nFacilities',
                    '/health-facilities',
                  ),

                  _quickAccess(
                    context,
                    Icons.notifications_none_outlined,
                    'Reminders',
                    '/reminders',
                  ),

                  _quickAccess(
                    context,
                    Icons.emergency_outlined,
                    'Emergency',
                    '/emergency',
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // =====================================================
              // UPCOMING APPOINTMENT
              // =====================================================

              Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: [

                  const Text(
                    'Upcoming Appointment',
                    style: TextStyle(
                      color: darkText,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  TextButton(
                    onPressed: () {
                      context.push('/appointments');
                    },
                    child: const Text(
                      'See all',
                      style: TextStyle(
                        color: purple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              GestureDetector(
                onTap: () {
                  context.push('/appointments');
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: lightPurple,
                          borderRadius:
                          BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.medical_services_outlined,
                          color: purple,
                        ),
                      ),

                      const SizedBox(width: 15),

                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [

                            Text(
                              'General Consultation',
                              style: TextStyle(
                                color: darkText,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),

                            SizedBox(height: 5),

                            Text(
                              'Tomorrow • 10:00 AM',
                              style: TextStyle(
                                color: greyText,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Icon(
                        Icons.chevron_right,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // =====================================================
              // NEXT MEDICATION
              // =====================================================

              const Text(
                'Next Medication',
                style: TextStyle(
                  color: darkText,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              GestureDetector(
                onTap: () {
                  context.push('/medications');
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9F7EF),
                          borderRadius:
                          BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.medication,
                          color: Colors.green,
                        ),
                      ),

                      const SizedBox(width: 15),

                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [

                            Text(
                              'Amoxicillin 500mg',
                              style: TextStyle(
                                color: darkText,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),

                            SizedBox(height: 5),

                            Text(
                              'Take at 2:00 PM',
                              style: TextStyle(
                                color: greyText,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Icon(
                        Icons.notifications_active_outlined,
                        color: purple,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // =====================================================
              // EMERGENCY ASSISTANCE
              // =====================================================

              GestureDetector(
                onTap: () {
                  context.push('/emergency');
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEEEE),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.red.shade100,
                    ),
                  ),
                  child: const Row(
                    children: [

                      Icon(
                        Icons.emergency,
                        color: Colors.red,
                        size: 30,
                      ),

                      SizedBox(width: 15),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [

                            Text(
                              'Emergency Assistance',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),

                            SizedBox(height: 4),

                            Text(
                              'Get urgent help and locate nearby care.',
                              style: TextStyle(
                                color: greyText,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.red,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // ============================================================
      // BOTTOM NAVIGATION
      // ============================================================

      bottomNavigationBar: Container(
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
                  selected: true,
                  onTap: () {},
                ),

                _bottomNavItem(
                  icon: Icons.calendar_month_outlined,
                  label: 'Calendar',
                  selected: false,
                  onTap: () {
                    context.push('/appointments');
                  },
                ),

                // CENTER +
                GestureDetector(
                  onTap: () {
                    context.push('/medications/add');
                  },
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(
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
                  icon: Icons.chat_bubble_outline,
                  label: 'Messages',
                  selected: false,
                  onTap: () {
                    context.push('/messages');
                  },
                ),

                // =================================================
                // PROFILE → HEALTH INFORMATION
                // =================================================

                _bottomNavItem(
                  icon: Icons.person_outline,
                  label: 'Profile',
                  selected: false,
                  onTap: () {
                    context.push('/health-information');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================================================================
  // QUICK ACCESS WIDGET
  // ================================================================

  Widget _quickAccess(
      BuildContext context,
      IconData icon,
      String title,
      String route,
      ) {
    return GestureDetector(
      onTap: () {
        context.push(route);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFEDEAF3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: lightPurple,
                borderRadius:
                BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                color: purple,
                size: 30,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 10,
                fontStyle: FontStyle.normal,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // BOTTOM NAV ITEM
  // ================================================================

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
              color: selected ? purple : greyText,
              size: 23,
            ),

            const SizedBox(height: 4),

            Text(
              label,
              style: TextStyle(
                color: selected ? purple : greyText,
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
}