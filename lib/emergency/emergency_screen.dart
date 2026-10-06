import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mednova/services/offline_database.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // MEDNOVA COLORS
  // ============================================================

  static const Color purple = Color(0xFF6C3CE9);
  static const Color lightPurple = Color(0xFFF0EAFF);
  static const Color background = Color(0xFFF9F7FC);
  static const Color darkText = Color(0xFF29263A);
  static const Color greyText = Color(0xFF777383);
  static const Color borderColor = Color(0xFFEAE5F5);
  static const Color red = Color(0xFFE53935);
  static const Color green = Color(0xFF22A06B);
  static const Color orange = Color(0xFFF59E0B);

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoadingContacts = true;
  bool _isLoadingFacilities = true;
  bool _isGettingLocation = false;

  List<Map<String, dynamic>> _contacts = [];

  Map<String, dynamic>? _nearestHospital;
  Map<String, dynamic>? _nearestClinic;

  double? _hospitalDistance;
  double? _clinicDistance;

  String? _facilityError;

  @override
  void initState() {
    super.initState();

    _loadEmergencyContacts();
    _loadNearestFacilities();
  }

  // ============================================================
  // USER
  // ============================================================

  User? get _currentUser => _supabase.auth.currentUser;

  // ============================================================
  // OFFLINE EMERGENCY CONTACT TABLE
  // ============================================================

  Future<void> _ensureEmergencyContactsTable() async {
    final db = await OfflineDatabase.instance.database;

    await db.execute('''
      CREATE TABLE IF NOT EXISTS emergency_contacts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        relationship TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
  }

  // ============================================================
  // SAVE CONTACTS TO OFFLINE CACHE
  // ============================================================

  Future<void> _cacheEmergencyContacts(
      String userId,
      List<Map<String, dynamic>> contacts,
      ) async {
    try {
      await _ensureEmergencyContactsTable();

      final db = await OfflineDatabase.instance.database;

      await db.delete(
        'emergency_contacts',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      for (final contact in contacts) {
        final id = contact['id']?.toString();

        if (id == null || id.isEmpty) {
          continue;
        }

        await db.insert(
          'emergency_contacts',
          {
            'id': id,
            'user_id': userId,
            'name': contact['name']?.toString() ?? '',
            'phone': contact['phone']?.toString() ?? '',
            'relationship':
            contact['relationship']?.toString() ?? '',
            'created_at':
            contact['created_at']?.toString(),
            'updated_at':
            contact['updated_at']?.toString(),
          },
        );
      }
    } catch (e) {
      debugPrint(
        'Error caching emergency contacts: $e',
      );
    }
  }

  // ============================================================
  // LOAD CONTACTS FROM OFFLINE CACHE
  // ============================================================

  Future<List<Map<String, dynamic>>> _getCachedEmergencyContacts(
      String userId,
      ) async {
    try {
      await _ensureEmergencyContactsTable();

      final db = await OfflineDatabase.instance.database;

      final result = await db.query(
        'emergency_contacts',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'created_at ASC',
      );

      return result
          .map(
            (row) => Map<String, dynamic>.from(row),
      )
          .toList();
    } catch (e) {
      debugPrint(
        'Error loading cached emergency contacts: $e',
      );

      return [];
    }
  }

  // ============================================================
  // LOAD EMERGENCY CONTACTS
  // ============================================================

  Future<void> _loadEmergencyContacts() async {
    if (!mounted) return;

    setState(() {
      _isLoadingContacts = true;
    });

    try {
      final user = _currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          _contacts = [];
          _isLoadingContacts = false;
        });

        return;
      }

      try {
        // --------------------------------------------------------
        // ONLINE: GET FROM SUPABASE
        // --------------------------------------------------------

        final response = await _supabase
            .from('emergency_contacts')
            .select()
            .eq('user_id', user.id)
            .order('created_at', ascending: true);

        final contacts =
        (response as List)
            .map(
              (item) =>
          Map<String, dynamic>.from(item),
        )
            .toList();

        // --------------------------------------------------------
        // SAVE ONLINE DATA TO OFFLINE CACHE
        // --------------------------------------------------------

        await _cacheEmergencyContacts(
          user.id,
          contacts,
        );

        if (!mounted) return;

        setState(() {
          _contacts = contacts;
          _isLoadingContacts = false;
        });
      } catch (onlineError) {
        // --------------------------------------------------------
        // OFFLINE FALLBACK
        // --------------------------------------------------------

        debugPrint(
          'Emergency contacts online load failed: $onlineError',
        );

        final cachedContacts =
        await _getCachedEmergencyContacts(user.id);

        if (!mounted) return;

        setState(() {
          _contacts = cachedContacts;
          _isLoadingContacts = false;
        });

        if (cachedContacts.isEmpty) {
          _showSnackBar(
            'No saved emergency contacts are available offline.',
            isError: true,
          );
        }
      }
    } catch (e) {
      debugPrint(
        'Error loading emergency contacts: $e',
      );

      if (!mounted) return;

      setState(() {
        _contacts = [];
        _isLoadingContacts = false;
      });
    }
  }

  // ============================================================
  // ADD CONTACT
  // ============================================================

  Future<void> _addContact() async {
    final result = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(
        builder: (_) => const _EmergencyContactFormScreen(),
      ),
    );

    if (result == null) return;

    final user = _currentUser;

    if (user == null) {
      _showSnackBar(
        'Please log in before adding an emergency contact.',
        isError: true,
      );
      return;
    }

    try {
      await _supabase.from('emergency_contacts').insert({
        'user_id': user.id,
        'name': result['name'],
        'phone': result['phone'],
        'relationship': result['relationship'],
      });

      await _loadEmergencyContacts();

      if (!mounted) return;

      _showSnackBar(
        'Emergency contact added successfully.',
      );
    } catch (e) {
      debugPrint(
        'Error adding emergency contact: $e',
      );

      if (!mounted) return;

      _showSnackBar(
        'Could not add emergency contact. Please check your internet connection.',
        isError: true,
      );
    }
  }

  // ============================================================
  // EDIT CONTACT
  // ============================================================

  Future<void> _editContact(
      Map<String, dynamic> contact,
      ) async {
    final result = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(
        builder: (_) => _EmergencyContactFormScreen(
          initialName:
          (contact['name'] ?? '').toString(),
          initialPhone:
          (contact['phone'] ?? '').toString(),
          initialRelationship:
          (contact['relationship'] ?? '').toString(),
        ),
      ),
    );

    if (result == null) return;

    final user = _currentUser;

    if (user == null) return;

    try {
      await _supabase
          .from('emergency_contacts')
          .update({
        'name': result['name'],
        'phone': result['phone'],
        'relationship': result['relationship'],
        'updated_at':
        DateTime.now().toIso8601String(),
      })
          .eq('id', contact['id'])
          .eq('user_id', user.id);

      await _loadEmergencyContacts();

      if (!mounted) return;

      _showSnackBar(
        'Emergency contact updated successfully.',
      );
    } catch (e) {
      debugPrint(
        'Error updating emergency contact: $e',
      );

      if (!mounted) return;

      _showSnackBar(
        'Could not update emergency contact. Please check your internet connection.',
        isError: true,
      );
    }
  }

  // ============================================================
  // DELETE CONTACT
  // ============================================================

  Future<void> _deleteContact(
      Map<String, dynamic> contact,
      ) async {
    final name =
    (contact['name'] ?? 'this contact').toString();

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Remove Contact',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: darkText,
            ),
          ),
          content: Text(
            'Are you sure you want to remove $name from your emergency contacts?',
            style: const TextStyle(
              color: greyText,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: greyText,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text(
                'Remove',
                style: TextStyle(
                  color: red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    final user = _currentUser;

    if (user == null) return;

    try {
      await _supabase
          .from('emergency_contacts')
          .delete()
          .eq('id', contact['id'])
          .eq('user_id', user.id);

      await _loadEmergencyContacts();

      if (!mounted) return;

      _showSnackBar(
        'Emergency contact removed.',
      );
    } catch (e) {
      debugPrint(
        'Error deleting emergency contact: $e',
      );

      if (!mounted) return;

      _showSnackBar(
        'Could not remove emergency contact. Please check your internet connection.',
        isError: true,
      );
    }
  }

  // ============================================================
  // PHONE CALL
  // ============================================================

  Future<void> _makePhoneCall(
      String phoneNumber,
      ) async {
    final cleanedNumber = phoneNumber
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .replaceAll('(', '')
        .replaceAll(')', '');

    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: cleanedNumber,
    );

    try {
      final canLaunch =
      await canLaunchUrl(phoneUri);

      if (!canLaunch) {
        if (!mounted) return;

        _showSnackBar(
          'Your device cannot make phone calls.',
          isError: true,
        );

        return;
      }

      await launchUrl(
        phoneUri,
        mode: LaunchMode.platformDefault,
      );
    } catch (e) {
      debugPrint(
        'Phone call error: $e',
      );

      if (!mounted) return;

      _showSnackBar(
        'Unable to open the phone dialer.',
        isError: true,
      );
    }
  }

  // ============================================================
  // EMERGENCY SERVICES
  // ============================================================

  Future<void> _callEmergencyServices() async {
    await _makePhoneCall('112');
  }

  // ============================================================
  // GET CACHED HEALTH FACILITIES
  // ============================================================

  Future<List<Map<String, dynamic>>>
  _getCachedHealthFacilities() async {
    try {
      final cached =
      await OfflineDatabase.instance
          .getHealthFacilities();

      return cached
          .map(
            (facility) =>
        Map<String, dynamic>.from(facility),
      )
          .toList();
    } catch (e) {
      debugPrint(
        'Error loading cached health facilities: $e',
      );

      return [];
    }
  }

  // ============================================================
  // NEAREST FACILITIES
  // ============================================================

  Future<void> _loadNearestFacilities() async {
    if (!mounted) return;

    setState(() {
      _isLoadingFacilities = true;
      _facilityError = null;
    });

    try {
      // ----------------------------------------------------------
      // CHECK LOCATION SERVICE
      // ----------------------------------------------------------

      final serviceEnabled =
      await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        setState(() {
          _isLoadingFacilities = false;
          _facilityError =
          'Please turn on your device location to find nearby facilities.';
        });

        return;
      }

      // ----------------------------------------------------------
      // CHECK PERMISSION
      // ----------------------------------------------------------

      LocationPermission permission =
      await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
        await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;

        setState(() {
          _isLoadingFacilities = false;
          _facilityError =
          'Location permission is needed to find nearby facilities.';
        });

        return;
      }

      if (permission ==
          LocationPermission.deniedForever) {
        if (!mounted) return;

        setState(() {
          _isLoadingFacilities = false;
          _facilityError =
          'Location permission is permanently denied. Please enable it in Settings.';
        });

        return;
      }

      // ----------------------------------------------------------
      // GET CURRENT LOCATION
      // ----------------------------------------------------------

      if (mounted) {
        setState(() {
          _isGettingLocation = true;
        });
      }

      final Position position =
      await Geolocator.getCurrentPosition(
        locationSettings:
        const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        _isGettingLocation = false;
      });

      // ----------------------------------------------------------
      // TRY SUPABASE FIRST
      // ----------------------------------------------------------

      List<Map<String, dynamic>> facilities = [];

      try {
        final response = await _supabase
            .from('health_facilities')
            .select();

        facilities =
            (response as List)
                .map(
                  (facility) =>
              Map<String, dynamic>.from(
                facility,
              ),
            )
                .toList();
      } catch (onlineError) {
        // --------------------------------------------------------
        // OFFLINE FALLBACK
        // --------------------------------------------------------

        debugPrint(
          'Health facilities online load failed: $onlineError',
        );

        facilities =
        await _getCachedHealthFacilities();
      }

      if (facilities.isEmpty) {
        if (!mounted) return;

        setState(() {
          _nearestHospital = null;
          _nearestClinic = null;
          _hospitalDistance = null;
          _clinicDistance = null;
          _isLoadingFacilities = false;
          _facilityError =
          'No health facilities are available right now.';
        });

        return;
      }

      // ----------------------------------------------------------
      // FIND NEAREST HOSPITAL AND CLINIC
      // ----------------------------------------------------------

      Map<String, dynamic>? nearestHospital;
      Map<String, dynamic>? nearestClinic;

      double? nearestHospitalDistance;
      double? nearestClinicDistance;

      for (final facility in facilities) {
        final latitude =
        _toDouble(facility['latitude']);

        final longitude =
        _toDouble(facility['longitude']);

        if (latitude == null ||
            longitude == null) {
          continue;
        }

        final distanceInMeters =
        Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          latitude,
          longitude,
        );

        final category =
        (facility['category'] ?? '')
            .toString()
            .toLowerCase();

        final name =
        (facility['name'] ?? '')
            .toString()
            .toLowerCase();

        final isHospital =
            category.contains('hospital') ||
                name.contains('hospital');

        final isClinic =
            category.contains('clinic') ||
                name.contains('clinic');

        if (isHospital) {
          if (nearestHospitalDistance == null ||
              distanceInMeters <
                  nearestHospitalDistance) {
            nearestHospital = facility;
            nearestHospitalDistance =
                distanceInMeters;
          }
        }

        if (isClinic) {
          if (nearestClinicDistance == null ||
              distanceInMeters <
                  nearestClinicDistance) {
            nearestClinic = facility;
            nearestClinicDistance =
                distanceInMeters;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _nearestHospital = nearestHospital;
        _nearestClinic = nearestClinic;
        _hospitalDistance =
            nearestHospitalDistance;
        _clinicDistance =
            nearestClinicDistance;
        _isLoadingFacilities = false;
      });
    } catch (e) {
      debugPrint(
        'Error finding nearby facilities: $e',
      );

      if (!mounted) return;

      setState(() {
        _isGettingLocation = false;
        _isLoadingFacilities = false;
        _facilityError =
        'Unable to determine nearby facilities right now.';
      });
    }
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }

  // ============================================================
  // FORMAT DISTANCE
  // ============================================================

  String _formatDistance(double? meters) {
    if (meters == null) {
      return '--';
    }

    if (meters < 1000) {
      return '${meters.round()} m';
    }

    final km = meters / 1000;

    return '${km.toStringAsFixed(
      km < 10 ? 1 : 0,
    )} km';
  }

  // ============================================================
  // GET FACILITY NAME
  // ============================================================

  String _facilityName(
      Map<String, dynamic>? facility,
      ) {
    if (facility == null) {
      return 'No facility found';
    }

    final name =
    (facility['name'] ?? '')
        .toString()
        .trim();

    if (name.isEmpty) {
      return 'Health Facility';
    }

    return name;
  }

  String _facilityLocation(
      Map<String, dynamic>? facility,
      ) {
    if (facility == null) {
      return 'Location unavailable';
    }

    final location =
    (facility['location'] ?? '')
        .toString()
        .trim();

    final area =
    (facility['area'] ?? '')
        .toString()
        .trim();

    if (location.isNotEmpty &&
        area.isNotEmpty) {
      return '$location, $area';
    }

    if (location.isNotEmpty) {
      return location;
    }

    if (area.isNotEmpty) {
      return area;
    }

    return 'Location unavailable';
  }

  // ============================================================
  // OPEN FACILITY PHONE
  // ============================================================

  Future<void> _callFacility(
      Map<String, dynamic>? facility,
      ) async {
    if (facility == null) return;

    final phone =
    (facility['phone'] ?? '')
        .toString()
        .trim();

    if (phone.isEmpty) {
      _showSnackBar(
        'Phone number is not available for this facility.',
        isError: true,
      );
      return;
    }

    await _makePhoneCall(phone);
  }

  // ============================================================
  // OPEN FACILITY MAP
  // ============================================================

  Future<void> _openFacilityOnMap(
      Map<String, dynamic>? facility,
      ) async {
    if (facility == null) return;

    final latitude =
    _toDouble(facility['latitude']);

    final longitude =
    _toDouble(facility['longitude']);

    if (latitude == null ||
        longitude == null) {
      _showSnackBar(
        'Location coordinates are not available.',
        isError: true,
      );
      return;
    }

    final Uri mapUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );

    try {
      final canLaunch =
      await canLaunchUrl(mapUri);

      if (!canLaunch) {
        _showSnackBar(
          'Unable to open the map.',
          isError: true,
        );
        return;
      }

      await launchUrl(
        mapUri,
        mode: LaunchMode.platformDefault,
      );
    } catch (e) {
      debugPrint(
        'Map error: $e',
      );

      if (!mounted) return;

      _showSnackBar(
        'Unable to open the map.',
        isError: true,
      );
    }
  }

  // ============================================================
  // HELP DIALOG
  // ============================================================

  void _showHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Emergency Assistance',
            style: TextStyle(
              color: darkText,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'Use this section to quickly contact emergency services, '
                'reach your trusted contacts, find nearby health facilities, '
                'or share your location.',
            style: TextStyle(
              color: greyText,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'Got it',
                style: TextStyle(
                  color: purple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showSnackBar(
      String message, {
        bool isError = false,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
          isError ? red : green,
          behavior:
          SnackBarBehavior.floating,
        ),
      );
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _onBottomNavTap(int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;

      case 1:
        context.go('/medications');
        break;

      case 2:
        break;

      case 3:
        context.go('/messages');
        break;

      case 4:
        context.go('/profile');
        break;
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
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: darkText,
            size: 20,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: const Text(
          'Emergency Assistance',
          style: TextStyle(
            color: darkText,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _showHelpDialog,
            child: const Text(
              'Help',
              style: TextStyle(
                color: purple,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: RefreshIndicator(
          color: purple,
          onRefresh: () async {
            await Future.wait([
              _loadEmergencyContacts(),
              _loadNearestFacilities(),
            ]);
          },
          child: ListView(
            physics:
            const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              110,
            ),
            children: [
              // ==================================================
              // EMERGENCY CALL CARD
              // ==================================================

              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: red,
                  borderRadius:
                  BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration:
                      BoxDecoration(
                        color: Colors.white
                            .withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.phone_in_talk_rounded,
                        color: Colors.white,
                        size: 27,
                      ),
                    ),

                    const SizedBox(width: 15),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: const [
                          Text(
                            'Call Emergency Services',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight:
                              FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'For immediate emergency assistance',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    IconButton(
                      onPressed:
                      _callEmergencyServices,
                      icon: const Icon(
                        Icons.call_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ==================================================
              // EMERGENCY CONTACTS HEADER
              // ==================================================

              Row(
                mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
                children: [
                  const Text(
                    'Emergency Contacts',
                    style: TextStyle(
                      color: darkText,
                      fontSize: 18,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),

                  TextButton.icon(
                    onPressed: _addContact,
                    icon: const Icon(
                      Icons.add_rounded,
                      size: 19,
                      color: purple,
                    ),
                    label: const Text(
                      'Add',
                      style: TextStyle(
                        color: purple,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ==================================================
              // CONTACTS
              // ==================================================

              if (_isLoadingContacts)
                const Padding(
                  padding:
                  EdgeInsets.symmetric(
                    vertical: 25,
                  ),
                  child: Center(
                    child:
                    CircularProgressIndicator(
                      color: purple,
                    ),
                  ),
                )
              else if (_contacts.isEmpty)
                Container(
                  padding:
                  const EdgeInsets.all(20),
                  decoration:
                  BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                    BorderRadius.circular(
                      18,
                    ),
                    border: Border.all(
                      color: borderColor,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration:
                        const BoxDecoration(
                          color: lightPurple,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons
                              .person_add_alt_1_rounded,
                          color: purple,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No emergency contacts yet',
                        style: TextStyle(
                          color: darkText,
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Add someone you trust so you can reach them quickly during an emergency.',
                        textAlign:
                        TextAlign.center,
                        style: TextStyle(
                          color: greyText,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton(
                        onPressed:
                        _addContact,
                        style:
                        OutlinedButton.styleFrom(
                          foregroundColor:
                          purple,
                          side:
                          const BorderSide(
                            color: purple,
                          ),
                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                              12,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Add Emergency Contact',
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._contacts.map(
                      (contact) =>
                      _buildContactCard(
                        contact,
                      ),
                ),

              const SizedBox(height: 28),

              // ==================================================
              // NEARBY FACILITIES
              // ==================================================

              Row(
                mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
                children: [
                  const Text(
                    'Nearby Facilities',
                    style: TextStyle(
                      color: darkText,
                      fontSize: 18,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),

                  if (!_isLoadingFacilities)
                    IconButton(
                      onPressed:
                      _loadNearestFacilities,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: purple,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              if (_isLoadingFacilities)
                Container(
                  padding:
                  const EdgeInsets.all(25),
                  decoration:
                  BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                    BorderRadius.circular(
                      18,
                    ),
                    border: Border.all(
                      color: borderColor,
                    ),
                  ),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(
                        color: purple,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isGettingLocation
                            ? 'Getting your location...'
                            : 'Finding nearby facilities...',
                        style:
                        const TextStyle(
                          color: greyText,
                        ),
                      ),
                    ],
                  ),
                )
              else if (_facilityError != null)
                Container(
                  padding:
                  const EdgeInsets.all(18),
                  decoration:
                  BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                    BorderRadius.circular(
                      18,
                    ),
                    border: Border.all(
                      color: borderColor,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons
                            .location_off_rounded,
                        color: orange,
                        size: 34,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _facilityError!,
                        textAlign:
                        TextAlign.center,
                        style:
                        const TextStyle(
                          color: greyText,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed:
                        _loadNearestFacilities,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          'Try Again',
                        ),
                        style:
                        OutlinedButton.styleFrom(
                          foregroundColor:
                          purple,
                          side:
                          const BorderSide(
                            color: purple,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                  if (_nearestHospital != null)
                    _buildFacilityCard(
                      title: 'Nearest Hospital',
                      facility:
                      _nearestHospital,
                      distance:
                      _hospitalDistance,
                      icon: Icons
                          .local_hospital_rounded,
                      iconColor: red,
                    ),

                  if (_nearestHospital !=
                      null &&
                      _nearestClinic != null)
                    const SizedBox(height: 12),

                  if (_nearestClinic != null)
                    _buildFacilityCard(
                      title: 'Nearby Clinic',
                      facility:
                      _nearestClinic,
                      distance:
                      _clinicDistance,
                      icon: Icons
                          .medical_services_rounded,
                      iconColor: green,
                    ),

                  if (_nearestHospital ==
                      null &&
                      _nearestClinic == null)
                    Container(
                      padding:
                      const EdgeInsets.all(
                        20,
                      ),
                      decoration:
                      BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                        BorderRadius.circular(
                          18,
                        ),
                        border: Border.all(
                          color: borderColor,
                        ),
                      ),
                      child: const Text(
                        'No nearby hospitals or clinics with verified coordinates were found.',
                        textAlign:
                        TextAlign.center,
                        style: TextStyle(
                          color: greyText,
                          height: 1.4,
                        ),
                      ),
                    ),
                ],

              const SizedBox(height: 28),

              // ==================================================
              // SHARE LOCATION
              // ==================================================

              GestureDetector(
                onTap: () {
                  context.push(
                    '/share-location',
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.all(20),
                  decoration:
                  BoxDecoration(
                    color: lightPurple,
                    borderRadius:
                    BorderRadius.circular(
                      20,
                    ),
                    border: Border.all(
                      color: const Color(
                        0xFFE2D8FF,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration:
                        const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons
                              .location_on_rounded,
                          color: purple,
                          size: 27,
                        ),
                      ),

                      const SizedBox(width: 15),

                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                          children: [
                            Text(
                              'Share My Location',
                              style: TextStyle(
                                color: darkText,
                                fontSize: 16,
                                fontWeight:
                                FontWeight
                                    .w700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Share your live location with trusted contacts.',
                              style: TextStyle(
                                color: greyText,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Icon(
                        Icons
                            .arrow_forward_ios_rounded,
                        color: purple,
                        size: 17,
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
      // MEDNOVA BOTTOM NAVIGATION
      // ============================================================

      bottomNavigationBar:
      _buildBottomNavigationBar(),
    );
  }

  // ============================================================
  // CONTACT CARD
  // ============================================================

  Widget _buildContactCard(
      Map<String, dynamic> contact,
      ) {
    final String name =
    (contact['name'] ??
        'Emergency Contact')
        .toString();

    final String phone =
    (contact['phone'] ?? '')
        .toString();

    final String relationship =
    (contact['relationship'] ?? '')
        .toString();

    return Container(
      margin:
      const EdgeInsets.only(bottom: 12),
      padding:
      const EdgeInsets.all(15),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration:
            const BoxDecoration(
              color: lightPurple,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: purple,
              size: 24,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: darkText,
                    fontSize: 15,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  relationship.isEmpty
                      ? phone
                      : '$relationship • $phone',
                  style:
                  const TextStyle(
                    color: greyText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: phone.isEmpty
                ? null
                : () =>
                _makePhoneCall(
                  phone,
                ),
            icon: const Icon(
              Icons.call_rounded,
              color: green,
              size: 21,
            ),
          ),

          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: greyText,
            ),
            onSelected: (value) {
              if (value == 'edit') {
                _editContact(contact);
              } else if (value ==
                  'delete') {
                _deleteContact(contact);
              }
            },
            itemBuilder: (context) =>
            const [
              PopupMenuItem<String>(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_rounded,
                      size: 19,
                      color: purple,
                    ),
                    SizedBox(width: 10),
                    Text('Edit'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons
                          .delete_outline_rounded,
                      size: 19,
                      color: red,
                    ),
                    SizedBox(width: 10),
                    Text('Remove'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FACILITY CARD
  // ============================================================

  Widget _buildFacilityCard({
    required String title,
    required Map<String, dynamic>? facility,
    required double? distance,
    required IconData icon,
    required Color iconColor,
  }) {
    final String name =
    _facilityName(facility);

    final String location =
    _facilityLocation(facility);

    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(16),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration:
            BoxDecoration(
              color:
              iconColor.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),

          const SizedBox(width: 13),

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
                    fontWeight:
                    FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  name,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style:
                  const TextStyle(
                    color: darkText,
                    fontSize: 15,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  location,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style:
                  const TextStyle(
                    color: greyText,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _formatDistance(
                    distance,
                  ),
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          Column(
            children: [
              IconButton(
                tooltip: 'Call',
                onPressed: () =>
                    _callFacility(
                      facility,
                    ),
                icon: const Icon(
                  Icons.call_rounded,
                  color: green,
                  size: 20,
                ),
              ),
              IconButton(
                tooltip: 'Map',
                onPressed: () =>
                    _openFacilityOnMap(
                      facility,
                    ),
                icon: const Icon(
                  Icons
                      .location_on_outlined,
                  color: purple,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration:
      BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset:
            const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              Expanded(
                child: _navItem(
                  icon:
                  Icons.home_outlined,
                  label: 'Home',
                  onTap: () =>
                      _onBottomNavTap(0),
                ),
              ),

              Expanded(
                child: _navItem(
                  icon:
                  Icons.medication_outlined,
                  label: 'Medications',
                  onTap: () =>
                      _onBottomNavTap(1),
                ),
              ),

              SizedBox(
                width: 70,
                child: Center(
                  child:
                  GestureDetector(
                    onTap: () {
                      context.go(
                        '/medications/add',
                      );
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration:
                      const BoxDecoration(
                        color: purple,
                        shape:
                        BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color:
                        Colors.white,
                        size: 29,
                      ),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: _navItem(
                  icon: Icons
                      .chat_bubble_outline_rounded,
                  label: 'Messages',
                  onTap: () =>
                      _onBottomNavTap(3),
                ),
              ),

              Expanded(
                child: _navItem(
                  icon: Icons
                      .person_outline_rounded,
                  label: 'Profile',
                  onTap: () =>
                      _onBottomNavTap(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
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
            maxLines: 1,
            overflow:
            TextOverflow.ellipsis,
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
    );
  }
}

// ============================================================================
// EMERGENCY CONTACT FORM
// ============================================================================

class _EmergencyContactFormScreen
    extends StatefulWidget {
  final String initialName;
  final String initialPhone;
  final String initialRelationship;

  const _EmergencyContactFormScreen({
    this.initialName = '',
    this.initialPhone = '',
    this.initialRelationship = '',
  });

  @override
  State<_EmergencyContactFormScreen>
  createState() =>
      _EmergencyContactFormScreenState();
}

class _EmergencyContactFormScreenState
    extends State<_EmergencyContactFormScreen> {
  final _formKey =
  GlobalKey<FormState>();

  late final TextEditingController
  _nameController;

  late final TextEditingController
  _phoneController;

  late final TextEditingController
  _relationshipController;

  bool _saving = false;

  static const Color purple =
  Color(0xFF6C3CE9);

  static const Color background =
  Color(0xFFF9F7FC);

  static const Color darkText =
  Color(0xFF29263A);

  static const Color greyText =
  Color(0xFF777383);

  static const Color borderColor =
  Color(0xFFEAE5F5);

  bool get _isEditing =>
      widget.initialName.isNotEmpty ||
          widget.initialPhone.isNotEmpty ||
          widget.initialRelationship
              .isNotEmpty;

  @override
  void initState() {
    super.initState();

    _nameController =
        TextEditingController(
          text: widget.initialName,
        );

    _phoneController =
        TextEditingController(
          text: widget.initialPhone,
        );

    _relationshipController =
        TextEditingController(
          text: widget.initialRelationship,
        );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationshipController.dispose();

    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    final result =
    <String, String>{
      'name':
      _nameController.text.trim(),
      'phone':
      _phoneController.text.trim(),
      'relationship':
      _relationshipController
          .text
          .trim(),
    };

    if (!mounted) return;

    Navigator.of(context).pop(
      result,
    );
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor:
        background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons
                .arrow_back_ios_new_rounded,
            color: darkText,
            size: 20,
          ),
          onPressed: _saving
              ? null
              : () =>
              Navigator.of(
                context,
              ).pop(),
        ),
        title: Text(
          _isEditing
              ? 'Edit Emergency Contact'
              : 'Add Emergency Contact',
          style:
          const TextStyle(
            color: darkText,
            fontSize: 19,
            fontWeight:
            FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding:
            const EdgeInsets.fromLTRB(
              20,
              15,
              20,
              30,
            ),
            children: [
              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.all(
                  20,
                ),
                decoration:
                BoxDecoration(
                  color: const Color(
                    0xFFF0EAFF,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    18,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons
                          .shield_outlined,
                      color: purple,
                      size: 32,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Add someone you trust and can reach quickly in an emergency.',
                        style:
                        TextStyle(
                          color: darkText,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              _buildLabel(
                'Full Name',
              ),

              const SizedBox(height: 8),

              TextFormField(
                controller:
                _nameController,
                textInputAction:
                TextInputAction
                    .next,
                decoration:
                _inputDecoration(
                  hint:
                  'Enter full name',
                  icon: Icons
                      .person_outline_rounded,
                ),
                validator: (value) {
                  if (value == null ||
                      value
                          .trim()
                          .isEmpty) {
                    return 'Please enter the contact name';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 20),

              _buildLabel(
                'Phone Number',
              ),

              const SizedBox(height: 8),

              TextFormField(
                controller:
                _phoneController,
                keyboardType:
                TextInputType.phone,
                textInputAction:
                TextInputAction
                    .next,
                decoration:
                _inputDecoration(
                  hint:
                  'Enter phone number',
                  icon: Icons
                      .phone_outlined,
                ),
                validator: (value) {
                  if (value == null ||
                      value
                          .trim()
                          .isEmpty) {
                    return 'Please enter a phone number';
                  }

                  if (value
                      .trim()
                      .length <
                      7) {
                    return 'Please enter a valid phone number';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 20),

              _buildLabel(
                'Relationship',
              ),

              const SizedBox(height: 8),

              TextFormField(
                controller:
                _relationshipController,
                textInputAction:
                TextInputAction
                    .done,
                decoration:
                _inputDecoration(
                  hint:
                  'e.g. Husband, Sister, Friend',
                  icon: Icons
                      .people_outline_rounded,
                ),
              ),

              const SizedBox(height: 35),

              SizedBox(
                height: 54,
                width: double.infinity,
                child:
                ElevatedButton(
                  onPressed:
                  _saving
                      ? null
                      : _save,
                  style:
                  ElevatedButton
                      .styleFrom(
                    backgroundColor:
                    purple,
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
                  child: _saving
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color:
                      Colors
                          .white,
                    ),
                  )
                      : Text(
                    _isEditing
                        ? 'Save Changes'
                        : 'Add Contact',
                    style:
                    const TextStyle(
                      fontSize: 15,
                      fontWeight:
                      FontWeight
                          .w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(
      String label,
      ) {
    return Text(
      label,
      style: const TextStyle(
        color: darkText,
        fontSize: 14,
        fontWeight:
        FontWeight.w600,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
      const TextStyle(
        color: greyText,
        fontSize: 13,
      ),
      prefixIcon: Icon(
        icon,
        color: purple,
        size: 21,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
      const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 16,
      ),
      border:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          14,
        ),
        borderSide:
        const BorderSide(
          color: borderColor,
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
          color: borderColor,
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
          color: purple,
          width: 1.5,
        ),
      ),
      errorBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          14,
        ),
        borderSide:
        const BorderSide(
          color: Colors.redAccent,
        ),
      ),
      focusedErrorBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          14,
        ),
        borderSide:
        const BorderSide(
          color: Colors.redAccent,
        ),
      ),
    );
  }
}