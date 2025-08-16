import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_registration_app/presentation/providers/database_provider.dart';

/// An avatar widget that handles async signed URL generation for storage paths
class AsyncAvatar extends ConsumerWidget {
  const AsyncAvatar({
    super.key,
    required this.imagePath,
    required this.initials,
    this.size = 48,
    this.fallbackIcon,
  });

  final String? imagePath;
  final String initials;
  final double size;
  final IconData? fallbackIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    if (imagePath == null || imagePath!.isEmpty) {
      return _buildPlaceholder(theme);
    }

    final path = imagePath!;
    final lower = path.toLowerCase();

    // Handle existing URLs
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return ClipOval(
        child: Image.network(
          path,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(theme),
        ),
      );
    }

    // Handle local file paths
    if (path.startsWith('/')) {
      try {
        final file = File(path);
        return ClipOval(
          child: Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(theme),
          ),
        );
      } catch (e) {
        return _buildPlaceholder(theme);
      }
    }

    // Handle storage paths - generate signed URL
    final supabaseService = ref.read(supabaseServiceProvider);
    return FutureBuilder<String?>(
      future: supabaseService.getProfileImageSignedUrl(path) as Future<String?>?,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircleAvatar(
            radius: size / 2,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: SizedBox(
              width: size * 0.6,
              height: size * 0.6,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return ClipOval(
            child: Image.network(
              snapshot.data!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildPlaceholder(theme),
            ),
          );
        }

        return _buildPlaceholder(theme);
      },
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    if (fallbackIcon != null) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(
          fallbackIcon!,
          size: size * 0.6,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      );
    }

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: theme.colorScheme.primary,
      child: Text(
        initials,
        style: TextStyle(
          color: theme.colorScheme.onPrimary,
          fontSize: size * 0.35,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}