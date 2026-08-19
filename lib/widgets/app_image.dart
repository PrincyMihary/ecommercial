import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Affiche :
/// - un asset Flutter (`assets/...`) via `Image.asset` ;
/// - un fichier local du stockage privé (chemin absolu, ex. celui
///   produit par `ImageStorageService`) via `Image.file` ;
/// - un fallback visuel propre si le chemin est vide, nul, ou si le
///   fichier est illisible/inexistant.
///
/// Ne fait jamais planter l'application : toute erreur de lecture
/// (asset manquant, fichier local absent ou corrompu) retombe sur
/// [_buildFallback].
class AppImage extends StatelessWidget {
  final String? path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData fallbackIcon;
  final double fallbackIconSize;
  final BorderRadius? borderRadius;

  const AppImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.image_outlined,
    this.fallbackIconSize = 40,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final imagePath = path;

    final Widget content;
    if (imagePath == null || imagePath.trim().isEmpty) {
      content = _buildFallback();
    } else if (_isAsset(imagePath)) {
      content = Image.asset(
        imagePath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildFallback(),
      );
    } else {
      content = Image.file(
        File(imagePath),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildFallback(),
      );
    }

    if (borderRadius == null) return content;

    return ClipRRect(
      borderRadius: borderRadius!,
      child: content,
    );
  }

  bool _isAsset(String imagePath) => imagePath.startsWith('assets/');

  Widget _buildFallback() {
    return Container(
      width: width,
      height: height,
      color: AppColors.surface,
      alignment: Alignment.center,
      child: Icon(
        fallbackIcon,
        size: fallbackIconSize,
        color: AppColors.textSecondary,
      ),
    );
  }
}