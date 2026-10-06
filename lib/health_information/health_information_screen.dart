import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mednova/services/offline_database.dart';

const Color medNovaPurple = Color(0xFF6C3CE9);
const Color lightPurple = Color(0xFFF0EAFF);
const Color darkText = Color(0xFF29263A);
const Color greyText = Color(0xFF777383);
const Color background = Color(0xFFF9F7FC);

class HealthInformation {
  String fullName;
  String dateOfBirth;
  String gender;
  String bloodGroup;
  String allergies;
  String currentMedications;
  String medicalConditions;
  String medicalHistory;
  String healthcareProvider;

  // Profile photo URL saved in Supabase
  String profilePhotoUrl;

  HealthInformation({
    required this.fullName,
    required this.dateOfBirth,
    required this.gender,
    required this.bloodGroup,
    required this.allergies,
    required this.currentMedications,
    required this.medicalConditions,
    required this.medicalHistory,
    required this.healthcareProvider,
    this.profilePhotoUrl = '',
  });
}

class HealthInformationScreen extends StatefulWidget {
  const HealthInformationScreen({super.key});

  @override
  State<HealthInformationScreen> createState() =>
      _HealthInformationScreenState();
}

class _HealthInformationScreenState
    extends State<HealthInformationScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  HealthInformation healthInformation = HealthInformation(
    fullName: 'Loading...',
    dateOfBirth: '',
    gender: '',
    bloodGroup: '',
    allergies: '',
    currentMedications: '',
    medicalConditions: '',
    medicalHistory: '',
    healthcareProvider: '',
    profilePhotoUrl: '',
  );

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHealthInformation();
  }

  // ============================================================
  // LOAD HEALTH INFORMATION
  // ONLINE  -> Supabase + save local cache
  // OFFLINE -> SQLite local cache
  // ============================================================

  Future<void> _loadHealthInformation() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    try {
      // --------------------------------------------------------
      // TRY SUPABASE FIRST
      // --------------------------------------------------------
      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        // ------------------------------------------------------
        // SAVE THE LATEST PROFILE LOCALLY
        // ------------------------------------------------------
        await OfflineDatabase.instance.saveProfile({
          ...Map<String, dynamic>.from(response),
          'id': user.id,
        });

        if (!mounted) return;

        setState(() {
          healthInformation = _healthInformationFromMap(response);
          isLoading = false;
        });

        return;
      }

      // --------------------------------------------------------
      // SUPABASE RETURNED NO PROFILE
      // TRY LOCAL CACHE
      // --------------------------------------------------------
      final localProfile =
      await OfflineDatabase.instance.getProfile(user.id);

      if (localProfile != null) {
        if (!mounted) return;

        setState(() {
          healthInformation =
              _healthInformationFromMap(localProfile);
          isLoading = false;
        });

        return;
      }

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    } catch (error) {
      // --------------------------------------------------------
      // SUPABASE FAILED / OFFLINE
      // LOAD FROM LOCAL SQLITE CACHE
      // --------------------------------------------------------

      try {
        final localProfile =
        await OfflineDatabase.instance.getProfile(user.id);

        if (localProfile != null) {
          if (!mounted) return;

          setState(() {
            healthInformation =
                _healthInformationFromMap(localProfile);
            isLoading = false;
          });

          return;
        }
      } catch (_) {
        // Ignore local database error and show normal message below.
      }

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showMessage(
        'Unable to load your health information.',
      );
    }
  }

  // ============================================================
  // CONVERT PROFILE MAP TO HEALTH INFORMATION MODEL
  // ============================================================

  HealthInformation _healthInformationFromMap(
      Map<String, dynamic> response,
      ) {
    return HealthInformation(
      fullName: _safeString(response['full_name']),
      dateOfBirth: _safeString(response['date_of_birth']),
      gender: _safeString(response['gender']),
      bloodGroup: _safeString(response['blood_group']),
      allergies: _safeString(response['allergies']),
      currentMedications:
      _safeString(response['current_medications']),
      medicalConditions:
      _safeString(response['medical_conditions']),
      medicalHistory:
      _safeString(response['medical_history']),
      healthcareProvider:
      _safeString(response['healthcare_provider']),

      // Profile photo URL from Supabase / local cache
      profilePhotoUrl:
      _safeString(response['profile_photo_url']),
    );
  }

  // ============================================================
  // SAFELY CONVERT VALUES TO STRING
  // ============================================================

  String _safeString(dynamic value) {
    if (value == null) {
      return '';
    }

    return value.toString();
  }

  // ============================================================
  // EDIT HEALTH INFORMATION
  // ============================================================

  Future<void> _editHealthInformation() async {
    await context.push(
      '/edit-health-information',
      extra: healthInformation,
    );

    // Reload latest information after returning
    // from the edit screen.
    if (mounted) {
      await _loadHealthInformation();
    }
  }

  // ============================================================
  // SHOW MESSAGE
  // ============================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // DISPLAY VALUE
  // ============================================================

  String _displayValue(String value) {
    if (value.trim().isEmpty) {
      return 'Not provided';
    }

    return value;
  }

  // ============================================================
  // CALCULATE AGE
  // ============================================================

  String _getAge() {
    if (healthInformation.dateOfBirth.isEmpty) {
      return 'Age not provided';
    }

    try {
      final parts = healthInformation.dateOfBirth.split(' ');

      if (parts.length != 3) {
        return 'Age not provided';
      }

      final day = int.parse(
        parts[1].replaceAll(',', ''),
      );

      final year = int.parse(parts[2]);

      const months = {
        'Jan': 1,
        'Feb': 2,
        'Mar': 3,
        'Apr': 4,
        'May': 5,
        'Jun': 6,
        'Jul': 7,
        'Aug': 8,
        'Sep': 9,
        'Oct': 10,
        'Nov': 11,
        'Dec': 12,
      };

      final month = months[parts[0]];

      if (month == null) {
        return 'Age not provided';
      }

      final dob = DateTime(year, month, day);
      final today = DateTime.now();

      int age = today.year - dob.year;

      if (today.month < dob.month ||
          (today.month == dob.month &&
              today.day < dob.day)) {
        age--;
      }

      return '$age years';
    } catch (_) {
      return 'Age not provided';
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,

        leading: IconButton(
          onPressed: () {
            context.pop();
          },
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: darkText,
            size: 25,
          ),
        ),

        title: const Text(
          'Health Information',
          style: TextStyle(
            color: darkText,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: lightPurple,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.favorite_border,
                color: medNovaPurple,
                size: 25,
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
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            0,
            20,
            30,
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Text(
                'Your personal and medical information\n'
                    'kept safe and up to date.',
                style: TextStyle(
                  color: greyText,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 25),

              // ==================================================
              // PROFILE CARD
              // ==================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                  BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFEDEAF3),
                  ),
                ),
                child: Row(
                  children: [
                    // PROFILE PHOTO
                    Container(
                      width: 58,
                      height: 58,
                      decoration:
                      const BoxDecoration(
                        color: lightPurple,
                        shape: BoxShape.circle,
                      ),
                      child: healthInformation
                          .profilePhotoUrl
                          .isNotEmpty
                          ? ClipOval(
                        child: Image.network(
                          healthInformation
                              .profilePhotoUrl,
                          width: 58,
                          height: 58,
                          fit: BoxFit.cover,
                          errorBuilder: (
                              context,
                              error,
                              stackTrace,
                              ) {
                            return const Icon(
                              Icons.person,
                              color:
                              medNovaPurple,
                              size: 34,
                            );
                          },
                        ),
                      )
                          : const Icon(
                        Icons.person,
                        color:
                        medNovaPurple,
                        size: 34,
                      ),
                    ),

                    const SizedBox(width: 15),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayValue(
                              healthInformation
                                  .fullName,
                            ),
                            style: const TextStyle(
                              color: darkText,
                              fontSize: 16,
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            healthInformation
                                .gender
                                .isEmpty
                                ? _getAge()
                                : '${healthInformation.gender} • ${_getAge()}',
                            style:
                            const TextStyle(
                              color: greyText,
                              fontSize: 12,
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 7),

                          GestureDetector(
                            onTap:
                            _editHealthInformation,
                            child: Container(
                              padding:
                              const EdgeInsets
                                  .symmetric(
                                horizontal: 11,
                                vertical: 5,
                              ),
                              decoration:
                              BoxDecoration(
                                color: lightPurple,
                                borderRadius:
                                BorderRadius
                                    .circular(20),
                              ),
                              child: const Text(
                                'Edit Information',
                                style:
                                TextStyle(
                                  color:
                                  medNovaPurple,
                                  fontSize: 12,
                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ==================================================
              // HEALTH INFORMATION TILES
              // ==================================================

              _healthInfoTile(
                icon: Icons.badge_outlined,
                title: 'Personal Health Details',
                value: 'Health Information.',
                onTap: _editHealthInformation,
              ),

              _healthInfoTile(
                icon: Icons.water_drop_outlined,
                title: 'Blood Group',
                value: _displayValue(
                  healthInformation.bloodGroup,
                ),
                onTap: _editHealthInformation,
              ),

              _healthInfoTile(
                icon: Icons.medication_outlined,
                title: 'Allergies',
                value: _displayValue(
                  healthInformation.allergies,
                ),
                onTap: _editHealthInformation,
              ),

              _healthInfoTile(
                icon:
                Icons.medication_liquid_outlined,
                title: 'Current Medications',
                value: _displayValue(
                  healthInformation
                      .currentMedications,
                ),
                onTap: () {
                  context.push('/medications');
                },
              ),

              _healthInfoTile(
                icon: Icons.favorite_border,
                title: 'Medical Conditions',
                value: _displayValue(
                  healthInformation
                      .medicalConditions,
                ),
                onTap: _editHealthInformation,
              ),

              _healthInfoTile(
                icon: Icons.description_outlined,
                title: 'Medical History',
                value: _displayValue(
                  healthInformation
                      .medicalHistory,
                ),
                onTap: _editHealthInformation,
              ),

              _healthInfoTile(
                icon: Icons.medical_services_outlined,
                title: 'Healthcare Provider',
                value: _displayValue(
                  healthInformation
                      .healthcareProvider,
                ),
                onTap: _editHealthInformation,
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar:
      _buildBottomNavigationBar(context),
    );
  }

  // ============================================================
  // HEALTH INFORMATION TILE
  // ============================================================

  Widget _healthInfoTile({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFEDEAF3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: lightPurple,
                borderRadius:
                BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                color: medNovaPurple,
                size: 30,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: darkText,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.deepPurpleAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right,
              color: Color(0xFF9D98A7),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION BAR
  // ============================================================

  Widget _buildBottomNavigationBar(
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
          height: 70,
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
                icon: Icons.calendar_month_outlined,
                label: 'Schedule',
                selected: false,
                onTap: () {
                  context.go('/appointments');
                },
              ),

              GestureDetector(
                onTap: () {
                  context.push('/medications/add');
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: medNovaPurple,
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
                  context.go('/messages');
                },
              ),

              _bottomNavItem(
                icon: Icons.person_outline,
                label: 'Profile',
                selected: true,
                onTap: () {
                  context.go('/health-information');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM NAV ITEM
  // ============================================================

  Widget _bottomNavItem({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected
                  ? medNovaPurple
                  : greyText,
              size: 22,
            ),

            const SizedBox(height: 3),

            Text(
              label,
              style: TextStyle(
                color: selected
                    ? medNovaPurple
                    : greyText,
                fontSize: 9,
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