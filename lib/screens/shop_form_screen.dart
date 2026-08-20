import 'package:flutter/material.dart';

import '../constants/shop_categories.dart';
import '../database/database_helper.dart' show AuthException;
import '../models/shop.dart';
import '../repositories/shop_repository.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/image_storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/image_picker_field.dart';
import 'login_screen.dart';
import 'shop_detail_screen.dart';
import 'signup_screen.dart';
import '../services/places_service.dart';
import 'place_search_screen.dart';

/// Détermine ce qui doit être affiché à l'ouverture du formulaire :
///
/// En CRÉATION (pas de [ShopFormScreen.shop] fourni) :
/// - [guest] : personne n'est connectée ;
/// - [hasShopElsewhere] : l'utilisateur connecté possède déjà un
///   commerce (règle : 1 utilisateur = 1 commerce maximum) ;
/// - [allowed] : utilisateur connecté sans commerce -> formulaire normal.
///
/// En ÉDITION (un [ShopFormScreen.shop] est fourni) :
/// - [guest] : personne n'est connectée ;
/// - [notOwner] : l'utilisateur connecté n'est pas le propriétaire de
///   CE commerce (y compris commerce seedé sans owner_id) ;
/// - [allowed] : l'utilisateur connecté est bien le propriétaire.
enum _ShopAccess { guest, hasShopElsewhere, notOwner, allowed }

/// Formulaire d'ajout / modification d'un commerce.
///
/// - Création : réservée à un utilisateur connecté sans commerce.
/// - Édition : réservée au propriétaire connecté du commerce concerné
///   (un commerce seedé sans owner_id n'est administrable par
///   personne).
/// - L'adresse est FACULTATIVE (commerce en ligne / non physique).
/// - La catégorie est choisie dans [kShopCategories] (pas de texte
///   libre).
class ShopFormScreen extends StatefulWidget {
  final Shop? shop;

  const ShopFormScreen({super.key, this.shop});

  @override
  State<ShopFormScreen> createState() => _ShopFormScreenState();
}

class _ShopFormScreenState extends State<ShopFormScreen> {
  final ShopRepository _shopRepository = ShopRepository();

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _addressController;

  String? _selectedCategory;

  bool _isSaving = false;
  bool _savedSuccessfully = false;

  String? _originalImagePath;
  String? _currentImagePath;

  bool get _isEditing => widget.shop != null;

  late final Future<_ShopAccess> _accessFuture;
  bool _hasPhysicalLocation = false;
  String? _selectedPlaceName;
  String? _selectedAddress;
  double? _selectedLatitude;
  double? _selectedLongitude;
  String? _selectedPlaceId;
  String? _locationError;
  /// Renseigné quand l'utilisateur possède déjà un commerce (création
  /// refusée), pour proposer un lien direct vers celui-ci.
  int? _existingShopId;

  @override
  void initState() {
    super.initState();
    final shop = widget.shop;
    _nameController = TextEditingController(text: shop?.name ?? '');
    _descriptionController = TextEditingController(text: shop?.description ?? '');
    _hasPhysicalLocation = shop?.hasAddress ?? false;
    _selectedAddress = shop?.address;
    _selectedLatitude = shop?.latitude;
    _selectedLongitude = shop?.longitude;
    _selectedPlaceId = shop?.googlePlaceId;
    _selectedCategory = (shop?.category.isNotEmpty ?? false) ? shop!.category : null;

    _originalImagePath = (shop?.image.isNotEmpty ?? false) ? shop!.image : null;
    _currentImagePath = _originalImagePath;

    _accessFuture = _resolveAccess();
  }

  /// Résout l'accès au formulaire selon le mode (création/édition).
  Future<_ShopAccess> _resolveAccess() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return _ShopAccess.guest;

    if (_isEditing) {
      // Édition : seul le propriétaire connecté peut administrer CE
      // commerce. Un commerce seedé (ownerId == null) n'est
      // administrable par personne via cet écran.
      final ownerId = widget.shop!.ownerId;
      if (ownerId == null || ownerId != user.id) {
        return _ShopAccess.notOwner;
      }
      return _ShopAccess.allowed;
    }

    // Création : réservée à un utilisateur sans commerce existant.
    // `GET /shops/me` répond 404 (`ApiException`) si l'utilisateur n'a
    // pas encore de commerce ; ce cas se traduit ici par `allowed`,
    // comme le `null` de l'ancien `getShopByOwnerId`.
    try {
      final existing = await _shopRepository.getMine();
      _existingShopId = existing.id;
      return _ShopAccess.hasShopElsewhere;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return _ShopAccess.allowed;
      rethrow;
    }
  }

  List<DropdownMenuItem<String>> _categoryItems() {
    final items = <String>[...kShopCategories];
    final current = widget.shop?.category;
    // Si le commerce édité a une catégorie "legacy" absente de la
    // liste prédéfinie, on l'ajoute pour ne pas perdre la donnée /
    // forcer un changement non voulu.
    if (current != null && current.trim().isNotEmpty && !items.contains(current)) {
      items.insert(0, current);
    }
    return items
        .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
        .toList();
  }

  void _onImageChanged(String? newPath) {
    final pending = _currentImagePath;
    if (pending != null && pending != _originalImagePath) {
      ImageStorageService.instance.deleteImage(pending);
    }
    setState(() => _currentImagePath = newPath);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();

    if (!_savedSuccessfully &&
        _currentImagePath != null &&
        _currentImagePath != _originalImagePath) {
      ImageStorageService.instance.deleteImage(_currentImagePath).ignore();
    }

    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Un commerce physique doit avoir un emplacement. Les anciens
    // commerces (adresse texte, sans coordonnées) restent valides :
    // seule l'ABSENCE totale d'adresse bloque l'enregistrement.
    if (_hasPhysicalLocation &&
        (_selectedAddress == null || _selectedAddress!.trim().isEmpty)) {
      setState(() => _locationError = 'Veuillez choisir un emplacement.');
      return;
    }
    setState(() => _locationError = null);

    setState(() => _isSaving = true);

    final imageChanged = _currentImagePath != _originalImagePath;
    final finalImagePath = _currentImagePath ?? '';

    final shopData = Shop(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      address: _hasPhysicalLocation ? _selectedAddress : null,
      latitude: _hasPhysicalLocation ? _selectedLatitude : null,
      longitude: _hasPhysicalLocation ? _selectedLongitude : null,
      googlePlaceId: _hasPhysicalLocation ? _selectedPlaceId : null,
      category: _selectedCategory ?? '',
      image: finalImagePath,
    );

    try {
      if (_isEditing && widget.shop?.id != null) {
        final user = AuthService.instance.currentUser;
        if (user == null) {
          throw const AuthException('Vous devez être connecté.');
        }
        // L'ownership est revérifiée côté backend
        // (`assertShopOwnership`, réponse 403 sinon) : plus besoin
        // d'un appel dédié avant l'update, même défense en
        // profondeur qu'auparavant, désormais assurée par le serveur.
        await _shopRepository.update(widget.shop!.id!, shopData);
      } else {
        final user = AuthService.instance.currentUser;
        if (user == null) {
          throw const AuthException(
            'Vous devez être connecté pour créer un commerce.',
          );
        }
        await _shopRepository.create(shopData);
      }

      if (imageChanged && _originalImagePath != null) {
        await ImageStorageService.instance.deleteImage(_originalImagePath);
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
  Future<void> _pickLocation() async {
    final result = await Navigator.push<PlaceSelection>(
      context,
      MaterialPageRoute(builder: (_) => const PlaceSearchScreen()),
    );
    if (result == null) return;
    setState(() {
      _selectedPlaceName = result.name;
      _selectedAddress = result.formattedAddress;
      _selectedLatitude = result.latitude;
      _selectedLongitude = result.longitude;
      _selectedPlaceId = result.placeId;
      _locationError = null;
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier le commerce' : 'Ajouter un commerce'),
      ),
      body: FutureBuilder<_ShopAccess>(
        future: _accessFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          switch (snapshot.data ?? _ShopAccess.guest) {
            case _ShopAccess.guest:
              return _buildGuestBlock();
            case _ShopAccess.hasShopElsewhere:
              return _buildHasShopBlock();
            case _ShopAccess.notOwner:
              return _buildNotOwnerBlock();
            case _ShopAccess.allowed:
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
              'Vous devez être connecté pour créer un commerce.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connectez-vous ou créez un compte pour continuer.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
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

  Widget _buildHasShopBlock() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text(
              'Vous possédez déjà un commerce.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Un utilisateur ne peut créer qu\'un seul commerce.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            if (_existingShopId != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => ShopDetailScreen(shopId: _existingShopId!),
                    ),
                  ),
                  child: const Text('Voir mon commerce'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Affiché en édition si l'utilisateur connecté n'est pas le
  /// propriétaire de ce commerce (y compris commerce seedé sans
  /// propriétaire).
  Widget _buildNotOwnerBlock() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text(
              'Vous ne pouvez pas modifier ce commerce.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Seul le propriétaire d\'un commerce peut le modifier ou le supprimer.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
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
            ImagePickerField(
              imagePath: _currentImagePath,
              ownerType: ImageOwnerType.shop,
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Commerce physique'),
              subtitle: const Text('Activez si ce commerce a un emplacement réel.'),
              value: _hasPhysicalLocation,
              onChanged: (value) {
                setState(() {
                  _hasPhysicalLocation = value;
                  if (!value) {
                    _selectedPlaceName = null;
                    _selectedAddress = null;
                    _selectedLatitude = null;
                    _selectedLongitude = null;
                    _selectedPlaceId = null;
                  }
                  _locationError = null;
                });
              },
            ),
            if (_hasPhysicalLocation) ...[
              const SizedBox(height: 8),
              const Text(
                '📍 Emplacement',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 8),
              if (_selectedAddress != null && _selectedAddress!.trim().isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.place, color: AppColors.accentDark),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_selectedPlaceName != null && _selectedPlaceName!.isNotEmpty)
                              Text(_selectedPlaceName!,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              _selectedAddress!,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Text(
                  'Aucun emplacement sélectionné.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _pickLocation,
                icon: const Icon(Icons.location_searching, size: 18),
                label: Text(
                  (_selectedAddress == null || _selectedAddress!.isEmpty)
                      ? 'Choisir l\'emplacement'
                      : 'Modifier l\'emplacement',
                ),
              ),
              if (_locationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _locationError!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 12),
                  ),
                ),
            ],
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(labelText: 'Catégorie *'),
              items: _categoryItems(),
              onChanged: (value) => setState(() => _selectedCategory = value),
              validator: (v) =>
              (v == null || v.isEmpty) ? 'La catégorie est obligatoire' : null,
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : Text(_isEditing ? 'Enregistrer les modifications' : 'Ajouter le commerce'),
            ),
          ],
        ),
      ),
    );
  }
}