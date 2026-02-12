import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:library_registration_app/core/services/image_compression_service.dart';
import 'package:library_registration_app/core/theme/design_tokens.dart';
import 'package:library_registration_app/core/utils/permission_service.dart';
import 'package:library_registration_app/presentation/providers/database_provider.dart';
import 'package:library_registration_app/presentation/providers/students/students_notifier.dart';
import 'package:library_registration_app/presentation/widgets/common/app_bottom_sheet.dart';
import 'package:library_registration_app/presentation/widgets/common/async_avatar.dart';
import 'package:library_registration_app/presentation/widgets/common/custom_notification.dart';
import 'package:library_registration_app/presentation/widgets/common/page_header.dart';

class AddStudentPage extends ConsumerStatefulWidget {
  const AddStudentPage({super.key});

  @override
  ConsumerState<AddStudentPage> createState() => _AddStudentPageState();
}

class _AddStudentPageState extends ConsumerState<AddStudentPage> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();

  // Personal Information Controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _seatNumberController = TextEditingController();

  DateTime? _selectedDate;

  Uint8List? _selectedImageBytes;
  String _selectedImageExtension = 'jpg';
  String? _selectedImageMimeType;

  bool _isLoading = false;
  bool _isCompressingImage = false;
  String? _emailError;
  int _currentPage = 0;
  bool _dobError = false;
  bool _isCheckingEmail = false;
  Timer? _emailDebounce;

  // Subscription removed from Add flow: handled in Subscriptions screen after student creation

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

  bool get _hasUnsavedChanges {
    return _firstNameController.text.trim().isNotEmpty ||
        _lastNameController.text.trim().isNotEmpty ||
        _emailController.text.trim().isNotEmpty ||
        _phoneController.text.trim().isNotEmpty ||
        _addressController.text.trim().isNotEmpty ||
        _seatNumberController.text.trim().isNotEmpty ||
        _selectedDate != null ||
        _selectedImageBytes != null;
  }

  Future<void> _onRequestExit() async {
    if (_isLoading) return;
    if (!_hasUnsavedChanges) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved changes in this form. Do you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if ((shouldDiscard ?? false) && mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget _wrapWithDiscardGuard(Widget child) {
    return PopScope(
      canPop: !_hasUnsavedChanges || _isLoading,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_onRequestExit());
      },
      child: child,
    );
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
      showAppBottomSheet<void>(
        context,
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
                if (_selectedImageBytes != null)
                  ListTile(
                    leading: const Icon(Icons.delete),
                    title: const Text('Remove Photo'),
                    onTap: () {
                      Navigator.of(context).pop();
                      setState(() {
                        _selectedImageBytes = null;
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
      final originalBytes = await image.readAsBytes();

      // Compress the image
      Uint8List compressedImage;
      try {
        compressedImage = await ImageCompressionService.compressImageData(
          originalBytes,
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
        final isValidSize = ImageCompressionService.validateImageSizeBytes(
          originalBytes,
        );
        if (!isValidSize) {
          final fileSize = originalBytes.length;
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
        compressedImage = originalBytes;
      }

      // Show compression success message if image was actually compressed
      final originalSize = originalBytes.length;
      final compressedSize = compressedImage.length;
      if (originalSize != compressedSize && mounted) {
        final savings = ((originalSize - compressedSize) / originalSize * 100)
            .round();
        CustomNotification.show(
          context,
          message:
              'Image optimized! Size reduced by $savings% (${ImageCompressionService.formatFileSize(originalSize)} → ${ImageCompressionService.formatFileSize(compressedSize)})',
        );
      }

      setState(() {
        _selectedImageBytes = compressedImage;
        final fileName = image.name.isNotEmpty ? image.name : image.path;
        final dot = fileName.lastIndexOf('.');
        final fallbackExt = dot >= 0
            ? fileName.substring(dot + 1).toLowerCase()
            : 'jpg';
        _selectedImageExtension = ImageCompressionService.detectFileExtension(
          compressedImage,
          fallback: fallbackExt,
        );
        _selectedImageMimeType = ImageCompressionService.mimeTypeForExtension(
          _selectedImageExtension,
        );
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
          );
      // If there is a local photo, upload to Supabase Storage and update student row with public URL
      if (studentId != null && _selectedImageBytes != null) {
        try {
          final supabase = ref.read(supabaseServiceProvider);
          final publicUrl = await supabase.uploadProfileImage(
            studentId: studentId,
            imageBytes: _selectedImageBytes!,
            fileExtension: _selectedImageExtension,
            contentType: _selectedImageMimeType,
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

    final digitsOnly = value.replaceAll(RegExp('[^0-9]'), '');
    if (digitsOnly.length != 10) {
      return 'Phone number must be 10 digits';
    }

    return null;
  }

  // Amount validation removed from Add flow (no amount field here)

  void _nextPage() {
    // Only advance from page 0 -> 1 (there are exactly 2 pages now)
    if (_currentPage == 0) {
      final ok = _formKey.currentState?.validate() ?? false;
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
    return PageHeader(
      title: 'Add Student',
      subtitle: 'Create new student profile',
      onBack: _onRequestExit,
      actions: [
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
    final width = MediaQuery.of(context).size.width;

    if (width >= 1200) return _buildDesktopLayout(context, theme);
    if (width >= 600) return _buildTabletLayout(context, theme);
    return _buildMobileLayout(context, theme);
  }

  Widget _buildTabletLayout(BuildContext context, ThemeData theme) {
    return _wrapWithDiscardGuard(
      Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: _buildModernHeader(context),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildProfilePhotoPage(),
                          const SizedBox(height: 32),
                          Divider(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          const SizedBox(height: 32),
                          _buildPersonalInfoPage(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
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
                child: Row(
                  children: [
                    OutlinedButton(
                      onPressed: _onRequestExit,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.borderMd,
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _saveStudent,
                      icon: _isLoading
                          ? SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.onPrimary,
                              ),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(_isLoading ? 'Saving...' : 'Create Student'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.borderMd,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, ThemeData theme) {
    return _wrapWithDiscardGuard(
      Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: _buildModernHeader(context),
                  ),
                  const SizedBox(height: 16),
                  // Two-column body
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Photo picker + preview card
                        SizedBox(
                          width: 340,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(24, 8, 16, 100),
                            child: _buildProfilePhotoPage(),
                          ),
                        ),
                        // Divider
                        Container(
                          width: 1,
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        // Right: All form fields
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                            child: _buildPersonalInfoPage(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Bottom action bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
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
                    child: Row(
                      children: [
                        OutlinedButton(
                          onPressed: _onRequestExit,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.borderMd,
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _isLoading ? null : _saveStudent,
                          icon: _isLoading
                              ? SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: Text(
                            _isLoading ? 'Saving...' : 'Create Student',
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.borderMd,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, ThemeData theme) {
    final progress = (_currentPage + 1) / 2;

    return _wrapWithDiscardGuard(
      Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _buildModernHeader(context),
              ),
              const SizedBox(height: 8),
              // Progress Indicator
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: AppRadius.borderXs,
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
              // Form Content
              Expanded(
                child: Form(
                  key: _formKey,
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        child: _buildPersonalInfoPage(),
                      ),
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        child: _buildProfilePhotoPage(),
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom Action Bar
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color: theme.colorScheme.outlineVariant,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: AppRadius.borderMd,
                              ),
                            ),
                            child: const Text('Previous'),
                          ),
                        ),
                      if (_currentPage > 0) const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: _isLoading
                              ? null
                              : (_currentPage == 0 ? _nextPage : _saveStudent),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.borderMd,
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
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildPersonalInfoPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                "Enter the student's basic details",
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
          borderRadius: AppRadius.borderLg,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: AppRadius.borderLg,
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
        const SizedBox(height: 20),

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
          borderRadius: AppRadius.borderLg,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderLg,
          borderSide: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderLg,
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderLg,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      if (_selectedImageBytes != null)
                        ClipOval(
                          child: Image.memory(
                            _selectedImageBytes!,
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
                              ? '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
                                    .trim()
                                    .split(RegExp(r'\s+'))
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
                            _selectedImageBytes == null
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

              if (_selectedImageBytes == null) ...[
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
                      _selectedImageBytes = null;
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
