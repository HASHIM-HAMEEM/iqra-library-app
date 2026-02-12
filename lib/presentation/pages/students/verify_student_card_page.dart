import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:library_registration_app/core/theme/app_colors.dart';
import 'package:library_registration_app/core/theme/design_tokens.dart';
import 'package:library_registration_app/domain/entities/id_card_verification.dart';
import 'package:library_registration_app/presentation/providers/database_provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class VerifyStudentCardPage extends ConsumerStatefulWidget {
  const VerifyStudentCardPage({required this.query, super.key});

  final Map<String, String> query;

  @override
  ConsumerState<VerifyStudentCardPage> createState() =>
      _VerifyStudentCardPageState();
}

class _VerifyStudentCardPageState extends ConsumerState<VerifyStudentCardPage> {
  Future<IdCardVerification?>? _verificationFuture;
  String? _error;
  String? _scannedToken;
  bool _isScanning = false;
  final TextEditingController _manualTokenController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );

  @override
  void initState() {
    super.initState();
    final token = _extractToken();
    if (token != null && token.trim().isNotEmpty) {
      _verifyToken(token);
    } else {
      _isScanning = true;
    }
  }

  @override
  void dispose() {
    _manualTokenController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  String? _extractToken() {
    if (_scannedToken != null) return _scannedToken;

    String? pick(String? v) =>
        (v == null || v.trim().isEmpty) ? null : v.trim();

    // Primary path: go_router query parameters.
    final direct = pick(widget.query['tok']);
    if (direct != null) return direct;

    // Defensive: direct browser URL (path strategy).
    final base = Uri.base;
    final fromQuery = pick(base.queryParameters['tok']);
    if (fromQuery != null) return fromQuery;

    // Defensive: legacy hash URLs like `/#/verify-card?tok=...`
    final frag = base.fragment; // e.g. "/verify-card?tok=abc"
    final qIndex = frag.indexOf('?');
    if (qIndex != -1 && qIndex + 1 < frag.length) {
      try {
        final qp = Uri.splitQueryString(frag.substring(qIndex + 1));
        final fromFrag = pick(qp['tok']);
        if (fromFrag != null) return fromFrag;
      } catch (_) {}
    }
    return null;
  }

  void _verifyToken(String token) {
    setState(() {
      _isScanning = false;
      _scannedToken = token;
      _error = null;
    });

    try {
      final service = ref.read(supabaseServiceProvider);
      setState(() {
        _verificationFuture = service.verifyStudentIdCard(token);
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize verification: $e';
      });
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null) continue;

      // Try to extract 'tok' parameter if it's a URL
      String? token;
      try {
        final uri = Uri.parse(rawValue);
        token = uri.queryParameters['tok'];
      } catch (_) {
        // Not a URL, checking if it might be the token itself
      }

      // If not a URL parameter, assumed to be the token itself
      token ??= rawValue;

      if (token.trim().isNotEmpty) {
        _verifyToken(token);
        break;
      }
    }
  }

  Widget _buildWebManualEntry(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Student ID Card'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.qr_code_scanner,
                  size: 64,
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 24),
                Text(
                  'Camera scanning is not available on web',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please enter the verification token manually or scan the QR code using a mobile device.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _manualTokenController,
                  decoration: InputDecoration(
                    labelText: 'Verification Token',
                    hintText: 'Enter token from QR code',
                    prefixIcon: const Icon(Icons.vpn_key),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.borderMd,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    final token = _manualTokenController.text.trim();
                    if (token.isNotEmpty) {
                      _verifyToken(token);
                    }
                  },
                  icon: const Icon(Icons.verified_user),
                  label: const Text('Verify'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    // Allow pasting a full URL and extracting token
                    final text = _manualTokenController.text.trim();
                    if (text.isEmpty) return;
                    try {
                      final uri = Uri.parse(text);
                      final tok = uri.queryParameters['tok'];
                      if (tok != null && tok.isNotEmpty) {
                        _verifyToken(tok);
                      }
                    } catch (_) {
                      // If not a valid URL, try using the text as token directly
                      _verifyToken(text);
                    }
                  },
                  child: const Text('Paste URL & Extract Token'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final token = _extractToken();

    // 1. Show Scanner if no token and in scanning mode
    if ((token == null || token.isEmpty) && _isScanning) {
      // Web doesn't support camera scanning - show manual entry
      if (kIsWeb) {
        return _buildWebManualEntry(context);
      }

      return Scaffold(
        appBar: AppBar(
          title: const Text('Scan Student ID Card'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.flash_on),
              onPressed: () => _scannerController.toggleTorch(),
              tooltip: 'Toggle Flash',
            ),
            IconButton(
              icon: const Icon(Icons.flip_camera_ios),
              onPressed: () => _scannerController.switchCamera(),
              tooltip: 'Switch Camera',
            ),
          ],
        ),
        body: Stack(
          children: [
            MobileScanner(
              controller: _scannerController,
              onDetect: _onBarcodeDetected,
            ),
            const ScannerOverlay(),
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Align QR code within the frame',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 2. Handle missing token case (manual entry or error state if not scanning)
    if (token == null || token.trim().isEmpty) {
      return _buildShell(
        context,
        title: 'Invalid QR Data',
        icon: Icons.error_outline_rounded,
        color: theme.colorScheme.error,
        body: Column(
          children: [
            const Text('Missing verification token in this QR code.'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _isScanning = true;
                  _scannedToken = null;
                  _error = null;
                });
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Again'),
            ),
          ],
        ),
      );
    }

    // 3. Handle Initialization Errors
    if (_error != null) {
      return _buildShell(
        context,
        title: 'Error',
        icon: Icons.error_outline_rounded,
        color: theme.colorScheme.error,
        body: Column(
          children: [
            Text(_error!),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _isScanning = true;
                  _scannedToken = null;
                  _error = null;
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    // 4. Handle Verification Future
    return FutureBuilder<IdCardVerification?>(
      future: _verificationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            _verificationFuture == null) {
          return _buildShell(
            context,
            title: 'Verifying...',
            icon: Icons.shield_outlined,
            color: theme.colorScheme.primary,
            body: const CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return _buildShell(
            context,
            title: 'Verification Failed',
            icon: Icons.error_outline_rounded,
            color: theme.colorScheme.error,
            body: Column(
              children: [
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _isScanning = true;
                      _scannedToken = null;
                      _error = null;
                      _verificationFuture = null;
                    });
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan Again'),
                ),
              ],
            ),
          );
        }

        final verification = snapshot.data;
        if (verification == null) {
          return _buildShell(
            context,
            title: 'Verification Failed',
            icon: Icons.cancel_outlined,
            color: theme.colorScheme.error,
            body: Column(
              children: [
                const Text(
                  'No matching student was found for this ID card token.',
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _isScanning = true;
                      _scannedToken = null;
                      _error = null;
                      _verificationFuture = null;
                    });
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan Again'),
                ),
              ],
            ),
          );
        }

        return _buildVerifiedView(context, verification);
      },
    );
  }

  Widget _buildVerifiedView(BuildContext context, IdCardVerification v) {
    final theme = Theme.of(context);
    final issuedAt = v.issuedAt;
    final hasActive = v.hasActiveSubscription;
    final bool hasSummary = hasActive != null;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('ID Card Verification'),
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Success Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: AppRadius.borderXl,
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.verified_user_rounded,
                          size: 64,
                          color: AppColors.success,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Card Verified',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          v.fullName.toUpperCase(),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow('Student ID', v.shortStudentId),
                        _buildInfoRow('Seat', v.seatNumber ?? 'N/A'),
                        _buildInfoRow(
                          'Issued',
                          issuedAt != null
                              ? DateFormat(
                                  'dd MMM yyyy',
                                ).format(issuedAt.toLocal())
                              : 'Unknown',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Subscription summary card (from RPC; no table reads from public clients)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: hasSummary
                          ? (hasActive
                                ? AppColors.success.withValues(alpha: 0.05)
                                : AppColors.warning.withValues(alpha: 0.05))
                          : theme.colorScheme.surfaceContainerLow,
                      borderRadius: AppRadius.borderXl,
                      border: Border.all(
                        color: hasSummary
                            ? (hasActive
                                  ? AppColors.success.withValues(alpha: 0.3)
                                  : AppColors.warning.withValues(alpha: 0.3))
                            : theme.colorScheme.outlineVariant,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              hasSummary
                                  ? (hasActive
                                        ? Icons.check_circle_rounded
                                        : Icons.warning_rounded)
                                  : Icons.help_outline_rounded,
                              color: hasSummary
                                  ? (hasActive
                                        ? AppColors.success
                                        : AppColors.warning)
                                  : theme.colorScheme.onSurfaceVariant,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              hasSummary
                                  ? (hasActive
                                        ? 'Active Subscription'
                                        : 'No Active Subscription')
                                  : 'Subscription Status Unavailable',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: hasSummary
                                    ? (hasActive
                                          ? AppColors.success
                                          : AppColors.warning)
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        if (hasActive == true) ...[
                          const SizedBox(height: 16),
                          if ((v.activePlanName ?? '').trim().isNotEmpty)
                            Text(
                              v.activePlanName!.toUpperCase(),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          if (v.activeEndDate != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Valid until: ${DateFormat('dd MMM yyyy').format(v.activeEndDate!.toLocal())}',
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ] else if (hasActive == false) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Student does not have an active library subscription.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
                          Text(
                            'Subscription info is not available for this verification link yet.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildShell(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required Widget body,
  }) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('ID Card Verification')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: AppRadius.borderXl,
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 56, color: color),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  body,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ScannerOverlay extends StatelessWidget {
  const ScannerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cutoutSize = constraints.maxWidth * 0.7;
        return Stack(
          children: [
            // Semi-transparent background
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.5),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      height: cutoutSize,
                      width: cutoutSize,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Border overlay
            Align(
              alignment: Alignment.center,
              child: Container(
                height: cutoutSize,
                width: cutoutSize,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
