import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class FacilityMapScreen extends StatefulWidget {
  const FacilityMapScreen({super.key});

  @override
  State<FacilityMapScreen> createState() => _FacilityMapScreenState();
}

class _FacilityMapScreenState extends State<FacilityMapScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final MapController _mapController = MapController();

  int selectedCategory = 0;
  int selectedFacility = 0;

  bool _isLoading = true;
  bool _isGettingLocation = false;
  String? _errorMessage;

  Position? _currentPosition;

  List<Map<String, dynamic>> _facilities = [];

  static const Color purple = Color(0xFF6C3CE9);
  static const Color lightPurple = Color(0xFFF0EAFF);
  static const Color background = Color(0xFFF9F7FC);
  static const Color darkText = Color(0xFF29263A);
  static const Color greyText = Color(0xFF777383);
  static const Color borderColor = Color(0xFFEAE5F5);
  static const Color green = Color(0xFF22A06B);
  static const Color orange = Color(0xFFF59E0B);

  static const LatLng _defaultMapCenter = LatLng(9.0820, 8.6753);
  static const double _defaultZoom = 5.5;

  final List<String> _categories = [
    'Hospitals',
    'Clinics',
    'Pharmacies',
    'Laboratories',
  ];

  @override
  void initState() {
    super.initState();
    _loadFacilities();
  }

  Future<void> _loadFacilities() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }

      final response = await _supabase
          .from('health_facilities')
          .select()
          .order('name', ascending: true);

      final data = List<Map<String, dynamic>>.from(response);

      if (!mounted) return;

      setState(() {
        _facilities = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load health facilities.';
      });
    }
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  LatLng? _facilityLatLng(Map<String, dynamic> facility) {
    final latitude = _toDouble(facility['latitude']);
    final longitude = _toDouble(facility['longitude']);

    if (latitude == null || longitude == null) {
      return null;
    }

    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    return LatLng(latitude, longitude);
  }

  List<Map<String, dynamic>> get _filteredFacilities {
    final category = _categories[selectedCategory];

    return _facilities.where((facility) {
      final facilityCategory =
      (facility['category'] ?? '').toString().toLowerCase();

      return facilityCategory == category.toLowerCase();
    }).toList();
  }

  List<Map<String, dynamic>> get _mappedFacilities {
    return _filteredFacilities.where((facility) {
      return _facilityLatLng(facility) != null;
    }).toList();
  }

  Future<void> _getCurrentLocation() async {
    if (_isGettingLocation) return;

    setState(() {
      _isGettingLocation = true;
    });

    try {
      final serviceEnabled =
      await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        _showMessage(
          'Please turn on your device location service.',
        );

        setState(() {
          _isGettingLocation = false;
        });

        return;
      }

      LocationPermission permission =
      await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;

        _showMessage(
          'Location permission was denied.',
        );

        setState(() {
          _isGettingLocation = false;
        });

        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;

        _showMessage(
          'Location permission is permanently denied. Please enable it in Settings.',
        );

        setState(() {
          _isGettingLocation = false;
        });

        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        _currentPosition = position;
        _isGettingLocation = false;
      });

      _mapController.move(
        LatLng(
          position.latitude,
          position.longitude,
        ),
        14,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isGettingLocation = false;
      });

      _showMessage(
        'Unable to get your current location.',
      );
    }
  }

  Future<void> _openDirections(
      Map<String, dynamic> facility,
      ) async {
    final location = _facilityLatLng(facility);

    if (location == null) {
      _showMessage(
        'Directions are unavailable because this facility has no coordinates.',
      );
      return;
    }

    final destination =
        '${location.latitude},${location.longitude}';

    final googleMapsUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
          '&destination=$destination'
          '&travelmode=driving',
    );

    try {
      final launched = await launchUrl(
        googleMapsUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        _showMessage(
          'Could not open Google Maps.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Could not open directions.',
        );
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _selectFacility(
      Map<String, dynamic> facility,
      int index,
      ) {
    setState(() {
      selectedFacility = index;
    });

    final location = _facilityLatLng(facility);

    if (location != null) {
      _mapController.move(
        location,
        15,
      );
    }

    _showFacilityDetails(facility);
  }

  void _showFacilityDetails(
      Map<String, dynamic> facility,
      ) {
    final name =
    (facility['name'] ?? 'Health Facility').toString();

    final category =
    (facility['category'] ?? '').toString();

    final location =
    (facility['location'] ?? '').toString();

    final area =
    (facility['area'] ?? '').toString();

    final state =
    (facility['state'] ?? '').toString();

    final openingHours =
    (facility['opening_hours'] ?? '').toString();

    final status =
    (facility['status'] ?? '').toString();

    final ownership =
    (facility['ownership'] ?? '').toString();

    final phone =
    (facility['phone'] ?? '').toString();

    final ratingValue = facility['rating'];

    String rating = '';

    if (ratingValue != null) {
      rating = ratingValue.toString();
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight:
              MediaQuery.of(context).size.height * 0.82,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                20,
                12,
                20,
                28,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: borderColor,
                        borderRadius:
                        BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
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
                          Icons.local_hospital_outlined,
                          color: purple,
                          size: 27,
                        ),
                      ),

                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 2,
                              overflow:
                              TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight:
                                FontWeight.w700,
                                color: darkText,
                              ),
                            ),

                            const SizedBox(height: 5),

                            Text(
                              category.isEmpty
                                  ? 'Health Facility'
                                  : category,
                              maxLines: 1,
                              overflow:
                              TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: greyText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  if (location.isNotEmpty)
                    _detailRow(
                      Icons.location_on_outlined,
                      location,
                    ),

                  if (area.isNotEmpty)
                    _detailRow(
                      Icons.map_outlined,
                      area,
                    ),

                  if (state.isNotEmpty)
                    _detailRow(
                      Icons.location_city_outlined,
                      state,
                    ),

                  if (ownership.isNotEmpty)
                    _detailRow(
                      Icons.business_outlined,
                      ownership,
                    ),

                  if (openingHours.isNotEmpty)
                    _detailRow(
                      Icons.access_time_outlined,
                      openingHours,
                    ),

                  if (status.isNotEmpty)
                    _detailRow(
                      Icons.circle,
                      status,
                      iconColor:
                      status.toLowerCase().contains('open')
                          ? green
                          : orange,
                    ),

                  if (phone.isNotEmpty)
                    _detailRow(
                      Icons.phone_outlined,
                      phone,
                    ),

                  if (rating.isNotEmpty)
                    _detailRow(
                      Icons.star_outline,
                      rating,
                      iconColor: orange,
                    ),

                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openDirections(facility);
                      },
                      icon: const Icon(
                        Icons.directions_outlined,
                        size: 21,
                      ),
                      label: const Text(
                        'Get Directions',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purple,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(
      IconData icon,
      String text, {
        Color iconColor = purple,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: iconColor,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: darkText,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildFacilityMarkers(
      List<Map<String, dynamic>> facilities,
      ) {
    return facilities.map((facility) {
      final location =
      _facilityLatLng(facility)!;

      return Marker(
        point: location,
        width: 58,
        height: 70,
        child: GestureDetector(
          onTap: () {
            _showFacilityDetails(facility);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: purple,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                      Colors.black.withOpacity(0.18),
                      blurRadius: 7,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_hospital,
                  color: Colors.white,
                  size: 22,
                ),
              ),

              CustomPaint(
                size: const Size(10, 8),
                painter: MarkerTailPainter(
                  color: purple,
                ),
              ),
            ],
          ),
        ),
        alignment: Alignment.topCenter,
      );
    }).toList();
  }

  Widget _buildMap() {
    final mappedFacilities =
        _mappedFacilities;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentPosition != null
                ? LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            )
                : _defaultMapCenter,
            initialZoom:
            _currentPosition != null
                ? 13.5
                : _defaultZoom,
            minZoom: 3,
            maxZoom: 19,
            interactionOptions:
            const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate:
              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName:
              'com.example.mednova',
            ),

            if (mappedFacilities.isNotEmpty)
              MarkerLayer(
                markers: _buildFacilityMarkers(
                  mappedFacilities,
                ),
              ),

            if (_currentPosition != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    width: 46,
                    height: 46,
                    child: Container(
                      decoration: BoxDecoration(
                        color:
                        Colors.blue.withOpacity(0.20),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 17,
                          height: 17,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors',
                ),
              ],
            ),
          ],
        ),

        Positioned(
          right: 16,
          top: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _mapButton(
                icon: Icons.add,
                onTap: () {
                  final currentZoom =
                      _mapController.camera.zoom;

                  _mapController.move(
                    _mapController.camera.center,
                    (currentZoom + 1)
                        .clamp(3.0, 19.0),
                  );
                },
              ),

              const SizedBox(height: 8),

              _mapButton(
                icon: Icons.remove,
                onTap: () {
                  final currentZoom =
                      _mapController.camera.zoom;

                  _mapController.move(
                    _mapController.camera.center,
                    (currentZoom - 1)
                        .clamp(3.0, 19.0),
                  );
                },
              ),
            ],
          ),
        ),

        Positioned(
          right: 16,
          bottom: 20,
          child: _mapButton(
            icon: _isGettingLocation
                ? Icons.hourglass_top
                : Icons.my_location,
            onTap: _getCurrentLocation,
          ),
        ),

        if (mappedFacilities.isEmpty &&
            !_isLoading)
          Positioned(
            left: 20,
            right: 20,
            bottom: 22,
            child: Container(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 13,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color:
                    Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset:
                    const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                'No facilities with map coordinates were found in this category.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: greyText,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _mapButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(
            icon,
            color: darkText,
            size: 21,
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding:
        const EdgeInsets.symmetric(
          horizontal: 20,
        ),
        itemCount: _categories.length,
        separatorBuilder: (_, __) {
          return const SizedBox(width: 10);
        },
        itemBuilder: (context, index) {
          final selected =
              selectedCategory == index;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedCategory = index;
                selectedFacility = 0;
              });
            },
            child: Container(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 17,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? purple
                    : Colors.white,
                borderRadius:
                BorderRadius.circular(22),
                border: Border.all(
                  color: selected
                      ? purple
                      : borderColor,
                ),
              ),
              child: Center(
                child: Text(
                  _categories[index],
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                    FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : darkText,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFacilityBottomList() {
    final facilities =
        _filteredFacilities;

    if (facilities.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 112,
      child: Container(
        color: Colors.white,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding:
          const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          itemCount: facilities.length,
          separatorBuilder: (_, __) {
            return const SizedBox(width: 12);
          },
          itemBuilder: (context, index) {
            final facility =
            facilities[index];

            final name =
            (facility['name'] ??
                'Health Facility')
                .toString();

            final location =
            (facility['location'] ??
                facility['area'] ??
                '')
                .toString();

            return GestureDetector(
              onTap: () {
                _selectFacility(
                  facility,
                  index,
                );
              },
              child: Container(
                width: 245,
                padding:
                const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius:
                  BorderRadius.circular(15),
                  border: Border.all(
                    color: borderColor,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: lightPurple,
                        borderRadius:
                        BorderRadius.circular(
                            12),
                      ),
                      child: const Icon(
                        Icons
                            .local_hospital_outlined,
                        color: purple,
                        size: 22,
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Column(
                        mainAxisAlignment:
                        MainAxisAlignment.center,
                        mainAxisSize:
                        MainAxisSize.min,
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow:
                            TextOverflow.ellipsis,
                            style:
                            const TextStyle(
                              fontSize: 13,
                              fontWeight:
                              FontWeight.w700,
                              color: darkText,
                              height: 1.15,
                            ),
                          ),

                          if (location.isNotEmpty) ...[
                            const SizedBox(height: 4),

                            Text(
                              location,
                              maxLines: 1,
                              overflow:
                              TextOverflow.ellipsis,
                              style:
                              const TextStyle(
                                fontSize: 11,
                                color: greyText,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // BOTTOM NAVIGATION
  // ------------------------------------------------------------

  Widget _bottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: borderColor,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceAround,
            crossAxisAlignment:
            CrossAxisAlignment.center,
            children: [
              _navItem(
                icon: Icons.home_outlined,
                label: 'Home',
                onTap: () {
                  context.go('/home');
                },
              ),

              _navItem(
                icon: Icons.medication_outlined,
                label: 'Medications',
                onTap: () {
                  context.go('/medications');
                },
              ),

              _navItem(
                icon:
                Icons.calendar_today_outlined,
                label: 'Appointments',
                onTap: () {
                  context.go('/appointments');
                },
              ),

              _navItem(
                icon: Icons.person_outline,
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

  Widget _navItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
      BorderRadius.circular(12),
      child: SizedBox(
        width: 72,
        height: 58,
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: greyText,
              size: 21,
            ),

            const SizedBox(height: 3),

            Text(
              label,
              maxLines: 1,
              overflow:
              TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: greyText,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding:
              const EdgeInsets.fromLTRB(
                20,
                14,
                20,
                12,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      context.pop();
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration:
                      BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                        BorderRadius.circular(
                            13),
                        border: Border.all(
                          color: borderColor,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: darkText,
                        size: 21,
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  const Expanded(
                    child: Text(
                      'Health Facilities',
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                        FontWeight.w700,
                        color: darkText,
                      ),
                    ),
                  ),

                  GestureDetector(
                    onTap: _loadFacilities,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration:
                      BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                        BorderRadius.circular(
                            13),
                        border: Border.all(
                          color: borderColor,
                        ),
                      ),
                      child: const Icon(
                        Icons.refresh,
                        color: purple,
                        size: 21,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            _buildCategorySelector(),

            const SizedBox(height: 12),

            Expanded(
              child: _isLoading
                  ? const Center(
                child:
                CircularProgressIndicator(
                  color: purple,
                ),
              )
                  : _errorMessage != null
                  ? Center(
                child: Padding(
                  padding:
                  const EdgeInsets.all(
                      24),
                  child: Column(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons
                            .location_off_outlined,
                        color: greyText,
                        size: 42,
                      ),

                      const SizedBox(
                          height: 12),

                      Text(
                        _errorMessage!,
                        textAlign:
                        TextAlign.center,
                        style:
                        const TextStyle(
                          color: greyText,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(
                          height: 16),

                      ElevatedButton(
                        onPressed:
                        _loadFacilities,
                        style:
                        ElevatedButton
                            .styleFrom(
                          backgroundColor:
                          purple,
                          foregroundColor:
                          Colors.white,
                        ),
                        child:
                        const Text(
                          'Retry',
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  : _buildMap(),
            ),

            _buildFacilityBottomList(),
          ],
        ),
      ),

      bottomNavigationBar:
      _bottomNavigationBar(),
    );
  }
}

// ============================================================
// MAP MARKER TAIL
// ============================================================

class MarkerTailPainter
    extends CustomPainter {
  final Color color;

  MarkerTailPainter({
    this.color =
    const Color(0xFF6C3CE9),
  });

  @override
  void paint(
      Canvas canvas,
      Size size,
      ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final ui.Path path = ui.Path();

    path.moveTo(
      size.width / 2 - 5,
      0,
    );

    path.lineTo(
      size.width / 2 + 5,
      0,
    );

    path.lineTo(
      size.width / 2,
      size.height,
    );

    path.close();

    canvas.drawPath(
      path,
      paint,
    );
  }

  @override
  bool shouldRepaint(
      covariant MarkerTailPainter oldDelegate,
      ) {
    return oldDelegate.color != color;
  }
}