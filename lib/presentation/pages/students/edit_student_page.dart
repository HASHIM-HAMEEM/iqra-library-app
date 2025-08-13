import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:library_registration_app/core/utils/permission_service.dart';
import 'package:library_registration_app/domain/entities/student.dart';
import 'package:library_registration_app/presentation/providers/students/students_notifier.dart';
import 'package:library_registration_app/presentation/providers/students/students_provider.dart';
import 'package:library_registration_app/presentation/widgets/common/custom_notification.dart';
import 'package:path_provider/path_provider.dart';

class EditStudentPage extends ConsumerStatefulWidget {

  const EditStudentPage({required this.studentId, super.key});
  final String studentId;

  @override
  ConsumerState<EditStudentPage> createState() => _EditStudentPageState();
}

class _EditStudentPageState extends ConsumerState<EditStudentPage> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _seatNumberController;
  late final TextEditingController _subscriptionAmountController;

  late DateTime _selectedDate;
  DateTime? _subscriptionStartDate;
  DateTime? _subscriptionEndDate;
  String? _subscriptionPlan;
  String? _subscriptionStatus;
  bool _isLoading = false;
  String? _emailError;
  bool _hasChanges = false;
  File? _selectedImage;
  String? _profileImagePath;
  int _currentPage = 0;
  Timer? _emailCheckTimer;

  final List<String> _subscriptionPlans = [
    'Basic',
    'Standard',
    'Premium',
    'VIP',
  ];

  final List<String> _subscriptionStatuses = [
    'Active',
    'Inactive',
    'Suspended',
    'Expired',
  ];

  Student? _loadedStudent;

  @override
  void initState() {
    super.initState();
    // Defer initialization until student is loaded in build
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _seatNumberController = TextEditingController();
    _subscriptionAmountController = TextEditingController();

    // Add listeners to detect changes
    _firstNameController.addListener(_onFieldChanged);
    _lastNameController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _addressController.addListener(_onFieldChanged);
    _subscriptionAmountController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _seatNumberController.dispose();
    _subscriptionAmountController.dispose();
    _pageController.dispose();
    _emailCheckTimer?.cancel();
    super.dispose();
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  bool _hasFormChanges() {
    final student = _loadedStudent;
    if (student == null) return false;
    return _firstNameController.text.trim() != student.firstName ||
        _lastNameController.text.trim() != student.lastName ||
        _emailController.text.trim() != student.email ||
        _phoneController.text.trim() != (student.phone ?? '') ||
        _addressController.text.trim() != (student.address ?? '') ||
        _seatNumberController.text.trim() != (student.seatNumber ?? '') ||
        _selectedDate != student.dateOfBirth;
  }

  Future<void> _selectDate({
    bool isSubscriptionStart = false,
    bool isSubscriptionEnd = false,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isSubscriptionStart
          ? _subscriptionStartDate ?? DateTime.now()
          : isSubscriptionEnd
          ? _subscriptionEndDate ?? DateTime.now()
          : _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: isSubscriptionStart
          ? 'Select Subscription Start Date'
          : isSubscriptionEnd
          ? 'Select Subscription End Date'
          : 'Select Date of Birth',
    );
    if (picked != null) {
      setState(() {
        if (isSubscriptionStart) {
          _subscriptionStartDate = picked;
        } else if (isSubscriptionEnd) {
          _subscriptionEndDate = picked;
        } else {
          _selectedDate = picked;
        }
        _hasChanges = true;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final granted = await PermissionService.ensurePhotoLibraryPermission();
    if (!granted) return;
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _hasChanges = true;
      });
    }
  }

  Future<String?> _saveImage(File imageFile) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage = await imageFile.copy('${appDir.path}/$fileName');
      return savedImage.path;
    } catch (e) {
      return null;
    }
  }

  String? _validateAmount(String? value) {
    if (value == null || value.isEmpty) return null;
    final amount = double.tryParse(value);
    if (amount == null || amount < 0) {
      return 'Please enter a valid amount';
    }
    return null;
  }

  void _nextPage() {
    if (_currentPage < 2) {
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

  Future<void> _checkEmailExists() async {
    final email = _emailController.text.trim();
    final student = _loadedStudent;
    if (student == null) return;
    if (email.isEmpty || email == student.email) {
      setState(() {
        _emailError = null;
      });
      return;
    }

    try {
      final exists = await ref
          .read(studentsNotifierProvider.notifier)
          .isEmailExists(email, excludeId: student.id);
      setState(() {
        _emailError = exists ? 'Email already exists' : null;
      });
    } catch (e) {
      setState(() {
        _emailError = null;
      });
    }
  }

  Future<void> _updateStudent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_emailError != null) {
      CustomNotification.show(
        context,
        message: _emailError!,
        type: NotificationType.error,
      );
      return;
    }

    if (!_hasFormChanges()) {
      CustomNotification.show(
        context,
        message: 'No changes to save',
        type: NotificationType.warning,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final student = _loadedStudent!;
      var finalImagePath = _profileImagePath;

      // Save new image if selected
      if (_selectedImage != null) {
        finalImagePath = await _saveImage(_selectedImage!);
      }

      final updatedStudent = student.copyWith(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        dateOfBirth: _selectedDate,
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
        profileImagePath: finalImagePath,
        subscriptionPlan: _subscriptionPlan,
        subscriptionStartDate: _subscriptionStartDate,
        subscriptionEndDate: _subscriptionEndDate,
        subscriptionAmount: _subscriptionAmountController.text.trim().isEmpty
            ? null
            : double.tryParse(_subscriptionAmountController.text.trim()),
        subscriptionStatus: _subscriptionStatus,
      );

      await ref
          .read(studentsNotifierProvider.notifier)
          .updateStudent(updatedStudent);

      if (mounted) {
        CustomNotification.show(
          context,
          message: 'Student updated successfully',
          type: NotificationType.success,
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        CustomNotification.show(
          context,
          message: 'Error updating student: $e',
          type: NotificationType.error,
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

  Future<bool> _onWillPop() async {
    if (!_hasFormChanges()) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to leave without saving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    return result ?? false;
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

    final phoneRegex = RegExp(r'^[\+]?[1-9][\d]{0,15}$');
    if (!phoneRegex.hasMatch(
      value.trim().replaceAll(RegExp(r'[\s\-\(\)]'), ''),
    )) {
      return 'Please enter a valid phone number';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final studentAsync = ref.watch(studentByIdProvider(widget.studentId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
         if (didPop) return;
         final canPop = await _onWillPop();
         if (canPop && context.mounted) {
           Navigator.of(context).pop();
         }
       },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            ['Edit Student', 'Edit Student', 'Edit Student'][_currentPage],
          ),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              TextButton(
                onPressed: _updateStudent,
                child: const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        body: studentAsync.when(
          data: (Student? student) {
            if (student == null) {
              return const Center(child: Text('Student not found'));
            }
            // Initialize controllers once when data arrives
            if (_loadedStudent == null || _loadedStudent!.id != student.id) {
              _loadedStudent = student;
              _firstNameController.text = student.firstName;
              _lastNameController.text = student.lastName;
              _emailController.text = student.email;
              _phoneController.text = student.phone ?? '';
              _addressController.text = student.address ?? '';
              _seatNumberController.text = student.seatNumber ?? '';
              _subscriptionAmountController.text =
                  student.subscriptionAmount?.toString() ?? '';
              _selectedDate = student.dateOfBirth;
              _subscriptionStartDate = student.subscriptionStartDate;
              _subscriptionEndDate = student.subscriptionEndDate;
              _subscriptionPlan = student.subscriptionPlan;
              _subscriptionStatus = student.subscriptionStatus;
              _profileImagePath = student.profileImagePath;
            }

            return Form(
              key: _formKey,
              child: Column(
                children: [
                  // Page indicator
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        for (int i = 0; i < 3; i++)
                          Expanded(
                            child: Container(
                              height: 4,
                              margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                              decoration: BoxDecoration(
                                color: i <= _currentPage
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Page content
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
                        _buildSubscriptionPage(),
                      ],
                    ),
                  ),

                  // Navigation buttons
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        if (_currentPage > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _previousPage,
                              child: const Text('Previous'),
                            ),
                          ),
                        if (_currentPage > 0) const SizedBox(width: 16),
                        if (_currentPage < 2)
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _nextPage,
                              child: const Text('Next'),
                            ),
                          ),
                        if (_currentPage == 2)
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _updateStudent,
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Update Student'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, StackTrace _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Widget _buildPersonalInfoPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Removed Student ID display

        // First Name
        TextFormField(
          controller: _firstNameController,
          decoration: const InputDecoration(
            labelText: 'First Name *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
          ),
          textCapitalization: TextCapitalization.words,
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
          validator: (value) => _validateRequired(value, 'Last name'),
        ),
        const SizedBox(height: 16),

        // Date of Birth
        InkWell(
          onTap: _selectDate,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Date of Birth *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_today),
            ),
            child: Text(
              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Age (Read-only)
        TextFormField(
          initialValue: (_loadedStudent?.age ?? 0).toString(),
          decoration: const InputDecoration(
            labelText: 'Age',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.cake_outlined),
          ),
          enabled: false,
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
          ),
          keyboardType: TextInputType.emailAddress,
          validator: _validateEmail,
          onChanged: (value) {
            // Clear email error when user types
            if (_emailError != null) {
              setState(() {
                _emailError = null;
              });
            }
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
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 16),

        // Seat Number
        TextFormField(
          controller: _seatNumberController,
          decoration: const InputDecoration(
            labelText: 'Seat Number',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.event_seat_outlined),
            helperText: 'Optional (e.g., A12)',
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 16),

        // Created/Updated info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Record Information',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _loadedStudent == null
                      ? ''
                      : 'Created: ${_loadedStudent!.createdAt.day}/${_loadedStudent!.createdAt.month}/${_loadedStudent!.createdAt.year}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  _loadedStudent == null
                      ? ''
                      : 'Updated: ${_loadedStudent!.updatedAt.day}/${_loadedStudent!.updatedAt.month}/${_loadedStudent!.updatedAt.year}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfilePhotoPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 32),

        // Profile Image
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 80,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: _selectedImage != null
                    ? ClipOval(
                        child: Image.file(
                          _selectedImage!,
                          width: 160,
                          height: 160,
                          fit: BoxFit.cover,
                        ),
                      )
                    : _profileImagePath != null
                    ? ClipOval(
                        child: Image.file(
                          File(_profileImagePath!),
                          width: 160,
                          height: 160,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Text(
                              _loadedStudent?.initials ?? '',
                              style: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.onPrimary,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      )
                    : Text(
                        _loadedStudent?.initials ?? '',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
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
                    border: Border.all(
                      color: Theme.of(context).colorScheme.onPrimary,
                      width: 2,
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.camera_alt,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 24,
                    ),
                    onPressed: _pickImage,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Image actions
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text('Choose Photo'),
            ),
            if (_selectedImage != null || _profileImagePath != null)
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedImage = null;
                    _profileImagePath = null;
                    _hasChanges = true;
                  });
                },
                icon: const Icon(Icons.delete),
                label: const Text('Remove'),
              ),
          ],
        ),
        const SizedBox(height: 32),

        // Photo guidelines
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Photo Guidelines',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text('• Use a clear, recent photo'),
                const Text('• Face should be clearly visible'),
                const Text('• Avoid sunglasses or hats'),
                const Text('• Professional appearance recommended'),
                const Text('• Maximum file size: 5MB'),
                const Text('• Supported formats: JPG, PNG'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Subscription Plan
        DropdownButtonFormField<String>(
          value: _subscriptionPlan,
          decoration: const InputDecoration(
            labelText: 'Subscription Plan',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.card_membership),
            helperText: 'Optional',
          ),
          items: _subscriptionPlans.map((plan) {
            return DropdownMenuItem(value: plan, child: Text(plan));
          }).toList(),
          onChanged: (value) {
            setState(() {
              _subscriptionPlan = value;
              _hasChanges = true;
            });
          },
        ),
        const SizedBox(height: 16),

        // Subscription Status
        DropdownButtonFormField<String>(
          value: _subscriptionStatus,
          decoration: const InputDecoration(
            labelText: 'Subscription Status',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.info_outline),
            helperText: 'Optional',
          ),
          items: _subscriptionStatuses.map((status) {
            return DropdownMenuItem(value: status, child: Text(status));
          }).toList(),
          onChanged: (value) {
            setState(() {
              _subscriptionStatus = value;
              _hasChanges = true;
            });
          },
        ),
        const SizedBox(height: 16),

        // Subscription Amount
        TextFormField(
          controller: _subscriptionAmountController,
          decoration: const InputDecoration(
            labelText: 'Subscription Amount',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.currency_rupee),
            helperText: 'Optional',
          ),
          keyboardType: TextInputType.number,
          validator: _validateAmount,
        ),
        const SizedBox(height: 16),

        // Subscription Start Date
        InkWell(
          onTap: () => _selectDate(isSubscriptionStart: true),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Subscription Start Date',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.date_range),
              helperText: 'Optional',
            ),
            child: Text(
              _subscriptionStartDate != null
                  ? '${_subscriptionStartDate!.day}/${_subscriptionStartDate!.month}/${_subscriptionStartDate!.year}'
                  : 'Not set',
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Subscription End Date
        InkWell(
          onTap: () => _selectDate(isSubscriptionEnd: true),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Subscription End Date',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.date_range),
              helperText: 'Optional',
            ),
            child: Text(
              _subscriptionEndDate != null
                  ? '${_subscriptionEndDate!.day}/${_subscriptionEndDate!.month}/${_subscriptionEndDate!.year}'
                  : 'Not set',
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Subscription summary
        if (_subscriptionPlan != null || _subscriptionStatus != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subscription Summary',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_subscriptionPlan != null)
                    Text('Plan: $_subscriptionPlan'),
                  if (_subscriptionStatus != null)
                    Text('Status: $_subscriptionStatus'),
                  if (_subscriptionAmountController.text.isNotEmpty)
                    Text('Amount: \$${_subscriptionAmountController.text}'),
                  if (_subscriptionStartDate != null)
                    Text(
                      'Start: ${_subscriptionStartDate!.day}/${_subscriptionStartDate!.month}/${_subscriptionStartDate!.year}',
                    ),
                  if (_subscriptionEndDate != null)
                    Text(
                      'End: ${_subscriptionEndDate!.day}/${_subscriptionEndDate!.month}/${_subscriptionEndDate!.year}',
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
