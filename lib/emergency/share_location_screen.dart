import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';

class ShareLocationScreen extends StatefulWidget {
  const ShareLocationScreen({super.key});

  @override
  State<ShareLocationScreen> createState() =>
      _ShareLocationScreenState();
}

class _ShareLocationScreenState extends State<ShareLocationScreen> {
  // ============================================================
  // MEDNOVA COLORS
  // ============================================================

  static const Color medNovaPurple = Color(0xFF6C3CE9);
  static const Color lightPurple = Color(0xFFF7F4FF);
  static const Color softPurple = Color(0xFFF1EDFF);
  static const Color darkText = Color(0xFF29243D);
  static const Color greyText = Color(0xFF777287);
  static const Color borderColor = Color(0xFFE8E4F2);

  // ============================================================
  // SUPABASE
  // ============================================================

  final SupabaseClient supabase = Supabase.instance.client;

  // ============================================================
  // CONTACT PICKER
  // ============================================================

  final FlutterNativeContactPicker _contactPicker =
  FlutterNativeContactPicker();

  // ============================================================
  // STATE
  // ============================================================

  String selectedDuration = '30 minutes';

  bool isSharing = false;
  bool isLoadingLocation = false;
  bool isLoadingContacts = true;
  bool isPickingPhoneContact = false;

  int selectedContact = 0;

  Position? currentPosition;

  String? locationError;
  String? activeLocationId;

  StreamSubscription<Position>? _positionSubscription;

  // ============================================================
  // CONTACTS
  // ============================================================

  List<Map<String, String>> contacts = [];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadEmergencyContacts();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightPurple,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  12,
                  18,
                  20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),

                    const SizedBox(height: 20),

                    _buildLocationIllustration(),

                    const SizedBox(height: 20),

                    _buildDurationSection(),

                    const SizedBox(height: 22),

                    _buildContactSection(),

                    const SizedBox(height: 22),

                    if (currentPosition != null)
                      _buildCurrentLocationCard(),

                    if (currentPosition != null)
                      const SizedBox(height: 14),

                    if (locationError != null)
                      _buildLocationError(),

                    if (locationError != null)
                      const SizedBox(height: 14),

                    _buildShareButton(),

                    const SizedBox(height: 16),

                    _buildPrivacyMessage(),
                  ],
                ),
              ),
            ),

            _buildBottomNavigation(context),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: borderColor,
              ),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: darkText,
            ),
          ),
        ),

        const SizedBox(width: 12),

        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share My Location',
                style: TextStyle(
                  color: darkText,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Share your live location with trusted contacts.',
                style: TextStyle(
                  color: greyText,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // LOCATION ILLUSTRATION
  // ============================================================

  Widget _buildLocationIllustration() {
    return Container(
      height: 190,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 45,
            bottom: 30,
            child: _smallCircle(28),
          ),

          Positioned(
            right: 55,
            top: 25,
            child: _smallCircle(20),
          ),

          Positioned(
            right: 75,
            bottom: 35,
            child: _smallCircle(14),
          ),

          CustomPaint(
            size: const Size(230, 90),
            painter: _LocationPathPainter(
              color: medNovaPurple.withOpacity(0.20),
            ),
          ),

          Container(
            height: 72,
            width: 72,
            decoration: BoxDecoration(
              color: medNovaPurple,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: medNovaPurple.withOpacity(0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallCircle(double size) {
    return Container(
      height: size,
      width: size,
      decoration: const BoxDecoration(
        color: softPurple,
        shape: BoxShape.circle,
      ),
    );
  }

  // ============================================================
  // DURATION
  // ============================================================

  Widget _buildDurationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Share Duration',
          style: TextStyle(
            color: darkText,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 10),

        Container(
          height: 50,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: borderColor,
            ),
          ),
          child: Row(
            children: [
              _durationOption('30 minutes'),
              _durationOption('1 hour'),
              _durationOption('Until I turn it off'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _durationOption(String duration) {
    final bool isSelected = selectedDuration == duration;

    return Expanded(
      child: GestureDetector(
        onTap: isSharing
            ? null
            : () {
          setState(() {
            selectedDuration = duration;
          });
        },
        child: Container(
          height: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? medNovaPurple
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            duration,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : greyText,
              fontSize: 10.5,
              fontWeight: isSelected
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CONTACT SECTION
  // ============================================================

  Widget _buildContactSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Select Contact',
                style: TextStyle(
                  color: darkText,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            GestureDetector(
              onTap: isSharing || isPickingPhoneContact
                  ? null
                  : _pickPhoneContact,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: softPurple,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: medNovaPurple.withOpacity(0.15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPickingPhoneContact)
                      const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: medNovaPurple,
                        ),
                      )
                    else
                      const Icon(
                        Icons.contacts_outlined,
                        color: medNovaPurple,
                        size: 16,
                      ),

                    const SizedBox(width: 5),

                    Text(
                      isPickingPhoneContact
                          ? 'Opening...'
                          : 'Phone Contacts',
                      style: const TextStyle(
                        color: medNovaPurple,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        if (isLoadingContacts)
          _buildContactsLoading()
        else if (contacts.isEmpty)
          _buildNoContacts()
        else
          ...List.generate(
            contacts.length,
                (index) {
              final contact = contacts[index];

              final bool isSelected =
                  selectedContact == index;

              return GestureDetector(
                onTap: isSharing
                    ? null
                    : () {
                  setState(() {
                    selectedContact = index;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(
                    bottom: 10,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? medNovaPurple
                          : borderColor,
                      width: isSelected ? 1.4 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 46,
                        width: 46,
                        decoration: const BoxDecoration(
                          color: softPurple,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: medNovaPurple,
                          size: 24,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              contact['name'] ??
                                  'Trusted Contact',
                              style: const TextStyle(
                                color: darkText,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),

                            const SizedBox(height: 3),

                            Text(
                              contact['phone'] ?? '',
                              style: const TextStyle(
                                color: greyText,
                                fontSize: 12,
                              ),
                            ),

                            if (contact['source'] ==
                                'phone')
                              const Padding(
                                padding: EdgeInsets.only(
                                  top: 3,
                                ),
                                child: Text(
                                  'Phone contact',
                                  style: TextStyle(
                                    color: medNovaPurple,
                                    fontSize: 9,
                                    fontWeight:
                                    FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      Container(
                        height: 22,
                        width: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? medNovaPurple
                                : borderColor,
                            width: 1.5,
                          ),
                        ),
                        child: isSelected
                            ? Center(
                          child: Container(
                            height: 12,
                            width: 12,
                            decoration:
                            const BoxDecoration(
                              color:
                              medNovaPurple,
                              shape:
                              BoxShape.circle,
                            ),
                          ),
                        )
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

        if (!isLoadingContacts)
          GestureDetector(
            onTap: isSharing || isPickingPhoneContact
                ? null
                : _pickPhoneContact,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: borderColor,
                ),
              ),
              child: const Row(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_add_alt_1_rounded,
                    color: medNovaPurple,
                    size: 18,
                  ),
                  SizedBox(width: 7),
                  Text(
                    'Choose another phone contact',
                    style: TextStyle(
                      color: medNovaPurple,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // CONTACT LOADING
  // ============================================================

  Widget _buildContactsLoading() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: const Row(
        children: [
          SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: medNovaPurple,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Loading trusted contacts...',
            style: TextStyle(
              color: greyText,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NO CONTACTS
  // ============================================================

  Widget _buildNoContacts() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.people_outline_rounded,
            color: medNovaPurple,
            size: 30,
          ),

          const SizedBox(height: 8),

          const Text(
            'No trusted contacts yet',
            style: TextStyle(
              color: darkText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'Choose a contact from your phone to share your location.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: greyText,
              fontSize: 10.5,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 12),

          GestureDetector(
            onTap: isPickingPhoneContact
                ? null
                : _pickPhoneContact,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: medNovaPurple,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Choose Phone Contact',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOAD EMERGENCY CONTACTS
  // ============================================================

  Future<void> _loadEmergencyContacts() async {
    if (!mounted) return;

    setState(() {
      isLoadingContacts = true;
    });

    final user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        contacts = [];
        selectedContact = 0;
        isLoadingContacts = false;
      });

      return;
    }

    try {
      final response = await supabase
          .from('emergency_contacts')
          .select('id, name, phone, relationship')
          .eq('user_id', user.id)
          .order('created_at', ascending: true);

      final List<Map<String, String>> loadedContacts = [];

      for (final item in response) {
        final String name =
        (item['name'] ?? '').toString().trim();

        final String phone =
        (item['phone'] ?? '').toString().trim();

        if (name.isNotEmpty && phone.isNotEmpty) {
          loadedContacts.add({
            'id': (item['id'] ?? '').toString(),
            'name': name,
            'phone': phone,
            'relationship':
            (item['relationship'] ?? '').toString(),
            'source': 'emergency',
          });
        }
      }

      if (!mounted) return;

      setState(() {
        contacts = loadedContacts;

        if (selectedContact >= contacts.length) {
          selectedContact = contacts.isEmpty
              ? 0
              : contacts.length - 1;
        }

        isLoadingContacts = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        contacts = [];
        selectedContact = 0;
        isLoadingContacts = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to load your trusted contacts.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // PICK PHONE CONTACT
  // ============================================================

  Future<void> _pickPhoneContact() async {
    if (isSharing || isPickingPhoneContact) {
      return;
    }

    if (!mounted) return;

    setState(() {
      isPickingPhoneContact = true;
    });

    try {
      final contact =
      await _contactPicker.selectPhoneNumber();

      if (contact == null) {
        if (!mounted) return;

        setState(() {
          isPickingPhoneContact = false;
        });

        return;
      }

      final String name =
      (contact.fullName ?? '').trim();

      final String phone =
      (contact.selectedPhoneNumber ?? '').trim();

      if (phone.isEmpty) {
        if (!mounted) return;

        setState(() {
          isPickingPhoneContact = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The selected contact does not have a phone number.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );

        return;
      }

      final String displayName =
      name.isEmpty ? 'Phone Contact' : name;

      if (!mounted) return;

      setState(() {
        contacts.add({
          'id': '',
          'name': displayName,
          'phone': phone,
          'relationship': '',
          'source': 'phone',
        });

        selectedContact = contacts.length - 1;
        isPickingPhoneContact = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$displayName selected.',
          ),
          backgroundColor: medNovaPurple,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isPickingPhoneContact = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open your phone contacts.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // CURRENT LOCATION
  // ============================================================

  Widget _buildCurrentLocationCard() {
    final position = currentPosition!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: medNovaPurple.withOpacity(0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: const BoxDecoration(
              color: softPurple,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.my_location_rounded,
              color: medNovaPurple,
              size: 21,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Location',
                  style: TextStyle(
                    color: darkText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '${position.latitude.toStringAsFixed(6)}, '
                      '${position.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(
                    color: greyText,
                    fontSize: 11,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  'Accuracy: '
                      '${position.accuracy.toStringAsFixed(0)} metres',
                  style: const TextStyle(
                    color: greyText,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildLocationError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.red.withOpacity(0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.location_off_outlined,
            color: Colors.red,
            size: 20,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              locationError!,
              style: const TextStyle(
                color: greyText,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // GET LOCATION
  // ============================================================

  Future<Position?> _getCurrentLocation() async {
    try {
      if (mounted) {
        setState(() {
          isLoadingLocation = true;
          locationError = null;
        });
      }

      final bool serviceEnabled =
      await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            locationError =
            'Location services are turned off. '
                'Please turn on your phone location and try again.';
            isLoadingLocation = false;
          });
        }

        return null;
      }

      LocationPermission permission =
      await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
        await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            locationError =
            'Location permission was denied. '
                'Please allow MedNova to access your location.';
            isLoadingLocation = false;
          });
        }

        return null;
      }

      if (permission ==
          LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            locationError =
            'Location permission is permanently denied. '
                'Please enable location permission from your phone settings.';
            isLoadingLocation = false;
          });
        }

        return null;
      }

      final Position position =
      await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) {
        return position;
      }

      setState(() {
        currentPosition = position;
        isLoadingLocation = false;
        locationError = null;
      });

      return position;
    } catch (_) {
      if (!mounted) return null;

      setState(() {
        isLoadingLocation = false;
        locationError =
        'Unable to get your current location. '
            'Please check your GPS and try again.';
      });

      return null;
    }
  }

  // ============================================================
  // CALCULATE EXPIRATION
  // ============================================================

  DateTime? _calculateExpiration() {
    final DateTime now = DateTime.now();

    switch (selectedDuration) {
      case '30 minutes':
        return now.add(
          const Duration(minutes: 30),
        );

      case '1 hour':
        return now.add(
          const Duration(hours: 1),
        );

      case 'Until I turn it off':
        return null;

      default:
        return null;
    }
  }

  // ============================================================
  // SAVE LOCATION TO SUPABASE
  // ============================================================

  Future<String?> _saveLocationToSupabase(
      Position position,
      ) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          locationError =
          'You need to be logged in before sharing your location.';
        });
      }

      return null;
    }

    if (contacts.isEmpty ||
        selectedContact >= contacts.length) {
      if (mounted) {
        setState(() {
          locationError =
          'Please select a trusted contact before sharing your location.';
        });
      }

      return null;
    }

    final contact = contacts[selectedContact];

    final DateTime now = DateTime.now();

    final DateTime? expiresAt =
    _calculateExpiration();

    try {
      final response = await supabase
          .from('emergency_locations')
          .insert({
        'user_id': user.id,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'contact_name': contact['name'],
        'contact_phone': contact['phone'],
        'share_duration': selectedDuration,
        'is_sharing': true,
        'started_at':
        now.toUtc().toIso8601String(),
        'expires_at': expiresAt
            ?.toUtc()
            .toIso8601String(),
        'last_updated_at':
        now.toUtc().toIso8601String(),
      }).select('id').single();

      return response['id']?.toString();
    } catch (_) {
      if (mounted) {
        setState(() {
          locationError =
          'Your location was found, but it could not be saved to your account.';
        });
      }

      return null;
    }
  }

  // ============================================================
  // START LIVE LOCATION UPDATES
  // ============================================================

  Future<void> _startLocationUpdates() async {
    await _positionSubscription?.cancel();

    const LocationSettings locationSettings =
    LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen(
              (Position position) {
            if (!mounted) return;

            setState(() {
              currentPosition = position;
            });

            _updateLocationInSupabase(position);
          },
          onError: (_) {
            // Keep sharing active even if one stream update fails.
          },
        );
  }

  // ============================================================
  // UPDATE LOCATION IN SUPABASE
  // ============================================================

  Future<void> _updateLocationInSupabase(
      Position position,
      ) async {
    if (activeLocationId == null) {
      return;
    }

    try {
      await supabase
          .from('emergency_locations')
          .update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'last_updated_at':
        DateTime.now()
            .toUtc()
            .toIso8601String(),
      }).eq(
        'id',
        activeLocationId!,
      );
    } catch (_) {
      // Keep the app running even if an update fails.
    }
  }

  // ============================================================
  // STOP LOCATION UPDATES
  // ============================================================

  Future<void> _stopLocationUpdates() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  // ============================================================
  // STOP LOCATION SHARING IN SUPABASE
  // ============================================================

  Future<void> _stopLocationSharing() async {
    await _stopLocationUpdates();

    if (activeLocationId == null) {
      return;
    }

    try {
      await supabase
          .from('emergency_locations')
          .update({
        'is_sharing': false,
        'last_updated_at':
        DateTime.now()
            .toUtc()
            .toIso8601String(),
      }).eq(
        'id',
        activeLocationId!,
      );
    } catch (_) {
      // Do not crash the app if the update fails.
    }
  }

  // ============================================================
  // SHARE LOCATION
  // ============================================================

  Future<void> _shareLocation() async {
    // ------------------------------------------------------------
    // STOP SHARING
    // ------------------------------------------------------------

    if (isSharing) {
      await _stopLocationSharing();

      if (!mounted) return;

      setState(() {
        isSharing = false;
        activeLocationId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Location sharing has been stopped.',
          ),
          backgroundColor: medNovaPurple,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      return;
    }

    // ------------------------------------------------------------
    // CHECK CONTACT
    // ------------------------------------------------------------

    if (contacts.isEmpty ||
        selectedContact >= contacts.length) {
      setState(() {
        locationError =
        'Please select a trusted contact before sharing your location.';
      });

      return;
    }

    // ------------------------------------------------------------
    // GET GPS LOCATION
    // ------------------------------------------------------------

    final Position? position =
    await _getCurrentLocation();

    if (position == null) {
      return;
    }

    // ------------------------------------------------------------
    // SAVE TO SUPABASE
    // ------------------------------------------------------------

    final String? locationId =
    await _saveLocationToSupabase(
      position,
    );

    if (locationId == null) {
      return;
    }

    activeLocationId = locationId;

    // ------------------------------------------------------------
    // START LIVE LOCATION UPDATES
    // ------------------------------------------------------------

    await _startLocationUpdates();

    // ------------------------------------------------------------
    // PREPARE SMS
    // ------------------------------------------------------------

    final contact = contacts[selectedContact];

    final String mapsUrl =
        'https://www.google.com/maps/search/?api=1'
        '&query=${position.latitude},'
        '${position.longitude}';

    final String message =
        'Hello ${contact['name']},\n\n'
        'I am sharing my current location with you '
        'through MedNova.\n\n'
        'My location:\n'
        '$mapsUrl\n\n'
        'Share duration: $selectedDuration\n\n'
        'MedNova will continue updating my location while '
        'location sharing is active.';

    final Uri smsUri = Uri(
      scheme: 'sms',
      path: contact['phone'],
      queryParameters: {
        'body': message,
      },
    );

    try {
      final bool launched = await launchUrl(
        smsUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        await _stopLocationSharing();

        if (!mounted) return;

        setState(() {
          activeLocationId = null;
          isSharing = false;
        });

        _showSmsError();

        return;
      }

      if (!mounted) return;

      setState(() {
        isSharing = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Your location is now being shared with ${contact['name']}.',
          ),
          backgroundColor: medNovaPurple,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (_) {
      await _stopLocationSharing();

      if (!mounted) return;

      setState(() {
        activeLocationId = null;
        isSharing = false;
      });

      _showSmsError();
    }
  }

  // ============================================================
  // SMS ERROR
  // ============================================================

  void _showSmsError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Unable to open the SMS application on this device.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // SHARE BUTTON
  // ============================================================

  Widget _buildShareButton() {
    return GestureDetector(
      onTap: isLoadingLocation
          ? null
          : _shareLocation,
      child: Container(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isLoadingLocation
              ? medNovaPurple.withOpacity(0.55)
              : medNovaPurple,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: medNovaPurple.withOpacity(0.20),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            if (isLoadingLocation)
              const SizedBox(
                height: 19,
                width: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              Icon(
                isSharing
                    ? Icons.stop_circle_outlined
                    : Icons.location_on_outlined,
                color: Colors.white,
                size: 20,
              ),

            const SizedBox(width: 8),

            Text(
              isLoadingLocation
                  ? 'Getting Location...'
                  : isSharing
                  ? 'Stop Sharing'
                  : 'Share Location',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PRIVACY MESSAGE
  // ============================================================

  Widget _buildPrivacyMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: softPurple.withOpacity(0.75),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            color: medNovaPurple,
            size: 21,
          ),

          SizedBox(width: 10),

          Expanded(
            child: Text(
              'Your location is secure and only shared '
                  'with the contact you select.',
              style: TextStyle(
                color: greyText,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomNavigation(
      BuildContext context,
      ) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: borderColor,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment:
        MainAxisAlignment.spaceAround,
        children: [
          _navItem(
            context,
            icon: Icons.home_outlined,
            label: 'Home',
            route: '/home',
          ),

          _navItem(
            context,
            icon: Icons.medication_outlined,
            label: 'Medications',
            route: '/medications',
          ),

          GestureDetector(
            onTap: () {
              context.push('/emergency');
            },
            child: Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: medNovaPurple,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:
                    medNovaPurple.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 27,
              ),
            ),
          ),

          _navItem(
            context,
            icon:
            Icons.chat_bubble_outline_rounded,
            label: 'Messages',
            route: '/messages',
          ),

          _navItem(
            context,
            icon:
            Icons.person_outline_rounded,
            label: 'Profile',
            route: '/profile',
          ),
        ],
      ),
    );
  }

  Widget _navItem(
      BuildContext context, {
        required IconData icon,
        required String label,
        required String route,
      }) {
    return GestureDetector(
      onTap: () => context.go(route),
      child: SizedBox(
        width: 62,
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: greyText,
              size: 21,
            ),

            const SizedBox(height: 4),

            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: greyText,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// LOCATION PATH PAINTER
// ================================================================

class _LocationPathPainter extends CustomPainter {
  final Color color;

  _LocationPathPainter({
    required this.color,
  });

  @override
  void paint(
      Canvas canvas,
      Size size,
      ) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final Path path = Path();

    path.moveTo(
      10,
      size.height * 0.70,
    );

    path.cubicTo(
      size.width * 0.20,
      size.height * 0.10,
      size.width * 0.35,
      size.height * 0.95,
      size.width * 0.50,
      size.height * 0.48,
    );

    path.cubicTo(
      size.width * 0.65,
      size.height * 0.02,
      size.width * 0.78,
      size.height * 0.85,
      size.width - 10,
      size.height * 0.25,
    );

    canvas.drawPath(
      path,
      paint,
    );

    final Paint dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(
        size.width * 0.22,
        size.height * 0.33,
      ),
      4,
      dotPaint,
    );

    canvas.drawCircle(
      Offset(
        size.width * 0.78,
        size.height * 0.52,
      ),
      4,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(
      covariant CustomPainter oldDelegate,
      ) {
    return false;
  }
}