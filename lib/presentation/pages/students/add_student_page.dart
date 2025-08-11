import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:library_registration_app/core/utils/permission_service.dart';
import 'package:library_registration_app/presentation/providers/students/students_notifier.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

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

  // Subscription Controllers
  final _subscriptionPlanController = TextEditingController();
  final _subscriptionAmountController = TextEditingController();

  DateTime? _selectedDate;
  DateTime? _subscriptionStartDate;
  DateTime? _subscriptionEndDate;
  String? _subscriptionPlan;
  String? _subscriptionStatus = 'Active';

  File? _selectedImage;
  String? _profileImagePath;

  bool _isLoading = false;
  String? _emailError;
  int _currentPage = 0;
  bool _dobError = false;
  bool _isCheckingEmail = false;
  Timer? _emailDebounce;

  final List<String> _subscriptionPlans = [
    'Basic',
    'Standard',
    'Premium',
    'Annual',
  ];

  final List<String> _subscriptionStatuses = [
    'Active',
    'Inactive',
    'Suspended',
    'Expired',
  ];

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
    _subscriptionPlanController.dispose();
    _subscriptionAmountController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(
    BuildContext context, {
    required bool isSubscriptionDate,
    required bool isStartDate,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isSubscriptionDate
          ? (isStartDate
                ? DateTime.now()
                : (_subscriptionStartDate ?? DateTime.now()))
          : DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: isSubscriptionDate ? DateTime(2020) : DateTime(1900),
      lastDate: isSubscriptionDate ? DateTime(2030) : DateTime.now(),
      helpText: isSubscriptionDate
          ? (isStartDate ? 'Select Start Date' : 'Select End Date')
          : 'Select Date of Birth',
    );

    if (picked != null) {
      setState(() {
        _dobError = false;
        if (isSubscriptionDate) {
          if (isStartDate) {
            _subscriptionStartDate = picked;
            // Reset end date if it's before start date
            if (_subscriptionEndDate != null &&
                _subscriptionEndDate!.isBefore(picked)) {
              _subscriptionEndDate = null;
            }
          } else {
            _subscriptionEndDate = picked;
          }
        } else {
          _selectedDate = picked;
        }
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();

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
                      _profileImagePath = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveImage(XFile image) async {
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

      final savedImage = await File(image.path).copy(savedPath);

      setState(() {
        _selectedImage = savedImage;
        _profileImagePath = savedPath;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving image: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
      // Find which page has validation errors and navigate to it
      if (_selectedDate == null) {
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      return;
    }

    if (_selectedDate == null) {
      setState(() => _dobError = true);
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    if (_emailError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_emailError!), backgroundColor: Colors.red),
      );
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
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
            profileImagePath: _profileImagePath,
            subscriptionPlan: _subscriptionPlan,
            subscriptionStartDate: _subscriptionStartDate,
            subscriptionEndDate: _subscriptionEndDate,
            subscriptionAmount:
                _subscriptionAmountController.text.trim().isEmpty
                ? null
                : double.tryParse(_subscriptionAmountController.text.trim()),
            subscriptionStatus: _subscriptionStatus,
          );

      if (mounted && studentId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        // Gentle message only; avoid technical errors
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add student. Please check inputs.')),
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

  String? _validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Amount is optional
    }

    final amount = double.tryParse(value.trim());
    if (amount == null || amount < 0) {
      return 'Please enter a valid amount';
    }

    return null;
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Add Student'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
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
              onPressed: _saveStudent,
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(context).unfocus(),
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
                              value: (_currentPage + 1) / 3,
                               backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '${_currentPage + 1} of 3',
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
                          _buildSubscriptionPage(),
                        ],
                      ),
                    ),
                  ],
                ),
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
                            : (_currentPage < 2 ? _nextPage : _saveStudent),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(_currentPage < 2 ? 'Next' : 'Add Student'),
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
          validator: (value) => _validateRequired(value, 'Last name'),
        ),
        const SizedBox(height: 16),

        // Date of Birth
        InkWell(
          onTap: () => _selectDate(
            context,
            isSubscriptionDate: false,
            isStartDate: false,
          ),
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
                  CircleAvatar(
                    radius: 80,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    backgroundImage: _selectedImage != null
                        ? FileImage(_selectedImage!)
                        : null,
                    child: _selectedImage == null
                        ? Icon(
                            Icons.person,
                            size: 80,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
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
                        onPressed: _pickImage,
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

  Widget _buildSubscriptionPage() {
    return ListView(
      padding: _pagePadding(context),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Text(
          'Subscription Details',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'All subscription fields are optional',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),

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
          ),
          items: _subscriptionStatuses.map((status) {
            return DropdownMenuItem(value: status, child: Text(status));
          }).toList(),
          onChanged: (value) {
            setState(() {
              _subscriptionStatus = value;
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
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          scrollPadding: _fieldScrollPadding(context),
          validator: _validateAmount,
        ),
        const SizedBox(height: 16),

        // Subscription Start Date
        InkWell(
          onTap: () =>
              _selectDate(context, isSubscriptionDate: true, isStartDate: true),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Subscription Start Date',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_today),
              helperText: 'Optional',
            ),
            child: Text(
              _subscriptionStartDate == null
                  ? 'Select start date'
                  : '${_subscriptionStartDate!.day}/${_subscriptionStartDate!.month}/${_subscriptionStartDate!.year}',
              style: TextStyle(
                color: _subscriptionStartDate == null
                    ? Theme.of(context).hintColor
                    : Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Subscription End Date
        InkWell(
          onTap: _subscriptionStartDate != null
              ? () => _selectDate(
                  context,
                  isSubscriptionDate: true,
                  isStartDate: false,
                )
              : null,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Subscription End Date',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.calendar_today),
              helperText: _subscriptionStartDate == null
                  ? 'Select start date first'
                  : 'Optional',
              enabled: _subscriptionStartDate != null,
            ),
            child: Text(
              _subscriptionEndDate == null
                  ? 'Select end date'
                  : '${_subscriptionEndDate!.day}/${_subscriptionEndDate!.month}/${_subscriptionEndDate!.year}',
              style: TextStyle(
                color:
                    _subscriptionEndDate == null ||
                        _subscriptionStartDate == null
                    ? Theme.of(context).hintColor
                    : Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
