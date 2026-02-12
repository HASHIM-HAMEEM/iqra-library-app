import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:library_registration_app/core/config/app_config.dart';
import 'package:library_registration_app/core/platform/export_file_saver.dart';
import 'package:library_registration_app/core/responsive/responsive.dart';
import 'package:library_registration_app/core/services/id_card_pdf_service.dart';
import 'package:library_registration_app/core/services/id_card_service.dart';
import 'package:library_registration_app/domain/entities/student.dart';
import 'package:library_registration_app/presentation/providers/database_provider.dart';
import 'package:library_registration_app/presentation/providers/students/students_provider.dart';
import 'package:library_registration_app/presentation/widgets/common/custom_notification.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

class StudentIdCardPage extends ConsumerStatefulWidget {
  const StudentIdCardPage({required this.studentId, super.key});

  final String studentId;

  @override
  ConsumerState<StudentIdCardPage> createState() => _StudentIdCardPageState();
}

class _StudentIdCardPageState extends ConsumerState<StudentIdCardPage> {
  bool _issuingToken = false;
  bool _isDownloading = false;
  bool _isDownloadingPdf = false;
  final ScreenshotController _screenshotController = ScreenshotController();

  Future<void> _ensureToken(Student student) async {
    setState(() => _issuingToken = true);
    try {
      await ref.read(supabaseServiceProvider).ensureStudentIdCardToken(student.id);
      ref.invalidate(studentByIdProvider(student.id));
      if (!mounted) return;
      CustomNotification.show(
        context,
        message: 'Secure token issued for ID card.',
      );
    } catch (e) {
      if (!mounted) return;
      CustomNotification.show(
        context,
        message: 'Failed to issue card token: $e',
        type: NotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _issuingToken = false);
    }
  }

  Future<void> _downloadCard() async {
    setState(() => _isDownloading = true);
    try {
      final image = await _screenshotController.capture(
        // High pixel ratio keeps printable PNG exports sharp.
        pixelRatio: 4,
        delay: const Duration(milliseconds: 250),
      );
      
      if (image == null) {
        if (!mounted) return;
        CustomNotification.show(
          context,
          message: 'Failed to capture ID card image.',
          type: NotificationType.error,
        );
        return;
      }

      final fileName = 'student_id_card_${widget.studentId}.png';
      final savedPathOrName = await saveExportBytes(image.toList(), fileName);
      await _maybeShareSavedFile(savedPathOrName, mimeType: 'image/png');

      if (!mounted) return;
      CustomNotification.show(
        context,
        message: 'ID card downloaded successfully!',
      );
    } catch (e) {
      if (!mounted) return;
      CustomNotification.show(
        context,
        message: 'Failed to download ID card: $e',
        type: NotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _downloadPdf(Student student, IdCardPayload payload) async {
    setState(() => _isDownloadingPdf = true);
    try {
      final supabase = ref.read(supabaseServiceProvider);
      final profileBytes = await supabase.downloadProfileImageBytes(
        student.profileImagePath,
      );

      final pdfBytes = await IdCardPdfService.buildFrontBackSheetPdf(
        student: student,
        payload: payload,
        profileImageBytes: profileBytes,
      );

      final fileName = 'student_id_card_${widget.studentId}.pdf';
      final savedPathOrName = await saveExportBytes(pdfBytes.toList(), fileName);
      await _maybeShareSavedFile(savedPathOrName, mimeType: 'application/pdf');

      if (!mounted) return;
      CustomNotification.show(
        context,
        message: 'ID card PDF downloaded successfully!',
      );
    } catch (e) {
      if (!mounted) return;
      CustomNotification.show(
        context,
        message: 'Failed to download PDF: $e',
        type: NotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _isDownloadingPdf = false);
    }
  }

  Future<void> _maybeShareSavedFile(String savedPathOrName, {required String mimeType}) async {
    // Web downloads via browser; there's no local file path to share.
    if (kIsWeb) return;
    final path = savedPathOrName.trim();
    if (path.isEmpty) return;
    // `saveExportBytes` returns a file path on IO and just a fileName on web.
    if (!path.contains('/')) return;
    try {
      await Share.shareXFiles(
        [XFile(path, mimeType: mimeType)],
        text: 'IQRA Student ID Card',
      );
    } catch (_) {
      // Sharing is best-effort; the file is still saved in app storage.
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentAsync = ref.watch(studentByIdProvider(widget.studentId));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Student ID Card'),
        centerTitle: true,
        elevation: 0,
      ),
      body: studentAsync.when(
        data: (student) {
          if (student == null) {
            return const Center(child: Text('Student not found'));
          }

          if ((student.idCardToken ?? '').isEmpty) {
            return _buildTokenMissingState(theme, student);
          }

          final payload = IdCardService.generate(
            student,
            issuedAt: student.idCardIssuedAt,
            token: student.idCardToken,
          );

          return _buildCardView(theme, student, payload);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load student: $e')),
      ),
    );
  }

  Widget _buildTokenMissingState(ThemeData theme, Student student) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shield_outlined,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Secure Token Required',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Issue a secure token to generate a verifiable ID card with QR code.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _issuingToken ? null : () => _ensureToken(student),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              icon: _issuingToken
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.security_update_good_outlined),
              label: Text(_issuingToken ? 'Issuing Token...' : 'Issue Secure Token'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardView(ThemeData theme, Student student, IdCardPayload payload) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: ResponsiveUtils.getMaxContentWidth(context),
          ),
          child: Column(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Screenshot(
                  controller: _screenshotController,
                  child: _buildModernIdCard(theme, student, payload),
                ),
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _isDownloadingPdf ? null : () => _downloadPdf(student, payload),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    icon: _isDownloadingPdf
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Download PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isDownloading ? null : _downloadCard,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    icon: _isDownloading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.image_outlined),
                    label: const Text('Download PNG'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: payload.verificationUri.toString()),
                      );
                      if (!mounted) return;
                      CustomNotification.show(
                        context,
                        message: 'Verification URL copied to clipboard.',
                      );
                    },
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Copy URL'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (AppConfig.idCardVerificationBaseUrl.trim().isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'Set ID_CARD_VERIFY_URL during web build for public QR verification links.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
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
    );
  }

  Widget _buildModernIdCard(ThemeData theme, Student student, IdCardPayload payload) {
    final dob = DateFormat('dd MMM yyyy').format(student.dateOfBirth);
    final issuedAt = DateFormat('dd MMM yyyy').format(payload.issuedAt);
    final shortId = student.id.length >= 8
        ? student.id.substring(0, 8).toUpperCase()
        : student.id.toUpperCase();

    return Column(
      children: [
        // ── FRONT SIDE ──
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D253F).withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0D253F),
                    Color(0xFF1B3A5C),
                    Color(0xFF274C77),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Decorative circles
                  Positioned(
                    right: -60,
                    top: -60,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -40,
                    bottom: -40,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.03),
                      ),
                    ),
                  ),
                  // Gold accent line at top
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 4,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFD4A843),
                            Color(0xFFF0C75E),
                            Color(0xFFD4A843),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Logo + Title
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFD4A843), Color(0xFFF0C75E)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.menu_book_rounded,
                                color: Color(0xFF0D253F),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'IQRA LIBRARY',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2.5,
                                      fontSize: 17,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'STUDENT IDENTIFICATION CARD',
                                    style: TextStyle(
                                      color: const Color(0xFFD4A843).withValues(alpha: 0.9),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Divider
                        Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: 0.15),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        // Body: Photo + Info
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Profile Photo
                            Container(
                              width: 100,
                              height: 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFD4A843).withValues(alpha: 0.6),
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: _buildProfileImage(student, theme),
                              ),
                            ),
                            const SizedBox(width: 18),
                            // Student Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    student.fullName.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      letterSpacing: 0.8,
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInfoField('Student ID', shortId),
                                  const SizedBox(height: 6),
                                  _buildInfoField('Date of Birth', dob),
                                  const SizedBox(height: 6),
                                  _buildInfoField('Seat No.', student.seatNumber ?? 'N/A'),
                                  const SizedBox(height: 6),
                                  _buildInfoField('Email', student.email),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Footer
                        Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: 0.1),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.verified_outlined,
                                  size: 13,
                                  color: const Color(0xFFD4A843).withValues(alpha: 0.8),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Issued: $issuedAt',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4A843).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFD4A843).withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Text(
                                'VERIFIED',
                                style: TextStyle(
                                  color: Color(0xFFF0C75E),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
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
            ),
          ),
        ),
        const SizedBox(height: 20),
        // ── BACK SIDE ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: const Color(0xFFE0E0E0),
            ),
          ),
          child: Column(
            children: [
              const Text(
                'SCAN TO VERIFY',
                style: TextStyle(
                  color: Color(0xFF0D253F),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFD4A843).withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: QrImageView(
                  data: payload.qrData,
                  size: 140,
                  padding: EdgeInsets.zero,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF0D253F),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF0D253F),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'This card is the property of IQRA Library.',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'If found, please return to the nearest branch.',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileImage(Student student, ThemeData theme) {
    final hasImage = student.profileImagePath != null &&
        student.profileImagePath!.isNotEmpty;

    if (!hasImage) {
      return _buildInitialsPlaceholder(student);
    }

    // Use FutureBuilder to resolve signed URL from Supabase storage path
    return FutureBuilder<String>(
      future: _resolveImageUrl(student.profileImagePath!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 100,
            height: 120,
            color: const Color(0xFF1B3A5C),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFD4A843),
              ),
            ),
          );
        }

        final imageUrl = snapshot.data;
        if (imageUrl == null || imageUrl.isEmpty) {
          return _buildInitialsPlaceholder(student);
        }

        return Image.network(
          imageUrl,
          fit: BoxFit.cover,
          width: 100,
          height: 120,
          errorBuilder: (context, error, stackTrace) {
            return _buildInitialsPlaceholder(student);
          },
        );
      },
    );
  }

  Future<String> _resolveImageUrl(String path) async {
    final lower = path.toLowerCase();
    // If already a full URL, use it directly
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return path;
    }
    // Otherwise get signed URL from Supabase storage
    try {
      final supabase = ref.read(supabaseServiceProvider);
      final url = await supabase.getProfileImageSignedUrl(path);
      return url ?? '';
    } catch (_) {
      return '';
    }
  }

  Widget _buildInitialsPlaceholder(Student student) {
    return Container(
      width: 100,
      height: 120,
      color: const Color(0xFF1B3A5C),
      child: Center(
        child: Text(
          student.initials,
          style: const TextStyle(
            color: Color(0xFFD4A843),
            fontWeight: FontWeight.w800,
            fontSize: 32,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: const Color(0xFFD4A843).withValues(alpha: 0.8),
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
