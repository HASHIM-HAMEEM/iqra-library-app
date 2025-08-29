import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_registration_app/presentation/providers/database_provider.dart';

class ProfilePhotoViewPage extends ConsumerStatefulWidget {
  const ProfilePhotoViewPage({
    super.key,
    required this.imagePath,
    required this.fallbackInitials,
    required this.heroTag,
    this.title,
  });

  final String? imagePath;
  final String fallbackInitials;
  final String heroTag;
  final String? title;

  @override
  ConsumerState<ProfilePhotoViewPage> createState() => _ProfilePhotoViewPageState();
}

class _ProfilePhotoViewPageState extends ConsumerState<ProfilePhotoViewPage> {
  final TransformationController _controller = TransformationController();
  TapDownDetails? _doubleTapDetails;
  String? _resolvedUrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _resolveImageIfNeeded();
  }

  Future<void> _resolveImageIfNeeded() async {
    final path = widget.imagePath;
    if (path == null || path.isEmpty) return;
    final lower = path.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://') || path.startsWith('/')) {
      setState(() => _resolvedUrl = path);
      return;
    }
    setState(() => _loading = true);
    try {
      final supabase = ref.read(supabaseServiceProvider);
      final url = await supabase.getProfileImageSignedUrl(path);
      if (!mounted) return;
      setState(() => _resolvedUrl = url);
    } catch (_) {
      // Ignore and fall back to initials
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleDoubleTap() {
    final details = _doubleTapDetails;
    if (details == null) return;
    const double zoomScale = 2.0;
    final current = _controller.value;
    final isZoomed = current.getMaxScaleOnAxis() > 1.01;
    if (isZoomed) {
      _controller.value = Matrix4.identity();
    } else {
      final tapPosition = details.localPosition;
      final zoomed = Matrix4.identity()
        ..translate(-tapPosition.dx * (zoomScale - 1), -tapPosition.dy * (zoomScale - 1))
        ..scale(zoomScale);
      _controller.value = zoomed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = _resolvedUrl != null && _resolvedUrl!.isNotEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Hero(
                tag: widget.heroTag,
                child: hasImage
                    ? _buildZoomableImage(theme)
                    : _buildFallbackInitials(theme),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  height: kToolbarHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        tooltip: 'Close',
                      ),
                      if (widget.title != null) ...[
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.title!,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (_loading)
              const Center(
                child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomableImage(ThemeData theme) {
    final url = _resolvedUrl!;
    final Widget imageWidget;
    if (url.startsWith('/')) {
      imageWidget = Image.file(File(url), fit: BoxFit.contain);
    } else {
      imageWidget = Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildFallbackInitials(theme),
      );
    }
    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      onDoubleTapDown: (d) => _doubleTapDetails = d,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 1.0,
        maxScale: 4.0,
        clipBehavior: Clip.none,
        child: imageWidget,
      ),
    );
  }

  Widget _buildFallbackInitials(ThemeData theme) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: CircleAvatar(
        radius: 80,
        backgroundColor: theme.colorScheme.primary,
        child: Text(
          widget.fallbackInitials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 48,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}


