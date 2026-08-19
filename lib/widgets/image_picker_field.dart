import 'package:flutter/material.dart';

import '../services/image_storage_service.dart';
import '../theme/app_theme.dart';
import 'app_image.dart';

/// Zone de sélection d'image réutilisable pour tout formulaire
/// (produit, commerce, et plus tard utilisateur).
///
/// Ce widget est volontairement "bête" côté persistance : il délègue
/// entièrement la sélection + copie de fichier à
/// [ImageStorageService] et communique uniquement le chemin résultant
/// via [onChanged]. Il ne sait pas si ce chemin est "l'image
/// d'origine" ou "une nouvelle sélection en attente" — c'est au
/// formulaire parent de gérer cette distinction (voir
/// [ProductFormScreen] / [ShopFormScreen]).
class ImagePickerField extends StatefulWidget {
  final String? imagePath;
  final ImageOwnerType ownerType;
  final ValueChanged<String?> onChanged;

  const ImagePickerField({
    super.key,
    required this.imagePath,
    required this.ownerType,
    required this.onChanged,
  });

  @override
  State<ImagePickerField> createState() => _ImagePickerFieldState();
}

class _ImagePickerFieldState extends State<ImagePickerField> {
  bool _isPicking = false;

  Future<void> _pickImage() async {
    setState(() => _isPicking = true);
    try {
      final newPath = await ImageStorageService.instance.pickAndStoreImage(
        ownerType: widget.ownerType,
      );
      if (newPath != null) {
        widget.onChanged(newPath);
      }
      // newPath == null : sélection annulée par l'utilisateur, rien à faire.
    } on ImageStorageException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Impossible de sélectionner cette image.');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _removeImage() {
    widget.onChanged(null);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.imagePath != null && widget.imagePath!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 1.6,
            child: AppImage(
              path: widget.imagePath,
              fallbackIcon: Icons.add_photo_alternate_outlined,
              fallbackIconSize: 40,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isPicking ? null : _pickImage,
                icon: _isPicking
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(hasImage ? "Changer l'image" : 'Choisir une image'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accentDark,
                  side: const BorderSide(color: AppColors.accent),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            if (hasImage) ...[
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _isPicking ? null : _removeImage,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Supprimer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}