import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'health_information_screen.dart';

class EditHealthInformationScreen extends StatefulWidget {
  final HealthInformation healthInformation;

  const EditHealthInformationScreen({
    super.key,
    required this.healthInformation,
  });

  @override
  State<EditHealthInformationScreen> createState() =>
      _EditHealthInformationScreenState();
}

class _EditHealthInformationScreenState
    extends State<EditHealthInformationScreen> {
  // ---------------------------------------------------------------------------
  // COLORS
  // ---------------------------------------------------------------------------

  static const Color medNovaPurple = Color(0xFF6C3CE9);
  static const Color lightPurple = Color(0xFFF0EAFF);
  static const Color darkText = Color(0xFF29263A);
  static const Color greyText = Color(0xFF777383);
  static const Color background = Color(0xFFF9F7FC);

  // ---------------------------------------------------------------------------
  // SUPABASE
  // ---------------------------------------------------------------------------

  final SupabaseClient supabase = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // FORM CONTROLLERS
  // ---------------------------------------------------------------------------

  late final TextEditingController fullNameController;
  late final TextEditingController dateOfBirthController;
  late final TextEditingController allergiesController;
  late final TextEditingController currentMedicationsController;
  late final TextEditingController medicalConditionsController;
  late final TextEditingController medicalHistoryController;
  late final TextEditingController healthcareProviderController;

  String selectedGender = '';
  String selectedBloodGroup = '';

  // ---------------------------------------------------------------------------
  // PHOTO
  // ---------------------------------------------------------------------------

  final ImagePicker _imagePicker = ImagePicker();

  File? selectedImage;
  String? profilePhotoUrl;

  bool isUploadingPhoto = false;
  bool isSaving = false;

  // ---------------------------------------------------------------------------
  // INIT
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    fullNameController = TextEditingController(
      text: widget.healthInformation.fullName,
    );

    dateOfBirthController = TextEditingController(
      text: widget.healthInformation.dateOfBirth,
    );

    allergiesController = TextEditingController(
      text: widget.healthInformation.allergies,
    );

    currentMedicationsController = TextEditingController(
      text: widget.healthInformation.currentMedications,
    );

    medicalConditionsController = TextEditingController(
      text: widget.healthInformation.medicalConditions,
    );

    medicalHistoryController = TextEditingController(
      text: widget.healthInformation.medicalHistory,
    );

    healthcareProviderController = TextEditingController(
      text: widget.healthInformation.healthcareProvider,
    );

    selectedGender = widget.healthInformation.gender.isNotEmpty
        ? widget.healthInformation.gender
        : 'Female';

    selectedBloodGroup = widget.healthInformation.bloodGroup.isNotEmpty
        ? widget.healthInformation.bloodGroup
        : 'O+';

    _loadProfilePhoto();
  }

  // ---------------------------------------------------------------------------
  // LOAD PROFILE PHOTO
  // ---------------------------------------------------------------------------

  Future<void> _loadProfilePhoto() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) return;

      final response = await supabase
          .from('profiles')
          .select('profile_photo_url')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        profilePhotoUrl = response?['profile_photo_url'] as String?;
      });
    } catch (e) {
      debugPrint('Error loading profile photo: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // SHOW PHOTO OPTIONS
  // ---------------------------------------------------------------------------

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 45,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 22),

                const Text(
                  'Change Profile Photo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkText,
                  ),
                ),

                const SizedBox(height: 20),

                // TAKE PHOTO
                ListTile(
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: lightPurple,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: medNovaPurple,
                    ),
                  ),
                  title: const Text(
                    'Take a Photo',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: darkText,
                    ),
                  ),
                  subtitle: const Text(
                    'Use your camera',
                    style: TextStyle(
                      color: greyText,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _takePhoto();
                  },
                ),

                const SizedBox(height: 8),

                // GALLERY
                ListTile(
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: lightPurple,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.photo_library_outlined,
                      color: medNovaPurple,
                    ),
                  ),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: darkText,
                    ),
                  ),
                  subtitle: const Text(
                    'Select a photo from your device',
                    style: TextStyle(
                      color: greyText,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _chooseFromGallery();
                  },
                ),

                const SizedBox(height: 10),

                // CANCEL
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: medNovaPurple,
                      fontWeight: FontWeight.w600,
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

  // ---------------------------------------------------------------------------
  // TAKE PHOTO
  // ---------------------------------------------------------------------------

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (image == null) return;

      final file = File(image.path);

      setState(() {
        selectedImage = file;
      });

      await _uploadProfilePhoto(file);
    } catch (e) {
      _showMessage(
        'Unable to access the camera. Please check your camera permission.',
        isError: true,
      );

      debugPrint('Camera error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // CHOOSE FROM GALLERY
  // ---------------------------------------------------------------------------

  Future<void> _chooseFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (image == null) return;

      final file = File(image.path);

      setState(() {
        selectedImage = file;
      });

      await _uploadProfilePhoto(file);
    } catch (e) {
      _showMessage(
        'Unable to open your gallery. Please check your permissions.',
        isError: true,
      );

      debugPrint('Gallery error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // UPLOAD PHOTO TO SUPABASE STORAGE
  // ---------------------------------------------------------------------------

  Future<void> _uploadProfilePhoto(File file) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      _showMessage(
        'Please log in again before changing your photo.',
        isError: true,
      );
      return;
    }

    setState(() {
      isUploadingPhoto = true;
    });

    try {
      final String filePath =
          '${user.id}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Upload the image to Supabase Storage.
      await supabase.storage.from('profile-photos').upload(
        filePath,
        file,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: false,
        ),
      );

      // Get the public URL.
      final String publicUrl = supabase.storage
          .from('profile-photos')
          .getPublicUrl(filePath);

      // Save the URL in the user's profile.
      await supabase
          .from('profiles')
          .update({
        'profile_photo_url': publicUrl,
      })
          .eq('id', user.id);

      if (!mounted) return;

      setState(() {
        profilePhotoUrl = publicUrl;
        isUploadingPhoto = false;
      });

      _showMessage(
        'Profile photo updated successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isUploadingPhoto = false;
      });

      _showMessage(
        'Could not upload your photo. Please try again.',
        isError: true,
      );

      debugPrint('Profile photo upload error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // SAVE HEALTH INFORMATION
  // ---------------------------------------------------------------------------

  Future<void> _saveChanges() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      _showMessage(
        'Please log in again.',
        isError: true,
      );
      return;
    }

    if (fullNameController.text.trim().isEmpty) {
      _showMessage(
        'Please enter your full name.',
        isError: true,
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await supabase
          .from('profiles')
          .update({
        'full_name': fullNameController.text.trim(),
        'date_of_birth': dateOfBirthController.text.trim(),
        'gender': selectedGender,
        'blood_group': selectedBloodGroup,
        'allergies': allergiesController.text.trim(),
        'current_medications':
        currentMedicationsController.text.trim(),
        'medical_conditions':
        medicalConditionsController.text.trim(),
        'medical_history': medicalHistoryController.text.trim(),
        'healthcare_provider':
        healthcareProviderController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', user.id);

      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      _showMessage(
        'Health information updated successfully.',
      );

      await Future.delayed(const Duration(milliseconds: 700));

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      _showMessage(
        'Unable to save your information. Please try again.',
        isError: true,
      );

      debugPrint('Save health information error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // MESSAGE
  // ---------------------------------------------------------------------------

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : medNovaPurple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TEXT FIELD
  // ---------------------------------------------------------------------------

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: darkText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 8),

        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(
            color: darkText,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: greyText,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: medNovaPurple,
                width: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // DROPDOWN
  // ---------------------------------------------------------------------------

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: darkText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : null,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: greyText,
              ),
              hint: Text(
                'Select $label',
                style: const TextStyle(
                  color: greyText,
                  fontSize: 14,
                ),
              ),
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    style: const TextStyle(
                      color: darkText,
                      fontSize: 14,
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PROFILE PHOTO WIDGET
  // ---------------------------------------------------------------------------

  Widget _buildProfilePhoto() {
    ImageProvider? imageProvider;

    if (selectedImage != null) {
      imageProvider = FileImage(selectedImage!);
    } else if (profilePhotoUrl != null &&
        profilePhotoUrl!.trim().isNotEmpty) {
      imageProvider = NetworkImage(profilePhotoUrl!);
    }

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 108,
          height: 108,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: lightPurple,
            border: Border.all(
              color: Colors.white,
              width: 4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
            image: imageProvider != null
                ? DecorationImage(
              image: imageProvider,
              fit: BoxFit.cover,
            )
                : null,
          ),
          child: imageProvider == null
              ? const Icon(
            Icons.person_outline_rounded,
            size: 52,
            color: medNovaPurple,
          )
              : null,
        ),

        GestureDetector(
          onTap: isUploadingPhoto ? null : _showPhotoOptions,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: medNovaPurple,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
            ),
            child: isUploadingPhoto
                ? const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : const Icon(
              Icons.camera_alt_rounded,
              size: 17,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: darkText,
            size: 20,
          ),
        ),
        title: const Text(
          'Edit Health Information',
          style: TextStyle(
            color: darkText,
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ----------------------------------------------------------------
              // PROFILE PHOTO
              // ----------------------------------------------------------------

              Center(
                child: Column(
                  children: [
                    _buildProfilePhoto(),

                    const SizedBox(height: 12),

                    GestureDetector(
                      onTap:
                      isUploadingPhoto ? null : _showPhotoOptions,
                      child: const Text(
                        'Change Photo',
                        style: TextStyle(
                          color: medNovaPurple,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    if (isUploadingPhoto) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Uploading photo...',
                        style: TextStyle(
                          color: greyText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ----------------------------------------------------------------
              // PERSONAL INFORMATION
              // ----------------------------------------------------------------

              const Text(
                'Personal Information',
                style: TextStyle(
                  color: darkText,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 18),

              _buildTextField(
                label: 'Full Name',
                controller: fullNameController,
                hint: 'Enter your full name',
              ),

              const SizedBox(height: 18),

              _buildTextField(
                label: 'Date of Birth',
                controller: dateOfBirthController,
                hint: 'DD/MM/YYYY',
              ),

              const SizedBox(height: 18),

              _buildDropdown(
                label: 'Gender',
                value: selectedGender,
                items: const [
                  'Female',
                  'Male',
                  'Other',
                ],
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    selectedGender = value;
                  });
                },
              ),

              const SizedBox(height: 18),

              _buildDropdown(
                label: 'Blood Group',
                value: selectedBloodGroup,
                items: const [
                  'A+',
                  'A-',
                  'B+',
                  'B-',
                  'AB+',
                  'AB-',
                  'O+',
                  'O-',
                ],
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    selectedBloodGroup = value;
                  });
                },
              ),

              const SizedBox(height: 30),

              // ----------------------------------------------------------------
              // MEDICAL INFORMATION
              // ----------------------------------------------------------------

              const Text(
                'Medical Information',
                style: TextStyle(
                  color: darkText,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 18),

              _buildTextField(
                label: 'Allergies',
                controller: allergiesController,
                hint: 'e.g. Penicillin, peanuts',
                maxLines: 2,
              ),

              const SizedBox(height: 18),

              _buildTextField(
                label: 'Current Medications',
                controller: currentMedicationsController,
                hint: 'List your current medications',
                maxLines: 2,
              ),

              const SizedBox(height: 18),

              _buildTextField(
                label: 'Medical Conditions',
                controller: medicalConditionsController,
                hint: 'e.g. Asthma, diabetes',
                maxLines: 2,
              ),

              const SizedBox(height: 18),

              _buildTextField(
                label: 'Medical History',
                controller: medicalHistoryController,
                hint: 'Tell us about your medical history',
                maxLines: 3,
              ),

              const SizedBox(height: 18),

              _buildTextField(
                label: 'Healthcare Provider',
                controller: healthcareProviderController,
                hint: 'Your doctor or healthcare provider',
              ),

              const SizedBox(height: 32),

              // ----------------------------------------------------------------
              // SAVE BUTTON
              // ----------------------------------------------------------------

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: medNovaPurple,
                    disabledBackgroundColor:
                    medNovaPurple.withOpacity(0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                    width: 23,
                    height: 23,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  )
                      : const Text(
                    'Save Changes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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

  // ---------------------------------------------------------------------------
  // DISPOSE
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    fullNameController.dispose();
    dateOfBirthController.dispose();
    allergiesController.dispose();
    currentMedicationsController.dispose();
    medicalConditionsController.dispose();
    medicalHistoryController.dispose();
    healthcareProviderController.dispose();

    super.dispose();
  }
}