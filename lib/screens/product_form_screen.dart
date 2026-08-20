import 'package:flutter/material.dart';

import '../models/product.dart';
import '../repositories/product_repository.dart';
import '../repositories/shop_repository.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/image_storage_service.dart';
import '../services/model_3d_storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/image_picker_field.dart';
import '../widgets/model_picker_field.dart';
import 'login_screen.dart';
import 'shop_form_screen.dart';
import 'signup_screen.dart';
import '../constants/product_categories.dart';
/// Détermine l'accès au formulaire produit :
/// - [guest] : personne n'est connectée ;
/// - [noShop] : utilisateur connecté mais sans commerce ;
/// - [wrongShop] : (édition uniquement) le produit édité n'appartient
///   pas au commerce de l'utilisateur connecté ;
/// - [allowed] : utilisateur connecté avec commerce, produit (en
///   édition) appartenant bien à ce commerce.
enum _ProductAccess { guest, noShop, wrongShop, allowed }

/// Formulaire d'ajout / modification d'un produit.
///
/// Le commerce n'est PLUS un choix libre dans le formulaire : il est
/// résolu automatiquement à partir de l'utilisateur connecté
/// (AuthService + ShopRepository.getMine). Un utilisateur ne peut ni
/// créer un produit pour un autre commerce, ni éditer un produit qui
/// n'appartient pas à son propre commerce.
class ProductFormScreen extends StatefulWidget {
  final Product? product;

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final ProductRepository _productRepository = ProductRepository();
  final ShopRepository _shopRepository = ShopRepository();

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  String? _selectedCategory;

  bool _isSaving = false;
  bool _savedSuccessfully = false;

  String? _originalImagePath;
  String? _currentImagePath;

  String? _originalModelPath;
  String? _currentModelPath;

  bool get _isEditing => widget.product != null;

  late final Future<_ProductAccess> _accessFuture;

  /// Commerce de l'utilisateur connecté, résolu par [_resolveAccess].
  /// Utilisé pour rattacher automatiquement le produit, et pour
  /// affichage (nom du commerce, lecture seule).
  int? _myShopId;
  String? _myShopName;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _descriptionController = TextEditingController(text: product?.description ?? '');
    _priceController = TextEditingController(
      text: product != null ? product.price.toString() : '',
    );
    _stockController = TextEditingController(
      text: product != null ? product.stock.toString() : '',
    );
    _selectedCategory = (product?.category.isNotEmpty ?? false) ? product!.category : null;
    _originalImagePath = (product?.image.isNotEmpty ?? false) ? product!.image : null;
    _currentImagePath = _originalImagePath;

    _originalModelPath =
    (product?.model3d?.isNotEmpty ?? false) ? product!.model3d : null;
    _currentModelPath = _originalModelPath;

    _accessFuture = _resolveAccess();
  }

  Future<_ProductAccess> _resolveAccess() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return _ProductAccess.guest;

    // `GET /shops/me` répond 404 (`ApiException`) si l'utilisateur n'a
    // pas encore de commerce ; ce cas se traduit ici par `noShop`,
    // comme le `null` de l'ancien `getShopByOwnerId`.
    try {
      final shop = await _shopRepository.getMine();
      _myShopId = shop.id;
      _myShopName = shop.name;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return _ProductAccess.noShop;
      rethrow;
    }

    if (_isEditing && widget.product!.shopId != _myShopId) {
      return _ProductAccess.wrongShop;
    }
    return _ProductAccess.allowed;
  }

  void _onImageChanged(String? newPath) {
    final pending = _currentImagePath;
    if (pending != null && pending != _originalImagePath) {
      ImageStorageService.instance.deleteImage(pending);
    }
    setState(() => _currentImagePath = newPath);
  }

  void _onModelChanged(String? newPath) {
    final pending = _currentModelPath;
    if (pending != null && pending != _originalModelPath) {
      Model3dStorageService.instance.deleteModel(pending);
    }
    setState(() => _currentModelPath = newPath);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();

    if (!_savedSuccessfully) {
      if (_currentImagePath != null && _currentImagePath != _originalImagePath) {
        ImageStorageService.instance.deleteImage(_currentImagePath).ignore();
      }
      if (_currentModelPath != null && _currentModelPath != _originalModelPath) {
        Model3dStorageService.instance.deleteModel(_currentModelPath).ignore();
      }
    }

    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = AuthService.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez être connecté pour vendre.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final imageChanged = _currentImagePath != _originalImagePath;
    final finalImagePath = _currentImagePath ?? '';

    final modelChanged = _currentModelPath != _originalModelPath;
    final finalModelPath = _currentModelPath;

    // Pas de shopId choisi librement ici : il est résolu côté backend
    // à partir de l'utilisateur connecté (création, voir
    // `Product.toApiJson`) ou déjà vérifié comme correct via
    // _accessFuture (édition). `shopId` n'a ici qu'une valeur locale
    // de confort (`_myShopId ?? 0`) : jamais sérialisée vers l'API.
    final productData = Product(
      shopId: _myShopId ?? widget.product?.shopId ?? 0,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      price: double.parse(_priceController.text.trim().replaceAll(',', '.')),
      stock: int.parse(_stockController.text.trim()),
      category: _selectedCategory ?? '',
      image: finalImagePath,
      model3d: finalModelPath,
    );

    try {
      if (_isEditing && widget.product?.id != null) {
        // L'ownership est revérifiée côté backend
        // (`assertProductOwnership`, réponse 403 sinon) : même
        // défense en profondeur qu'auparavant, désormais assurée par
        // le serveur plutôt que par un appel dédié côté client.
        await _productRepository.update(widget.product!.id!, productData);
      } else {
        // Résout le commerce depuis l'utilisateur connecté côté
        // backend, ignore tout shopId qui aurait pu être fourni :
        // impossible de créer un produit dans le commerce de
        // quelqu'un d'autre.
        await _productRepository.create(productData);
      }

      if (imageChanged && _originalImagePath != null) {
        await ImageStorageService.instance.deleteImage(_originalImagePath);
      }
      if (modelChanged && _originalModelPath != null) {
        await Model3dStorageService.instance.deleteModel(_originalModelPath);
      }

      _savedSuccessfully = true;
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de l'enregistrement : $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier le produit' : 'Ajouter un produit'),
      ),
      body: FutureBuilder<_ProductAccess>(
        future: _accessFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          switch (snapshot.data ?? _ProductAccess.guest) {
            case _ProductAccess.guest:
              return _buildGuestBlock();
            case _ProductAccess.noShop:
              return _buildNoShopBlock();
            case _ProductAccess.wrongShop:
              return _buildWrongShopBlock();
            case _ProductAccess.allowed:
              return _buildForm();
          }
        },
      ),
    );
  }

  Widget _buildGuestBlock() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text(
              'Vous devez être connecté pour vendre.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: const Text('Se connecter'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const SignupScreen()),
                ),
                child: const Text('Créer un compte'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoShopBlock() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_outlined, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text(
              'Vous devez d\'abord créer votre commerce avant d\'ajouter un produit.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const ShopFormScreen()),
                ),
                child: const Text('Créer mon commerce'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWrongShopBlock() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text(
              'Vous ne pouvez modifier que les produits de votre propre commerce.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return AbsorbPointer(
      absorbing: _isSaving,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Commerce résolu automatiquement, affiché en lecture
            // seule : plus de choix libre parmi tous les commerces.
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.storefront_outlined, color: AppColors.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Commerce : ${_myShopName ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ImagePickerField(
              imagePath: _currentImagePath,
              ownerType: ImageOwnerType.product,
              onChanged: _onImageChanged,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nom *'),
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Le nom est obligatoire' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'Prix (Ar) *'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Le prix est obligatoire';
                final parsed = double.tryParse(v.trim().replaceAll(',', '.'));
                if (parsed == null) return 'Prix invalide';
                if (parsed < 0) return 'Le prix doit être positif';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _stockController,
              decoration: const InputDecoration(labelText: 'Stock *'),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Le stock est obligatoire';
                final parsed = int.tryParse(v.trim());
                if (parsed == null) return 'Stock invalide';
                if (parsed < 0) return 'Le stock doit être positif';
                return null;
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(labelText: 'Catégorie *'),
              isExpanded: true,
              items: [
                if (_selectedCategory != null && !kProductCategories.contains(_selectedCategory))
                  DropdownMenuItem<String>(
                    value: _selectedCategory,
                    child: Text('${_selectedCategory!} (ancienne valeur)'),
                  ),
                ...kProductCategories.map(
                      (c) => DropdownMenuItem<String>(value: c, child: Text(c)),
                ),
              ],
              onChanged: (value) => setState(() => _selectedCategory = value),
              validator: (v) =>
              (v == null || v.isEmpty) ? 'Veuillez sélectionner une catégorie' : null,
            ),
            const SizedBox(height: 20),
            ModelPickerField(
              modelPath: _currentModelPath,
              onChanged: _onModelChanged,
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Text(_isEditing ? 'Enregistrer les modifications' : 'Ajouter le produit'),
            ),
          ],
        ),
      ),
    );
  }
}