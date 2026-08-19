import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../services/model_3d_storage_service.dart';
import '../theme/app_theme.dart';

/// Zone de sélection d'un modèle 3D `.glb`, réutilisable dans le
/// formulaire produit.
///
/// Miroir de [ImagePickerField] côté responsabilités : ce widget
/// délègue entièrement la sélection + copie de fichier à
/// [Model3dStorageService] et communique uniquement le chemin
/// résultant via [onChanged]. Il ne sait pas si ce chemin est "le
/// modèle d'origine" ou "une nouvelle sélection en attente" — c'est
/// au formulaire parent de gérer cette distinction (voir
/// [ProductFormScreen]).
///
/// Contrairement à [ImagePickerField], il n'y a pas d'aperçu visuel
/// (un `.glb` ne se prévisualise pas simplement) : on affiche le nom
/// du fichier avec une icône.
class ModelPickerField extends StatefulWidget {
  final String? modelPath;
  final ValueChanged<String?> onChanged;

  const ModelPickerField({
    super.key,
    required this.modelPath,
    required this.onChanged,
  });

  @override
  State<ModelPickerField> createState() => _ModelPickerFieldState();
}

class _ModelPickerFieldState extends State<ModelPickerField> {
  bool _isPicking = false;

  Future<void> _pickModel() async {
    setState(() => _isPicking = true);
    try {
      final newPath = await Model3dStorageService.instance.pickAndStoreModel();
      if (newPath != null) {
        widget.onChanged(newPath);
      }
      // newPath == null : sélection annulée par l'utilisateur, rien à faire.
    } on Model3dStorageException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Impossible de sélectionner ce modèle 3D.');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _removeModel() {
    widget.onChanged(null);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final hasModel = widget.modelPath != null && widget.modelPath!.trim().isNotEmpty;
    final fileName = hasModel ? p.basename(widget.modelPath!) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Modèle 3D (optionnel)',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                Icons.view_in_ar_outlined,
                color: hasModel ? AppColors.accentDark : AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasModel ? fileName! : 'Aucun modèle sélectionné',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasModel ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: hasModel ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isPicking ? null : _pickModel,
                icon: _isPicking
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.upload_file_outlined, size: 18),
                label: Text(hasModel ? 'Remplacer le modèle' : 'Ajouter un modèle 3D'),
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
            if (hasModel) ...[
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _isPicking ? null : _removeModel,
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