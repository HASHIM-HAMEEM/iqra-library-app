import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:library_registration_app/domain/entities/student.dart';
import 'package:library_registration_app/presentation/providers/database_provider.dart';
import 'package:library_registration_app/presentation/providers/students/students_provider.dart';

class TypeaheadStudentField extends ConsumerStatefulWidget {
  const TypeaheadStudentField({
    required this.onSelected, super.key,
    this.initial,
    this.label = 'Student',
  });

  final void Function(Student? student) onSelected;
  final Student? initial;
  final String label;

  @override
  ConsumerState<TypeaheadStudentField> createState() =>
      _TypeaheadStudentFieldState();
}

class _TypeaheadStudentFieldState extends ConsumerState<TypeaheadStudentField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<Student> _results = const [];
  // Inline dropdown removed; keep only bottom-sheet UX
  Student? _selectedStudent;
  Timer? _debounceTimer;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _selectedStudent = widget.initial;
      final seat = widget.initial!.seatNumber;
      _controller.text = seat == null || seat.isEmpty
          ? '${widget.initial!.fullName} · ${widget.initial!.email}'
          : '${widget.initial!.fullName} · ${widget.initial!.email} · Seat $seat';
    }
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        // When focused with empty query, load active students for quick pick
        _search(_controller.text);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _search(String query) {
    // Cancel previous timer
    _debounceTimer?.cancel();

    // If we have a selected student and the query matches their display text, don't search
    var selectedDisplay = '';
    if (_selectedStudent != null) {
      final seat = _selectedStudent!.seatNumber;
      selectedDisplay = (seat == null || seat.isEmpty)
          ? '${_selectedStudent!.fullName} · ${_selectedStudent!.email}'
          : '${_selectedStudent!.fullName} · ${_selectedStudent!.email} · Seat $seat';
    }
    if (_selectedStudent != null && query == selectedDisplay) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    // Clear selection if user is typing something different
    if (_selectedStudent != null && query.isNotEmpty) {
      _selectedStudent = null;
      // Notify parent that selection was cleared
      widget.onSelected(null);
    }

    // Allow empty query to list active students for discovery UX
    if (query.trim().isEmpty) {
      setState(() => _isSearching = true);
      _debounceTimer = Timer(const Duration(milliseconds: 150), () async {
        try {
          final repo = ref.read(studentRepositoryProvider);
          final list = await repo.getActiveStudents();
          if (!mounted) return;
          setState(() {
            _results = list;
            _isSearching = false;
          });
        } catch (e) {
          debugPrint('Error loading active students: $e');
          if (!mounted) return;
          setState(() {
            _results = const [];
            _isSearching = false;
          });
        }
      });
      return;
    }

    // Debounce the search
    setState(() => _isSearching = true);
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final list = await ref.read(
          searchStudentsProvider(query.trim()).future,
        );
        if (!mounted) return;
        setState(() {
          _results = list;
          _isSearching = false;
        });
      } catch (e) {
        debugPrint('Error searching students: $e');
        if (!mounted) return;
        setState(() {
          _results = const [];
          _isSearching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          readOnly: true,
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: _selectedStudent != null
                ? const Icon(Icons.person, color: Colors.green)
                : _isSearching
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            suffixIcon: _selectedStudent != null
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _selectedStudent = null;
                        _controller.clear();
                        _results = [];
                      });
                      widget.onSelected(null);
                    },
                  )
                : IconButton(
                    icon: const Icon(Icons.arrow_drop_down_rounded),
                    onPressed: _openPickerDialog,
                  ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          ),
          onTap: _openPickerDialog,
          validator: (value) {
            if (_selectedStudent == null) {
              return 'Please select a student';
            }
            return null;
          },
        ),
        // Inline dropdown removed; we use a dedicated bottom sheet picker
      ],
    );
  }

  Future<void> _openPickerDialog() async {
    // Ensure initial list
    // Always load initial list to avoid relying on prior field state
    _isSearching = true;
    try {
      final repo = ref.read(studentRepositoryProvider);
      final list = await repo.getActiveStudents();
      if (mounted) {
        setState(() {
          _results = list;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _results = const [];
          _isSearching = false;
        });
      }
    }
    final searchCtrl = TextEditingController();
    final focusNode = FocusNode();
    var didFocus = false;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        // Local state helpers
        Future<void> runSearch(String q) async {
          setState(() {
            _isSearching = true;
          });
          try {
            final qLower = q.trim().toLowerCase();
            final list = qLower.isEmpty
                ? await ref.read(studentRepositoryProvider).getActiveStudents()
                : await ref.read(searchStudentsProvider(qLower).future);
            if (!mounted) return;
            setState(() {
              _isSearching = false;
              _results = list;
            });
          } catch (_) {
            if (!mounted) return;
            setState(() {
              _isSearching = false;
              _results = const [];
            });
          }
        }

        final mq = MediaQuery.of(ctx);
        final isTablet = mq.size.shortestSide >= 600;
        final heightFactor = isTablet ? 0.6 : 0.85;
        final maxHeight = mq.size.height * heightFactor;

        return AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
          child: SafeArea(
            child: FractionallySizedBox(
              heightFactor: heightFactor,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: StatefulBuilder(
                  builder: (ctx, setSheetState) {
                    if (!didFocus) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        focusNode.requestFocus();
                      });
                      didFocus = true;
                    }
                    return SizedBox(
                      height: maxHeight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: searchCtrl,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Search student',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (q) => runSearch(q.toLowerCase()),
                            autofocus: true,
                            textInputAction: TextInputAction.search,
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _isSearching
                                ? const Center(child: CircularProgressIndicator())
                                : _results.isEmpty
                                    ? Center(
                                        child: Text(
                                          'No students found',
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: _results.length,
                                        separatorBuilder: (_, __) => const Divider(height: 1),
                                        itemBuilder: (context, index) {
                                          final s = _results[index];
                                          return ListTile(
                                            leading: const Icon(Icons.person_outline),
                                            title: Text(s.fullName),
                                            subtitle: Text(s.email),
                                            onTap: () {
                                              widget.onSelected(s);
                                              setState(() {
                                                _selectedStudent = s;
                                                final seat = s.seatNumber;
                                                _controller.text = seat == null || seat.isEmpty
                                                    ? '${s.fullName} · ${s.email}'
                                                    : '${s.fullName} · ${s.email} · Seat $seat';
                                                _results = [];
                                              });
                                              Navigator.of(ctx).pop();
                                            },
                                          );
                                        },
                                      ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
