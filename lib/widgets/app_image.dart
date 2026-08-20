import 'dart:io';

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// Affiche :
/// - un asset Flutter (`assets/...`) via `Image.asset` ;
/// - une référence distante backend (`/files/...`, ex. celle
///   renvoyée par `POST /uploads/image`) via `Image.network`,
///   résolue avec `ApiClient.instance.baseUrl` ;
/// - un fichier local (chemin absolu, ex. le fichier temporaire tout
///   juste sélectionné par `image_picker`, avant la fin de l'upload)
///   via `Image.file` ;
/// - un fallback visuel propre si le chemin est vide, nul, ou si
///   l'image est illisible/inexistante/inaccessible.
///
/// Ne fait jamais planter l'application : toute erreur de chargement
/// (asset manquant, fichier local absent, échec réseau...) retombe
/// sur [_buildFallback].
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
    } else if (_isRemoteReference(imagePath)) {
      content = Image.network(
        _resolveRemoteUrl(imagePath),
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _buildLoading();
        },
        errorBuilder: (context, error, stackTrace) => _buildFallback(),
      );
    } else {
      // Chemin local absolu : cas du fichier temporaire tout juste
      // sélectionné par le picker, affiché immédiatement pendant que
      // l'upload backend est encore en cours.
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

  /// Référence distante renvoyée par le backend (`POST /uploads/...`),
  /// toujours de la forme `/files/...` (voir contrat `/uploads`).
  bool _isRemoteReference(String imagePath) => imagePath.startsWith('/files/');

  String _resolveRemoteUrl(String imagePath) {
    return '${ApiClient.instance.baseUrl}$imagePath';
  }

  Widget _buildLoading() {
    return Container(
      width: width,
      height: height,
      color: AppColors.surface,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

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