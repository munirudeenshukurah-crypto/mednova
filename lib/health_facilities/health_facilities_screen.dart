import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mednova/services/offline_database.dart';

class HealthFacilitiesScreen extends StatefulWidget {
  const HealthFacilitiesScreen({super.key});

  @override
  State<HealthFacilitiesScreen> createState() =>
      _HealthFacilitiesScreenState();
}

class _HealthFacilitiesScreenState extends State<HealthFacilitiesScreen> {
  // ============================================================
  // MEDNOVA COLORS
  // ============================================================

  static const Color purple = Color(0xFF6C3CE9);
  static const Color lightPurple = Color(0xFFF0EAFF);
  static const Color background = Color(0xFFF9F7FC);
  static const Color darkText = Color(0xFF29263A);
  static const Color greyText = Color(0xFF777383);
  static const Color borderColor = Color(0xFFEAE5F5);
  static const Color green = Color(0xFF22A06B);
  static const Color orange = Color(0xFFF59E0B);

  // ============================================================
  // SEARCH
  // ============================================================

  final TextEditingController _searchController =
  TextEditingController();

  String _searchText = '';

  // null = show all facilities
  String? _selectedCategory;

  // ============================================================
  // SUPABASE
  // ============================================================

  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // FACILITY DATA
  // ============================================================

  List<HealthFacility> _facilities = [];

  bool _isLoading = true;
  String? _errorMessage;

  // ============================================================
  // CATEGORY LIST
  // ============================================================

  final List<FacilityCategory> _categories = const [
    FacilityCategory(
      name: 'Hospitals',
      icon: Icons.local_hospital_outlined,
    ),
    FacilityCategory(
      name: 'Clinics',
      icon: Icons.medical_services_outlined,
    ),
    FacilityCategory(
      name: 'Pharmacies',
      icon: Icons.medication_outlined,
    ),
    FacilityCategory(
      name: 'Laboratories',
      icon: Icons.science_outlined,
    ),
  ];

  // ============================================================
  // INIT STATE
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadFacilities();
  }

  // ============================================================
  // LOAD FACILITIES
  //
  // ONLINE:
  // Supabase -> Screen -> SQLite cache
  //
  // OFFLINE:
  // SQLite cache -> Screen
  // ============================================================

  Future<void> _loadFacilities() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // --------------------------------------------------------
      // TRY SUPABASE FIRST
      // --------------------------------------------------------

      final response = await _supabase
          .from('health_facilities')
          .select()
          .order('name', ascending: true);

      final List<HealthFacility> loadedFacilities =
      (response as List)
          .map(
            (facility) => HealthFacility.fromSupabase(
          Map<String, dynamic>.from(facility),
        ),
      )
          .toList();

      // --------------------------------------------------------
      // SAVE FACILITIES TO LOCAL SQLITE CACHE
      // --------------------------------------------------------

      for (final facility in loadedFacilities) {
        await OfflineDatabase.instance.saveHealthFacility(
          facility.toOfflineMap(),
        );
      }

      if (!mounted) return;

      setState(() {
        _facilities = loadedFacilities;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      // --------------------------------------------------------
      // SUPABASE FAILED
      // LOAD FROM LOCAL SQLITE CACHE
      // --------------------------------------------------------

      debugPrint(
        'Health facilities Supabase error: $error',
      );

      try {
        final localFacilities =
        await OfflineDatabase.instance.getHealthFacilities();

        final List<HealthFacility> cachedFacilities =
        localFacilities
            .map(
              (facility) => HealthFacility.fromOfflineMap(
            Map<String, dynamic>.from(facility),
          ),
        )
            .toList();

        if (!mounted) return;

        if (cachedFacilities.isNotEmpty) {
          setState(() {
            _facilities = cachedFacilities;
            _isLoading = false;
            _errorMessage = null;
          });

          debugPrint(
            'Loaded ${cachedFacilities.length} health facilities from offline cache.',
          );
        } else {
          setState(() {
            _facilities = [];
            _isLoading = false;
            _errorMessage =
            'Unable to load health facilities right now.';
          });
        }
      } catch (localError) {
        debugPrint(
          'Health facilities offline cache error: $localError',
        );

        if (!mounted) return;

        setState(() {
          _facilities = [];
          _isLoading = false;
          _errorMessage =
          'Unable to load health facilities right now.';
        });
      }
    }
  }

  // ============================================================
  // FILTERED FACILITIES
  // ============================================================

  List<HealthFacility> get _filteredFacilities {
    final query = _searchText.trim().toLowerCase();

    return _facilities.where((facility) {
      final matchesCategory =
          _selectedCategory == null ||
              facility.category == _selectedCategory;

      final matchesSearch =
          query.isEmpty ||
              facility.name.toLowerCase().contains(query) ||
              facility.location.toLowerCase().contains(query) ||
              facility.area.toLowerCase().contains(query) ||
              facility.state.toLowerCase().contains(query) ||
              facility.category.toLowerCase().contains(query);

      return matchesCategory && matchesSearch;
    }).toList();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),

                    const SizedBox(height: 20),

                    _buildSearchBar(),

                    const SizedBox(height: 20),

                    _buildCategories(),

                    const SizedBox(height: 20),

                    _buildListMapSwitcher(),

                    const SizedBox(height: 14),

                    _buildFacilityList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: 1,
            ),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: darkText,
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Find Health Facilities',
                style: TextStyle(
                  color: darkText,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Nearby hospitals, clinics, pharmacies\nand more.',
                style: TextStyle(
                  color: greyText,
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(
            color: lightPurple,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.favorite_outline_rounded,
            color: purple,
            size: 24,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SEARCH BAR
  // ============================================================

  Widget _buildSearchBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchText = value;
          });
        },
        textInputAction: TextInputAction.search,
        style: const TextStyle(
          color: darkText,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText:
          'Search hospitals, clinics, pharmacies...',
          hintStyle: const TextStyle(
            color: greyText,
            fontSize: 12,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: greyText,
            size: 21,
          ),
          suffixIcon: _searchText.isNotEmpty
              ? IconButton(
            onPressed: () {
              _searchController.clear();

              setState(() {
                _searchText = '';
              });
            },
            icon: const Icon(
              Icons.close_rounded,
              color: greyText,
              size: 18,
            ),
          )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CATEGORIES
  // ============================================================

  Widget _buildCategories() {
    return SizedBox(
      height: 86,
      child: Row(
        children: _categories.map((category) {
          final bool selected =
              _selectedCategory == category.name;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (_selectedCategory == category.name) {
                    _selectedCategory = null;
                  } else {
                    _selectedCategory = category.name;
                  }
                });
              },
              child: _buildCategoryItem(
                category,
                selected,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryItem(
      FacilityCategory category,
      bool selected,
      ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: selected
                ? lightPurple
                : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            category.icon,
            color: purple,
            size: 25,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          category.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? purple : darkText,
            fontSize: 10.5,
            fontWeight: selected
                ? FontWeight.w700
                : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // LIST / MAP SWITCHER
  // ============================================================

  Widget _buildListMapSwitcher() {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: lightPurple,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: purple,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Center(
                child: Text(
                  'List',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                context.push(
                  '/health-facilities-map',
                );
              },
              child: const Center(
                child: Text(
                  'Map',
                  style: TextStyle(
                    color: darkText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FACILITY LIST
  // ============================================================

  Widget _buildFacilityList() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    final facilities = _filteredFacilities;

    if (facilities.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: facilities.map((facility) {
        return Padding(
          padding: const EdgeInsets.only(
            bottom: 12,
          ),
          child: _buildFacilityCard(facility),
        );
      }).toList(),
    );
  }

  // ============================================================
  // LOADING STATE
  // ============================================================

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 45,
      ),
      child: const Center(
        child: Column(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor:
                AlwaysStoppedAnimation<Color>(
                  purple,
                ),
              ),
            ),
            SizedBox(height: 15),
            Text(
              'Finding health facilities...',
              style: TextStyle(
                color: greyText,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 25,
        vertical: 35,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: lightPurple,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: purple,
              size: 28,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'Unable to load facilities',
            style: TextStyle(
              color: darkText,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Please check your connection and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: greyText,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 17),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: _loadFacilities,
              style: ElevatedButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(
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
  // FACILITY CARD
  // ============================================================

  Widget _buildFacilityCard(
      HealthFacility facility,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 76,
            decoration: BoxDecoration(
              color: facility.color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    facility.icon,
                    color: purple,
                    size: 34,
                  ),
                ),
                Positioned(
                  top: 7,
                  right: 7,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: purple,
                      size: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        facility.name,
                        maxLines: 2,
                        overflow:
                        TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: darkText,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: greyText,
                      size: 19,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: greyText,
                      size: 13,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        facility.location,
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: greyText,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration:
                      const BoxDecoration(
                        color: green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      facility.status,
                      style: const TextStyle(
                        color: green,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '• ${facility.openingHours}',
                        overflow:
                        TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: greyText,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: orange,
                      size: 14,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      facility.rating,
                      style: const TextStyle(
                        color: darkText,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        _showFacilityDetails(
                          facility,
                        );
                      },
                      child: Container(
                        padding:
                        const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: lightPurple,
                          borderRadius:
                          BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'View Details',
                          style: TextStyle(
                            color: purple,
                            fontSize: 8.5,
                            fontWeight:
                            FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 25,
        vertical: 40,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: lightPurple,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              color: purple,
              size: 28,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'No facilities found',
            style: TextStyle(
              color: darkText,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try another search or choose a different category.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: greyText,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FACILITY DETAILS
  // ============================================================

  void _showFacilityDetails(
      HealthFacility facility,
      ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(
            20,
            15,
            20,
            25,
          ),
          decoration: const BoxDecoration(
            color: background,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(25),
            ),
          ),
          child: SafeArea(
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
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: facility.color,
                        borderRadius:
                        BorderRadius.circular(15),
                      ),
                      child: Icon(
                        facility.icon,
                        color: purple,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            facility.name,
                            style: const TextStyle(
                              color: darkText,
                              fontSize: 16,
                              fontWeight:
                              FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            facility.category,
                            style: const TextStyle(
                              color: greyText,
                              fontSize: 11,
                              fontWeight:
                              FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDetailRow(
                  Icons.location_on_outlined,
                  'Location',
                  facility.location,
                ),
                const SizedBox(height: 13),
                _buildDetailRow(
                  Icons.map_outlined,
                  'State',
                  facility.state,
                ),
                const SizedBox(height: 13),
                _buildDetailRow(
                  Icons.access_time_rounded,
                  'Opening Hours',
                  facility.openingHours,
                ),
                const SizedBox(height: 13),
                _buildDetailRow(
                  Icons.star_outline_rounded,
                  'Rating',
                  facility.rating,
                ),
                if (facility.phone.trim().isNotEmpty) ...[
                  const SizedBox(height: 13),
                  _buildDetailRow(
                    Icons.phone_outlined,
                    'Phone',
                    facility.phone,
                  ),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);

                      ScaffoldMessenger.of(
                        this.context,
                      ).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Opening ${facility.name}',
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(13),
                      ),
                    ),
                    child: const Text(
                      'View Facility',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // DETAIL ROW
  // ============================================================

  Widget _buildDetailRow(
      IconData icon,
      String title,
      String value,
      ) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: lightPurple,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: purple,
            size: 18,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: greyText,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: darkText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomNavigationBar() {
    return SafeArea(
      top: false,
      child: Container(
        height: 76,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: borderColor,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _buildNavItem(
                icon: Icons.home_outlined,
                label: 'Home',
                onTap: () {
                  context.go('/home');
                },
              ),
            ),
            Expanded(
              child: _buildNavItem(
                icon: Icons.calendar_month_outlined,
                label: 'Schedule',
                onTap: () {
                  context.go('/appointments');
                },
              ),
            ),
            SizedBox(
              width: 76,
              height: 76,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    context.push(
                      '/medications/add',
                    );
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration:
                    const BoxDecoration(
                      color: purple,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 29,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _buildNavItem(
                icon:
                Icons.chat_bubble_outline_rounded,
                label: 'Messages',
                onTap: () {
                  context.go('/messages');
                },
              ),
            ),
            Expanded(
              child: _buildNavItem(
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                isSelected: true,
                onTap: () {
                  context.go('/profile');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM NAV ITEM
  // ============================================================

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 76,
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? purple
                  : greyText,
              size: 21,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected
                    ? purple
                    : greyText,
                fontSize: 9,
                fontWeight: isSelected
                    ? FontWeight.w700
                    : FontWeight.w500,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// HEALTH FACILITY MODEL
// ================================================================

class HealthFacility {
  final int? id;
  final String name;
  final String category;
  final String location;
  final String area;
  final String state;
  final String openingHours;
  final String status;
  final String rating;
  final IconData icon;
  final Color color;
  final double? latitude;
  final double? longitude;
  final String phone;

  const HealthFacility({
    this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.area,
    required this.state,
    required this.openingHours,
    required this.status,
    required this.rating,
    required this.icon,
    required this.color,
    this.latitude,
    this.longitude,
    required this.phone,
  });

  // ============================================================
  // CREATE FACILITY FROM SUPABASE
  // ============================================================

  factory HealthFacility.fromSupabase(
      Map<String, dynamic> data,
      ) {
    final String category = _normaliseCategory(
      data['category']?.toString() ?? '',
    );

    final IconData icon =
    _iconForCategory(category);

    final Color color =
    _colorForCategory(category);

    final dynamic ratingValue = data['rating'];

    String ratingText = '';

    if (ratingValue != null) {
      ratingText = ratingValue.toString();
    }

    return HealthFacility(
      id: data['id'] is int
          ? data['id'] as int
          : int.tryParse(
        data['id']?.toString() ?? '',
      ),
      name: data['name']?.toString() ?? '',
      category: category,
      location:
      data['location']?.toString() ?? '',
      area: data['area']?.toString() ?? '',
      state: data['state']?.toString() ?? '',
      openingHours:
      data['opening_hours']?.toString() ??
          'Hours not available',
      status:
      data['status']?.toString() ??
          'Status unavailable',
      rating: ratingText.isEmpty
          ? 'N/A'
          : ratingText,
      icon: icon,
      color: color,
      latitude: _toDouble(data['latitude']),
      longitude: _toDouble(data['longitude']),
      phone: data['phone']?.toString() ?? '',
    );
  }

  // ============================================================
  // CREATE FACILITY FROM SQLITE CACHE
  // ============================================================

  factory HealthFacility.fromOfflineMap(
      Map<String, dynamic> data,
      ) {
    final String category = _normaliseCategory(
      data['category']?.toString() ?? '',
    );

    final dynamic ratingValue = data['rating'];

    String ratingText = '';

    if (ratingValue != null) {
      ratingText = ratingValue.toString();
    }

    return HealthFacility(
      id: data['id'] is int
          ? data['id'] as int
          : int.tryParse(
        data['id']?.toString() ?? '',
      ),
      name: data['name']?.toString() ?? '',
      category: category,
      location:
      data['location']?.toString() ?? '',
      area: data['area']?.toString() ?? '',
      state: data['state']?.toString() ?? '',
      openingHours:
      data['opening_hours']?.toString() ??
          'Hours not available',
      status:
      data['status']?.toString() ??
          'Status unavailable',
      rating: ratingText.isEmpty
          ? 'N/A'
          : ratingText,
      icon: _iconForCategory(category),
      color: _colorForCategory(category),
      latitude: _toDouble(data['latitude']),
      longitude: _toDouble(data['longitude']),
      phone: data['phone']?.toString() ?? '',
    );
  }

  // ============================================================
  // CONVERT FACILITY TO SQLITE MAP
  // ============================================================

  Map<String, dynamic> toOfflineMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'location': location,
      'area': area,
      'state': state,
      'opening_hours': openingHours,
      'status': status,
      'rating': double.tryParse(rating),
      'latitude': latitude,
      'longitude': longitude,
      'phone': phone,
    };
  }

  // ============================================================
  // NORMALISE CATEGORY
  // ============================================================

  static String _normaliseCategory(
      String value,
      ) {
    final category =
    value.trim().toLowerCase();

    switch (category) {
      case 'hospital':
      case 'hospitals':
        return 'Hospitals';

      case 'clinic':
      case 'clinics':
        return 'Clinics';

      case 'pharmacy':
      case 'pharmacies':
        return 'Pharmacies';

      case 'laboratory':
      case 'laboratories':
      case 'lab':
      case 'labs':
        return 'Laboratories';

      default:
        return value.trim().isEmpty
            ? 'Hospitals'
            : value.trim();
    }
  }

  // ============================================================
  // ICON BY CATEGORY
  // ============================================================

  static IconData _iconForCategory(
      String category,
      ) {
    switch (category) {
      case 'Hospitals':
        return Icons.local_hospital_outlined;

      case 'Clinics':
        return Icons.medical_services_outlined;

      case 'Pharmacies':
        return Icons.medication_outlined;

      case 'Laboratories':
        return Icons.science_outlined;

      default:
        return Icons.local_hospital_outlined;
    }
  }

  // ============================================================
  // COLOR BY CATEGORY
  // ============================================================

  static Color _colorForCategory(
      String category,
      ) {
    switch (category) {
      case 'Hospitals':
        return const Color(0xFFEAE2FF);

      case 'Clinics':
        return const Color(0xFFE8F2FF);

      case 'Pharmacies':
        return const Color(0xFFE8F7F0);

      case 'Laboratories':
        return const Color(0xFFFFF2DD);

      default:
        return const Color(0xFFEAE2FF);
    }
  }

  // ============================================================
  // DOUBLE CONVERSION
  // ============================================================

  static double? _toDouble(
      dynamic value,
      ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }
}

// ================================================================
// CATEGORY MODEL
// ================================================================

class FacilityCategory {
  final String name;
  final IconData icon;

  const FacilityCategory({
    required this.name,
    required this.icon,
  });
}