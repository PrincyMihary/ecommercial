import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../models/product.dart';
import '../services/api_client.dart';
import '../services/cart_service.dart';
import '../services/model_3d_storage_service.dart';
import '../theme/app_theme.dart';

/// Écran de visualisation AR d'un produit, à partir de son modèle
/// `.glb` (voir [Model3dStorageService]).
///
/// Repose sur `model_viewer_plus`, qui embarque le web component
/// Google `<model-viewer>` dans une WebView. Sur Android, l'AR
/// (détection de surface, placement, déplacement, rotation,
/// redimensionnement) est entièrement déléguée à Scene Viewer
/// (application Google), pas à une intégration ARCore directe.
///
/// Le `.glb` peut être :
/// - un asset embarqué (`assets/...`) ;
/// - une référence backend distante (`/files/models/...`, cas normal
///   depuis la migration vers le stockage serveur) ;
/// - à titre de compatibilité, un chemin de fichier local absolu
///   (`file://...`).
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
  String? _posterUri;

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

    // Revalidation systématique : la référence a pu devenir invalide
    // depuis la dernière fois que la fiche produit a été affichée
    // (l'existence n'est jamais supposée à partir du seul champ
    // `model3d` non nul). Pour une référence distante, ceci ne
    // vérifie que la forme de la référence (préfixe `/files/`), pas
    // sa disponibilité réseau réelle : un échec réseau au chargement
    // est géré séparément par `<model-viewer>` lui-même (voir
    // `_buildViewer`, écouteur d'erreur natif).
    final exists = await Model3dStorageService.instance.exists(path);
    if (!mounted) return;

    if (!exists) {
      setState(() => _status = _ArStatus.fileNotFound);
      return;
    }

    setState(() {
      _modelUri = _resolveReference(path);
      // Le poster (image 2D) est affiché instantanément par
      // <model-viewer> pendant que le .glb, potentiellement volumineux,
      // continue de charger en arrière-plan (voir `reveal: auto` dans
      // `_buildViewer`) : c'est ce qui règle le "rien ne s'affiche
      // pendant le chargement" pour les modèles lourds. Fallback sur
      // le modèle lui-même si le produit n'a pas d'image.
      final image = widget.product.image;
      _posterUri = image.trim().isEmpty ? null : _resolveReference(image);
      _status = _ArStatus.ready;
    });
  }

  /// Résout une référence stockée (asset, backend distant, ou chemin
  /// local legacy) en une URI/URL directement exploitable par
  /// `<model-viewer>` (paramètres `src`/`poster`, qui acceptent tous
  /// deux une URL ou un chemin d'asset).
  String _resolveReference(String reference) {
    if (reference.startsWith('assets/')) return reference;
    if (reference.startsWith('/files/')) {
      return '${ApiClient.instance.baseUrl}$reference';
    }
    // Compatibilité : ancien chemin de fichier local absolu.
    return Uri.file(reference).toString();
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
          message: 'Le modèle 3D est introuvable ou a été supprimé. '
              'Réimportez un modèle depuis la fiche produit.',
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
      poster: _posterUri,
      // "auto" (comportement demandé) : le poster (image produit) est
      // affiché immédiatement, puis remplacé automatiquement par le
      // modèle 3D dès que celui-ci a fini de charger — utile en
      // particulier pour un .glb volumineux téléchargé depuis le
      // backend, pour éviter un écran vide pendant l'attente.
      reveal: Reveal.auto,
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