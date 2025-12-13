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

  @override
  void dispose() {
    _emailDebounce?.cancel();
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

  Future<void> _selectDate(BuildContext context) async {
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

    unawaited(
      showModalBottomSheet<void>(
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
      ),
    );
  }

  Future<void> _saveImage(XFile image) async {
    setState(() => _isCompressingImage = true);

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${path.basename(image.path)}';
      final savedPath = path.join(appDir.path, 'profile_images', fileName);

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
        compressedImage = await ImageCompressionService.compressImage(
          tempImage,
        );
      } catch (e) {
        // Check if this is our custom ImageTooLargeException
        if (e is ImageTooLargeException) {
          if (mounted) {
            CustomNotification.show(
              context,
              message:
                  'Image is too large (max ${ImageCompressionService.maxFileSizeMB}MB). ${e.message}',
              type: NotificationType.error,
            );
          }
          return;
        }
        // If compression fails, try to use original but still validate size
        final isValidSize = await ImageCompressionService.validateImageSize(
          tempImage,
        );
        if (!isValidSize) {
          final fileSize = await tempImage.length();
          if (mounted) {
            CustomNotification.show(
              context,
              message:
                  'Image is too large (max ${ImageCompressionService.maxFileSizeMB}MB). Current size: ${ImageCompressionService.formatFileSize(fileSize)}',
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
        final savings = ((originalSize - compressedSize) / originalSize * 100)
            .round();
        CustomNotification.show(
          context,
          message:
              'Image optimized! Size reduced by $savings% (${ImageCompressionService.formatFileSize(originalSize)} → ${ImageCompressionService.formatFileSize(compressedSize)})',
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
      unawaited(
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ),
      );
      return;
    }

    if (_selectedDate == null) {
      setState(() => _dobError = true);
      unawaited(
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ),
      );
      return;
    }

    // Subscription fields are removed in Add flow; no validation here

    if (_emailError != null) {
      CustomNotification.show(
        context,
        message: _emailError!,
        type: NotificationType.error,
      );
      unawaited(
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ),
      );
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
          message:
              'Student added successfully. You can add a subscription from the Subscriptions screen.',
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
          errorMessage =
              'Could not add student. Please check your inputs and try again.';
        }

        CustomNotification.show(
          context,
          message: errorMessage,
          type:
              e.toString().contains('must be signed in') ||
                  e.toString().contains('session has expired') ||
                  e.toString().contains('not properly configured')
              ? NotificationType.warning
              : NotificationType.error,
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
      unawaited(
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ),
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      unawaited(
        _pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ),
      );
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
    final theme = Theme.of(context);
    // isMobile unused variable removed

    // Calculate progress (0.0 to 1.0)
    final double progress = (_currentPage + 1) / 2;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          // Background Gradient decoration (subtle)
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.05),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(context).unfocus(),
              child: CustomScrollView(
                slivers: [
                  // Modern Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: ResponsiveUtils.getResponsivePadding(
                        context,
                      ).copyWith(top: 8, bottom: 0),
                      child: _buildModernHeader(context),
                    ),
                  ),

                  // Progress Indicator
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Step ${_currentPage + 1} of 2',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Form Content (PageView within CustomScrollView tricky, usually needs fixed height)
                  // For better UX, we'll use SliverFillRemaining to fill space
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Form(
                      key: _formKey,
                      child: SizedBox(
                        // Explicit height for PageView inside scroll view if needed,
                        // but SliverFillRemaining creates constraints.
                        // However, PageView usually needs bounded height.
                        // Let's use Expanded logic carefully.
                        height: MediaQuery.of(context).size.height - 200,
                        child: PageView(
                          controller: _pageController,
                          physics:
                              const NeverScrollableScrollPhysics(), // Managed navigation
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
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.95),
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _previousPage,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(
                              color: theme.colorScheme.outlineVariant,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Previous'),
                        ),
                      ),
                    if (_currentPage > 0) const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _isLoading
                            ? null
                            : (_currentPage == 0 ? _nextPage : _saveStudent),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              )
                            : Text(
                                _currentPage == 0
                                    ? 'Next Step'
                                    : 'Create Student',
                                style: const TextStyle(
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
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personal Information',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the student\'s basic details',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // First Name
        _buildModernTextField(
          controller: _firstNameController,
          label: 'First Name',
          icon: Icons.person_outline_rounded,
          textCapitalization: TextCapitalization.words,
          validator: (value) => _validateRequired(value, 'First name'),
          isRequired: true,
        ),
        const SizedBox(height: 20),

        // Last Name
        _buildModernTextField(
          controller: _lastNameController,
          label: 'Last Name',
          icon: Icons.person_outline_rounded,
          textCapitalization: TextCapitalization.words,
          validator: (value) => _validateRequired(value, 'Last name'),
          isRequired: true,
        ),
        const SizedBox(height: 20),

        // Date of Birth
        InkWell(
          onTap: () => _selectDate(context),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _dobError
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Date of Birth',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '*',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedDate == null
                          ? 'Select date'
                          : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: _selectedDate == null
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5)
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: _selectedDate == null
                            ? FontWeight.normal
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_dobError)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 16),
            child: Text(
              'Date of birth is required',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        const SizedBox(height: 20),

        // Email
        _buildModernTextField(
          controller: _emailController,
          label: 'Email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: _validateEmail,
          isRequired: true,
          errorText: _emailError,
          suffixIcon: _isCheckingEmail
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
          onChanged: (value) {
            if (_emailError != null) {
              setState(() => _emailError = null);
            }
            _emailDebounce?.cancel();
            _emailDebounce = Timer(
              const Duration(milliseconds: 400),
              _checkEmailExists,
            );
          },
          onFieldSubmitted: (_) => _checkEmailExists(),
        ),
        const SizedBox(height: 20),

        // Phone
        _buildModernTextField(
          controller: _phoneController,
          label: 'Phone',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          validator: _validatePhone,
          helperText: 'Optional',
        ),
        const SizedBox(height: 20),

        // Address
        _buildModernTextField(
          controller: _addressController,
          label: 'Address',
          icon: Icons.location_on_outlined,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          helperText: 'Optional',
        ),
        const SizedBox(height: 20),

        // Seat Number
        _buildModernTextField(
          controller: _seatNumberController,
          label: 'Seat Number',
          icon: Icons.event_seat_outlined,
          textCapitalization: TextCapitalization.characters,
          helperText: 'Optional (e.g. A12)',
        ),

        // Extra padding at bottom for FAB/Footer
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
    bool isRequired = false,
    String? errorText,
    String? helperText,
    int maxLines = 1,
    Widget? suffixIcon,
    void Function(String)? onChanged,
    void Function(String)? onFieldSubmitted,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        labelStyle: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
        floatingLabelStyle: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.3,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.error),
        ),
        errorText: errorText,
        helperText: helperText,
        contentPadding: const EdgeInsets.all(16),
      ),
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      maxLines: maxLines,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }

  Widget _buildProfilePhotoPage() {
    final theme = Theme.of(context);
    return ListView(
      padding: _pagePadding(context),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile Photo',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add a photo to easily identify the student',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: _isCompressingImage ? null : _pickImage,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.shadowColor.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Image or Fallback
                      if (_selectedImage != null)
                        ClipOval(
                          child: Image.file(
                            _selectedImage!,
                            width: 192,
                            height: 192,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        AsyncAvatar(
                          imagePath: null,
                          initials:
                              ((_firstNameController.text.trim().isNotEmpty ||
                                  _lastNameController.text.trim().isNotEmpty)
                              ? (_firstNameController.text.trim() +
                                        ' ' +
                                        _lastNameController.text.trim())
                                    .trim()
                                    .split(RegExp(r"\s+"))
                                    .map(
                                      (e) => e.isNotEmpty
                                          ? e[0].toUpperCase()
                                          : '',
                                    )
                                    .take(2)
                                    .join()
                              : '?'),
                          size: 192,
                          fallbackIcon: Icons.person_rounded,
                          backgroundColor: theme
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          foregroundColor: theme.colorScheme.primary,
                        ),

                      // Loading Overlay
                      if (_isCompressingImage)
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        ),

                      // Camera Icon Badge
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.4,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: theme.colorScheme.surface,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            _selectedImage == null
                                ? Icons.add_a_photo_rounded
                                : Icons.edit_rounded,
                            color: theme.colorScheme.onPrimary,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              if (_selectedImage == null) ...[
                Text(
                  'No photo selected',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    'Tap the circle above to take a new photo or choose from your library',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ] else ...[
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedImage = null;
                    });
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Remove Photo'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Removed: subscription page; handled after student creation
}
