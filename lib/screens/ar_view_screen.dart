import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../models/product.dart';
import '../services/cart_service.dart';
import '../services/model_3d_storage_service.dart';
import '../theme/app_theme.dart';

/// Écran de visualisation AR d'un produit, à partir de son modèle
/// `.glb` déjà stocké localement (voir [Model3dStorageService]).
///
/// Repose sur `model_viewer_plus`, qui embarque le web component
/// Google `<model-viewer>` dans une WebView. Sur Android, l'AR
/// (détection de surface, placement, déplacement, rotation,
/// redimensionnement) est entièrement déléguée à Scene Viewer
/// (application Google), pas à une intégration ARCore directe.
///
/// Ne fait AUCUNE hypothèse sur un hébergement distant : le `.glb`
/// est lu depuis son chemin local via une URI `file://`.
class ArViewScreen extends StatefulWidget {
  final Product product;

  const ArViewScreen({super.key, required this.product});

  @override
  State<ArViewScreen> createState() => _ArViewScreenState();
}

enum _ArStatus { checking, ready, missingModel, fileNotFound }

class _ArViewScreenState extends State<ArViewScreen> {
  _ArStatus _status = _ArStatus.checking;
  String? _modelUri;

  @override
  void initState() {
    super.initState();
    _checkModel();
  }

  Future<void> _checkModel() async {
    final path = widget.product.model3d;
    if (path == null || path.trim().isEmpty) {
      setState(() => _status = _ArStatus.missingModel);
      return;
    }

    // Revalidation systématique : le fichier a pu être supprimé ou
    // déplacé depuis la dernière fois que la fiche produit a été
    // affichée (l'existence n'est jamais supposée à partir du seul
    // champ `model3d` non nul).
    final exists = await Model3dStorageService.instance.exists(path);
    if (!mounted) return;

    if (!exists) {
      setState(() => _status = _ArStatus.fileNotFound);
      return;
    }

    setState(() {
      _modelUri = _toModelUri(path);
      _status = _ArStatus.ready;
    });
  }

  /// Convertit un chemin de fichier local en URI `file://` correctement
  /// encodée. Les assets embarqués (`assets/...`) sont laissés tels
  /// quels : `model_viewer_plus` sait les charger directement.
  String _toModelUri(String path) {
    if (path.startsWith('assets/')) return path;
    return Uri.file(path).toString();
  }

  Future<void> _addToCart() async {
    final added = await CartService.instance.addProduct(widget.product, quantity: 1);
    if (!mounted) return;

    final message = added > 0
        ? '${widget.product.name} ajouté au panier.'
        : "Impossible d'ajouter ce produit : stock insuffisant.";
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('AR — ${widget.product.name}'),
      ),
      body: _buildBody(),
      bottomNavigationBar: _status == _ArStatus.ready ? _buildCartBar() : null,
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _ArStatus.checking:
        return const Center(child: CircularProgressIndicator());

      case _ArStatus.missingModel:
        return _buildError(
          icon: Icons.view_in_ar_outlined,
          title: 'Aucun modèle 3D',
          message: 'Ce produit ne possède pas de modèle 3D associé.',
        );

      case _ArStatus.fileNotFound:
        return _buildError(
          icon: Icons.error_outline,
          title: 'Modèle introuvable',
          message: 'Le fichier du modèle 3D est introuvable ou a été '
              "supprimé de l'appareil. Réimportez un modèle depuis la "
              'fiche produit.',
        );

      case _ArStatus.ready:
        return _buildViewer();
    }
  }

  Widget _buildViewer() {
    // key sur l'URI : force la reconstruction du widget (et donc de la
    // WebView interne) si jamais le chemin change.
    return ModelViewer(
      key: ValueKey(_modelUri),
      backgroundColor: const Color(0xFF87CEEB),
      src: _modelUri!,
      alt: widget.product.name,
      loading: Loading.eager,
      ar: true,
      // Restreint à Scene Viewer : on cible Android uniquement, pas de
      // repli WebXR-navigateur ni de mode iOS Quick Look.
      arModes: const ['scene-viewer'],
      // 'auto' (défaut) = le modèle peut être redimensionné en AR.
      arScale: ArScale.auto,
      // Table/objet posé au sol, pas sur un mur.
      arPlacement: ArPlacement.floor,
      cameraControls: true,
      autoRotate: false,
      disableZoom: false,
    );
  }

  Widget _buildCartBar() {
    final inStock = widget.product.stock > 0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: inStock ? _addToCart : null,
          icon: const Icon(Icons.add_shopping_cart_outlined, size: 18),
          label: Text(inStock ? 'Ajouter au panier' : 'Rupture de stock'),
        ),
      ),
    );
  }

  Widget _buildError({required IconData icon, required String title, required String message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Retour à la fiche produit'),
            ),
          ],
        ),
      ),
    );
  }
}