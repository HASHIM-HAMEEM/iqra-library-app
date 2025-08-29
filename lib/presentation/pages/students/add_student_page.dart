import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'package:library_registration_app/core/utils/permission_service.dart';
import 'package:library_registration_app/core/utils/responsive_utils.dart';
import 'package:library_registration_app/core/services/image_compression_service.dart';
import 'package:library_registration_app/presentation/providers/students/students_notifier.dart';
import 'package:library_registration_app/presentation/providers/database_provider.dart';
import 'package:library_registration_app/presentation/widgets/common/custom_notification.dart';
import 'package:library_registration_app/presentation/widgets/common/async_avatar.dart';


class AddStudentPage extends ConsumerStatefulWidget {
  const AddStudentPage({super.key});

  @override
  ConsumerState<AddStudentPage> createState() => _AddStudentPageState();
}

class _AddStudentPageState extends ConsumerState<AddStudentPage> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  static const double _footerHeight = 80;

  // Personal Information Controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _seatNumberController = TextEditingController();

  DateTime? _selectedDate;

  File? _selectedImage;

  bool _isLoading = false;
  bool _isCompressingImage = false;
  String? _emailError;
  int _currentPage = 0;
  bool _dobError = false;
  bool _isCheckingEmail = false;
  Timer? _emailDebounce;

  // Subscription removed from Add flow: handled in Subscriptions screen after student creation

  double _footerTotalHeight(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return _footerHeight + safeBottom + 16;
  }

  EdgeInsets _pagePadding(BuildContext context) {
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    return EdgeInsets.fromLTRB(
      16,
      16,
      16,
      _footerTotalHeight(context) + keyboard,
    );
  }

  EdgeInsets _fieldScrollPadding(BuildContext context) {
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    return EdgeInsets.only(
      bottom: _footerTotalHeight(context) + keyboard + 120,
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _seatNumberController.dispose();
    // No subscription controllers in add flow
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(
    BuildContext context,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Select Date of Birth',
    );

    if (picked != null) {
      setState(() {
        _dobError = false;
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();

    unawaited(showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Library'),
                  onTap: () async {
                  Navigator.of(context).pop();
                  final granted =
                      await PermissionService.ensurePhotoLibraryPermission();
                  if (!granted) return;
                  final image = await picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (image != null) {
                    await _saveImage(image);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                  onTap: () async {
                  Navigator.of(context).pop();
                  final granted =
                      await PermissionService.ensureCameraPermission();
                  if (!granted) return;
                  final image = await picker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (image != null) {
                    await _saveImage(image);
                  }
                },
              ),
              if (_selectedImage != null)
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text('Remove Photo'),
                  onTap: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _selectedImage = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    ));
  }

  Future<void> _saveImage(XFile image) async {
    setState(() => _isCompressingImage = true);

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${path.basename(image.path)}';
      final savedPath = path.join(
        appDir.path,
        'profile_images',
        fileName,
      );

      // Create directory if it doesn't exist
      final profileDir = Directory(path.dirname(savedPath));
      if (!await profileDir.exists()) {
        await profileDir.create(recursive: true);
      }

      // Copy original image first
      final tempImage = await File(image.path).copy(savedPath);

      // Compress the image
      File compressedImage;
      try {
        compressedImage = await ImageCompressionService.compressImage(tempImage);
      } catch (e) {
        // Check if this is our custom ImageTooLargeException
        if (e is ImageTooLargeException) {
          if (mounted) {
            CustomNotification.show(
              context,
              message: 'Image is too large (max ${ImageCompressionService.maxFileSizeMB}MB). ${e.message}',
              type: NotificationType.error,
            );
          }
          return;
        }
        // If compression fails, try to use original but still validate size
        final isValidSize = await ImageCompressionService.validateImageSize(tempImage);
        if (!isValidSize) {
          final fileSize = await tempImage.length();
          if (mounted) {
            CustomNotification.show(
              context,
              message: 'Image is too large (max ${ImageCompressionService.maxFileSizeMB}MB). Current size: ${ImageCompressionService.formatFileSize(fileSize)}',
              type: NotificationType.error,
            );
          }
          return;
        }
        compressedImage = tempImage;
      }

      // Show compression success message if image was actually compressed
      final originalSize = await tempImage.length();
      final compressedSize = await compressedImage.length();
      if (originalSize != compressedSize && mounted) {
        final savings = ((originalSize - compressedSize) / originalSize * 100).round();
        CustomNotification.show(
          context,
          message: 'Image optimized! Size reduced by $savings% (${ImageCompressionService.formatFileSize(originalSize)} → ${ImageCompressionService.formatFileSize(compressedSize)})',
          type: NotificationType.success,
        );
      }

      setState(() {
        _selectedImage = compressedImage;
      });
    } catch (e) {
      if (mounted) {
        CustomNotification.show(
          context,
          message: 'Error processing image: $e',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCompressingImage = false);
      }
    }
  }

  Future<void> _checkEmailExists() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _emailError = null;
        _isCheckingEmail = false;
      });
      return;
    }

    try {
      setState(() => _isCheckingEmail = true);
      final exists = await ref
          .read(studentsNotifierProvider.notifier)
          .isEmailExists(email);
      setState(() {
        _emailError = exists ? 'Email already exists' : null;
        _isCheckingEmail = false;
      });
    } catch (e) {
      setState(() {
        _emailError = null;
        _isCheckingEmail = false;
      });
    }
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) {
      // Build a friendly summary of issues
      final issues = <String>[];
      if (_firstNameController.text.trim().isEmpty) {
        issues.add('First name is required');
      }
      if (_lastNameController.text.trim().isEmpty) {
        issues.add('Last name is required');
      }
      final emailErr = _validateEmail(_emailController.text);
      if (emailErr != null) {
        issues.add(emailErr);
      }
      final phoneErr = _validatePhone(_phoneController.text);
      if (phoneErr != null) {
        issues.add(phoneErr);
      }
      if (_selectedDate == null) {
        issues.add('Date of birth is required');
      }
      if (issues.isNotEmpty) {
        CustomNotification.show(
          context,
          message: 'Please fix the following issues:\n• ${issues.join('\n• ')}',
          type: NotificationType.error,
        );
      }
      // Navigate to the personal info page for corrections
      unawaited(_pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ));
      return;
    }

    if (_selectedDate == null) {
      setState(() => _dobError = true);
      unawaited(_pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ));
      return;
    }

    // Subscription fields are removed in Add flow; no validation here

    if (_emailError != null) {
      CustomNotification.show(
        context,
        message: _emailError!,
        type: NotificationType.error,
      );
      unawaited(_pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final studentId = await ref
          .read(studentsNotifierProvider.notifier)
          .createStudent(
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            dateOfBirth: _selectedDate!,
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            address: _addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim(),
            seatNumber: _seatNumberController.text.trim().isEmpty
                ? null
                : _seatNumberController.text.trim(),
            profileImagePath: null, // will be set after uploading to storage
            subscriptionPlan: null,
            subscriptionStartDate: null,
            subscriptionEndDate: null,
            subscriptionAmount: null,
            subscriptionStatus: null,
          );
      // If there is a local photo, upload to Supabase Storage and update student row with public URL
      if (studentId != null && _selectedImage != null) {
        try {
          final supabase = ref.read(supabaseServiceProvider);
          final publicUrl = await supabase.uploadProfileImage(
            studentId: studentId,
            file: _selectedImage!,
          );
          await supabase.updateStudentProfileImage(studentId, publicUrl);
        } catch (e) {
          // Non-fatal: keep going even if image upload fails
          if (mounted) {
            CustomNotification.show(
              context,
              message: 'Student added, but profile image upload failed: $e',
              type: NotificationType.warning,
            );
          }
        }
      }

      if (mounted && studentId != null) {
        CustomNotification.show(
          context,
          message: 'Student added successfully. You can add a subscription from the Subscriptions screen.',
          type: NotificationType.success,
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        // Show specific error message for authentication/database issues
        String errorMessage;
        if (e.toString().contains('must be signed in') || 
            e.toString().contains('session has expired') ||
            e.toString().contains('not properly configured')) {
          errorMessage = e.toString();
        } else {
          errorMessage = 'Could not add student. Please check your inputs and try again.';
        }
        
        CustomNotification.show(
          context,
          message: errorMessage,
          type: e.toString().contains('must be signed in') || 
                e.toString().contains('session has expired') || 
                e.toString().contains('not properly configured') 
                ? NotificationType.warning : NotificationType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }

    return _emailError;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Phone is optional
    }

    final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length != 10) {
      return 'Phone number must be 10 digits';
    }

    return null;
  }

  // Amount validation removed from Add flow (no amount field here)

  void _nextPage() {
    // Only advance from page 0 -> 1 (there are exactly 2 pages now)
    if (_currentPage == 0) {
      final bool ok = _formKey.currentState?.validate() ?? false;
      if (_selectedDate == null) {
        setState(() => _dobError = true);
      }
      if (!ok || _selectedDate == null) {
        return;
      }
      unawaited(_pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ));
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      unawaited(_pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ));
    }
  }

  Widget _buildModernHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Student',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                ),
              ),
              Text(
                'Create new student profile',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          TextButton(
            onPressed: _saveStudent,
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(context).unfocus(),
              child: CustomScrollView(
                slivers: [
                  // Modern Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: ResponsiveUtils.getResponsivePadding(context).copyWith(top: 8),
                      child: _buildModernHeader(context),
                    ),
                  ),
                  
                  // Form Content
                  SliverFillRemaining(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Container(
                            color: Theme.of(context).colorScheme.surface,
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: (_currentPage + 1) / 2,
                                     backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                 Text(
                                   '${_currentPage + 1} of 2',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentPage = index;
                          });
                        },
                        children: [
                          _buildPersonalInfoPage(),
                          _buildProfilePhotoPage(),
                        ],
                      ),
                    ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                color: Theme.of(context).colorScheme.surface,
                padding: const EdgeInsets.all(16),
                height: _footerHeight,
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _previousPage,
                          child: const Text('Previous'),
                        ),
                      ),
                    if (_currentPage > 0) const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : (_currentPage == 0 ? _nextPage : _saveStudent),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(_currentPage == 0 ? 'Next' : 'Save Details'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoPage() {
    return ListView(
      padding: _pagePadding(context),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Text(
          'Personal Information',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),

        // First Name
        TextFormField(
          controller: _firstNameController,
          decoration: const InputDecoration(
            labelText: 'First Name *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
          ),
          textCapitalization: TextCapitalization.words,
          scrollPadding: _fieldScrollPadding(context),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) => _validateRequired(value, 'First name'),
        ),
        const SizedBox(height: 16),

        // Last Name
        TextFormField(
          controller: _lastNameController,
          decoration: const InputDecoration(
            labelText: 'Last Name *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
          ),
          textCapitalization: TextCapitalization.words,
          scrollPadding: _fieldScrollPadding(context),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) => _validateRequired(value, 'Last name'),
        ),
        const SizedBox(height: 16),

        // Date of Birth
        InkWell(
          onTap: () => _selectDate(context),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Date of Birth *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_today),
            ),
            child: Text(
              _selectedDate == null
                  ? 'Select date of birth'
                  : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
              style: TextStyle(
                color: _selectedDate == null
                    ? (_dobError ? Theme.of(context).colorScheme.error : Theme.of(context).hintColor)
                    : Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ),
        if (_dobError)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Date of birth is required',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),

        // Email
        TextFormField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: 'Email *',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.email_outlined),
            errorText: _emailError,
            suffixIcon: _isCheckingEmail
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          keyboardType: TextInputType.emailAddress,
          scrollPadding: _fieldScrollPadding(context),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: _validateEmail,
          onChanged: (value) {
            if (_emailError != null) {
              setState(() {
                _emailError = null;
              });
            }
            _emailDebounce?.cancel();
            _emailDebounce = Timer(const Duration(milliseconds: 400), _checkEmailExists);
          },
          onFieldSubmitted: (value) => _checkEmailExists(),
        ),
        const SizedBox(height: 16),

        // Phone
        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Phone',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone_outlined),
            helperText: 'Optional',
          ),
          keyboardType: TextInputType.phone,
          scrollPadding: _fieldScrollPadding(context),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: _validatePhone,
        ),
        const SizedBox(height: 16),

        // Address
        TextFormField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: 'Address',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_on_outlined),
            helperText: 'Optional',
          ),
          maxLines: 3,
          scrollPadding: _fieldScrollPadding(context),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 16),

        // Seat Number (optional)
        TextFormField(
          controller: _seatNumberController,
          decoration: const InputDecoration(
            labelText: 'Seat Number',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.event_seat_outlined),
            helperText: 'Optional (e.g., A12)',
          ),
          textCapitalization: TextCapitalization.characters,
          scrollPadding: _fieldScrollPadding(context),
        ),
      ],
    );
  }

  Widget _buildProfilePhotoPage() {
    return ListView(
      padding: _pagePadding(context),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Text(
          'Profile Photo',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),

        Center(
          child: Column(
            children: [
                              Stack(
                  children: [
                    // Show selected image immediately if present
                    if (_selectedImage != null)
                      ClipOval(
                        child: Image.file(
                          _selectedImage!,
                          width: 160,
                          height: 160,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      AsyncAvatar(
                        imagePath: null, // new student; no stored path yet
                        initials: (
                          (_firstNameController.text.trim().isNotEmpty || _lastNameController.text.trim().isNotEmpty)
                            ? (_firstNameController.text.trim() + ' ' + _lastNameController.text.trim())
                                .trim()
                                .split(RegExp(r"\s+"))
                                .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
                                .take(2)
                                .join()
                            : '?'
                        ),
                        size: 160,
                        fallbackIcon: Icons.person,
                      ),
                    // Loading overlay for image compression
                    if (_isCompressingImage)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.camera_alt,
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 24,
                          ),
                          onPressed: _isCompressingImage ? null : _pickImage,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),

              Text(
                'Add a profile photo for the student',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              Text(
                'This is optional but helps identify the student',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_a_photo),
                label: Text(
                  _selectedImage == null ? 'Add Photo' : 'Change Photo',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Removed: subscription page; handled after student creation
}
