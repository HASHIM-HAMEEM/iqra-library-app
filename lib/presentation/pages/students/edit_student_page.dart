import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:library_registration_app/core/utils/permission_service.dart';
import 'package:library_registration_app/core/utils/responsive_utils.dart';
import 'package:library_registration_app/core/services/image_compression_service.dart';
import 'package:library_registration_app/domain/entities/student.dart';
import 'package:library_registration_app/presentation/providers/students/students_notifier.dart';
import 'package:library_registration_app/presentation/providers/students/students_provider.dart';
import 'package:library_registration_app/presentation/widgets/common/custom_notification.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:library_registration_app/presentation/providers/database_provider.dart';
import 'package:library_registration_app/presentation/widgets/common/async_avatar.dart';

class EditStudentPage extends ConsumerStatefulWidget {
  const EditStudentPage({required this.studentId, super.key});
  final String studentId;

  @override
  ConsumerState<EditStudentPage> createState() => _EditStudentPageState();
}

class _EditStudentPageState extends ConsumerState<EditStudentPage> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();

  // Controllers
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _seatNumberController;

  DateTime? _selectedDate;
  bool _isLoading = false;
  bool _isCompressingImage = false;
  String? _emailError;
  bool _hasChanges = false;
  File? _selectedImage;
  String? _profileImagePath;
  int _currentPage = 0;
  Student? _loadedStudent;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController()
      ..addListener(_onFieldChanged);
    _lastNameController = TextEditingController()..addListener(_onFieldChanged);
    _emailController = TextEditingController()..addListener(_onFieldChanged);
    _phoneController = TextEditingController()..addListener(_onFieldChanged);
    _addressController = TextEditingController()..addListener(_onFieldChanged);
    _seatNumberController = TextEditingController()
      ..addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _seatNumberController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  bool _hasFormChanges() {
    if (_hasChanges) return true;
    if (_selectedImage != null) return true;
    // Deep check if needed, but _onFieldChanged covers text fields
    return false;
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Select Date of Birth',
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _hasChanges = true;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Photo Library'),
              onTap: () async {
                Navigator.pop(context);
                if (await PermissionService.ensurePhotoLibraryPermission()) {
                  final img = await picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (img != null) _processSelectedImage(img);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () async {
                Navigator.pop(context);
                if (await PermissionService.ensureCameraPermission()) {
                  final img = await picker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (img != null) _processSelectedImage(img);
                }
              },
            ),
            if (_selectedImage != null || _profileImagePath != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Remove Photo',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedImage = null;
                    _profileImagePath = null;
                    _hasChanges = true;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _processSelectedImage(XFile image) async {
    setState(() => _isCompressingImage = true);
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${path.basename(image.path)}';
      final savedPath = path.join(appDir.path, 'profile_images', fileName);
      final profileDir = Directory(path.dirname(savedPath));
      if (!await profileDir.exists()) await profileDir.create(recursive: true);

      final tempImage = await File(image.path).copy(savedPath);
      // Simplify compression for edit (using service)
      final compressed = await ImageCompressionService.compressImage(tempImage);

      setState(() {
        _selectedImage = compressed;
        _hasChanges = true;
      });
    } catch (e) {
      if (mounted)
        CustomNotification.show(
          context,
          message: 'Error processing image: $e',
          type: NotificationType.error,
        );
    } finally {
      if (mounted) setState(() => _isCompressingImage = false);
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasFormChanges()) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text('You have unsaved changes. Leave without saving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _updateStudent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_emailError != null) {
      CustomNotification.show(
        context,
        message: _emailError!,
        type: NotificationType.error,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Upload image if new
      String? finalImagePath = _profileImagePath;
      if (_selectedImage != null) {
        final supabase = ref.read(supabaseServiceProvider);
        finalImagePath = await supabase.uploadProfileImage(
          studentId: widget.studentId,
          file: _selectedImage!,
        );
        // Supabase trigger might handle DB update, but we set it explicitly below
      }

      // 2. Prepare Updated Object
      final updated = _loadedStudent!.copyWith(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
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
        dateOfBirth: _selectedDate!,
        profileImagePath: finalImagePath,
        // Subscriptions processed separately now - retain old values if they existed to play safe
        subscriptionPlan: _loadedStudent!.subscriptionPlan,
        subscriptionStatus: _loadedStudent!.subscriptionStatus,
        subscriptionStartDate: _loadedStudent!.subscriptionStartDate,
        subscriptionEndDate: _loadedStudent!.subscriptionEndDate,
        subscriptionAmount: _loadedStudent!.subscriptionAmount,
      );

      // 3. Call Notifier
      await ref.read(studentsNotifierProvider.notifier).updateStudent(updated);

      if (mounted) {
        CustomNotification.show(
          context,
          message: 'Student updated successfully',
          type: NotificationType.success,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        CustomNotification.show(
          context,
          message: 'Update failed: $e',
          type: NotificationType.error,
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final studentAsync = ref.watch(studentByIdProvider(widget.studentId));
    final progress = (_currentPage + 1) / 2;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _onWillPop() && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: studentAsync.when(
          data: (student) {
            if (student == null)
              return const Center(child: Text('Student not found'));

            // Initialization
            if (_loadedStudent == null || _loadedStudent!.id != student.id) {
              _loadedStudent = student;
              _firstNameController.text = student.firstName;
              _lastNameController.text = student.lastName;
              _emailController.text = student.email;
              _phoneController.text = student.phone ?? '';
              _addressController.text = student.address ?? '';
              _seatNumberController.text = student.seatNumber ?? '';
              _selectedDate = student.dateOfBirth;
              _profileImagePath = student.profileImagePath;
              // Reset trigger after init
              Future.microtask(() => setState(() => _hasChanges = false));
            }

            return Stack(
              children: [
                // Background Gradient
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
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.05,
                          ),
                          blurRadius: 100,
                          spreadRadius: 20,
                        ),
                      ],
                    ),
                  ),
                ),

                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: ResponsiveUtils.getResponsivePadding(
                              context,
                            ).copyWith(top: 8, bottom: 0),
                            child: _buildModernHeader(context, student),
                          ),
                        ),
                        // Stepper
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
                                      backgroundColor: theme
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      valueColor: AlwaysStoppedAnimation(
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
                        // Form
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Form(
                            key: _formKey,
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height - 200,
                              child: PageView(
                                controller: _pageController,
                                physics: const NeverScrollableScrollPhysics(),
                                onPageChanged: (i) =>
                                    setState(() => _currentPage = i),
                                children: [
                                  _buildPersonalInfoPage(theme),
                                  _buildProfilePhotoPage(theme),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Bar
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
                                onPressed: () => _pageController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
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
                              onPressed: _currentPage == 0
                                  ? () {
                                      if (_formKey.currentState!.validate() &&
                                          _selectedDate != null) {
                                        _pageController.nextPage(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          curve: Curves.easeInOut,
                                        );
                                      } else if (_selectedDate == null) {
                                        CustomNotification.show(
                                          context,
                                          message: 'Date of birth is required',
                                          type: NotificationType.error,
                                        );
                                      }
                                    }
                                  : (_isLoading ? null : _updateStudent),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _currentPage == 0
                                          ? 'Next Step'
                                          : 'Update Student',
                                      style: const TextStyle(
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
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Widget _buildModernHeader(BuildContext context, Student student) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          onPressed: () async {
            if (await _onWillPop() && context.mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Student',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                student.fullName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalInfoPage(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _buildModernTextField(
          theme,
          _firstNameController,
          'First Name',
          Icons.person_outline,
          validator: (v) => v?.isEmpty == true ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        _buildModernTextField(
          theme,
          _lastNameController,
          'Last Name',
          Icons.person_outline,
          validator: (v) => v?.isEmpty == true ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => _selectDate(context),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.cake_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date of Birth *',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedDate == null
                            ? 'Select Date'
                            : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildModernTextField(
          theme,
          _emailController,
          'Email',
          Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (v) => v?.contains('@') == true ? null : 'Invalid email',
        ),
        const SizedBox(height: 16),
        _buildModernTextField(
          theme,
          _phoneController,
          'Phone (Optional)',
          Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        _buildModernTextField(
          theme,
          _addressController,
          'Address (Optional)',
          Icons.location_on_outlined,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildProfilePhotoPage(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 190,
                    height: 190,
                    child: _selectedImage != null
                        ? Image.file(_selectedImage!, fit: BoxFit.cover)
                        : AsyncAvatar(
                            imagePath: _profileImagePath,
                            initials: _loadedStudent?.initials ?? '?',
                            size: 190,
                          ),
                  ),
                ),
                Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                if (_isCompressingImage)
                  const CircularProgressIndicator(color: Colors.white),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Tap to change photo',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildModernTextField(
    ThemeData theme,
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
        floatingLabelStyle: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
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
        contentPadding: const EdgeInsets.all(16),
      ),
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }
}
