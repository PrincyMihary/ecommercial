import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'api_client.dart';

/// Type de propriétaire d'une image, utilisé pour renseigner le
/// paramètre `owner` de `POST /uploads/image?owner=...`.
///
/// `user` n'est pas encore exploité par le backend (pas de
/// fonctionnalité User dans le projet actuel) mais l'API est prête à
/// l'accueillir sans modification.
enum ImageOwnerType { shop, product, user }

/// Erreur métier levée par [ImageStorageService], avec un message déjà
/// adapté à un affichage utilisateur (SnackBar, dialogue...).
class ImageStorageException implements Exception {
  final String message;

  const ImageStorageException(this.message);

  @override
  String toString() => message;
}

/// Service central de gestion des images de l'application.
///
/// Depuis la migration vers le backend, ce service n'est PLUS un
/// stockage local permanent : il se contente de
/// - ouvrir le sélecteur d'IMAGES du système via `image_picker` ;
/// - envoyer le fichier temporairement sélectionné au backend via
///   `POST /uploads/image?owner=...` (multipart, champ `file`) ;
/// - retourner la référence distante (`path`) renvoyée par le serveur ;
/// - supprimer une référence distante via `DELETE /uploads`.
///
/// Le fichier sélectionné par `image_picker` ne sert que de source au
/// multipart : il n'est jamais copié dans
/// `ApplicationDocumentsDirectory`. Le backend est l'unique stockage
/// définitif et génère lui-même le nom de fichier final.
///
/// Ce service ne connaît ni Product, ni Shop : il ne manipule que des
/// références de fichiers. Les écrans/formulaires restent
/// responsables de la logique métier (quand uploader, quand supprimer
/// l'ancienne image, quand mettre à jour le commerce/produit).
class ImageStorageService {
  ImageStorageService._();

  static final ImageStorageService instance = ImageStorageService._();

  static const List<String> _allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

  /// Taille maximale acceptée pour une image (8 Mo), vérifiée
  /// côté Flutter avant l'envoi, en plus de toute limite backend.
  static const int _maxSizeBytes = 8 * 1024 * 1024;

  /// Ouvre le sélecteur d'images du système via `image_picker`, puis
  /// envoie l'image choisie au backend pour [ownerType].
  ///
  /// Retourne la référence distante (`path`, ex :
  /// `/files/products/product_....jpg`), ou `null` si l'utilisateur a
  /// annulé la sélection. Lève une [ImageStorageException] en cas de
  /// fichier invalide ou d'erreur d'envoi.
  Future<String?> pickAndStoreImage({required ImageOwnerType ownerType}) async {
    final ImagePicker picker = ImagePicker();
    XFile? pickedFile;

    try {
      pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
    } catch (e) {
      throw const ImageStorageException(
        "Impossible d'ouvrir le sélecteur d'images.",
      );
    }

    if (pickedFile == null) {
      // Sélection annulée par l'utilisateur : pas une erreur.
      return null;
    }

    return storeImageFromPath(sourcePath: pickedFile.path, ownerType: ownerType);
  }

  /// Valide puis envoie une image déjà présente sur l'appareil (à
  /// [sourcePath]) au backend, et retourne la référence distante
  /// (`path`) renvoyée par le serveur.
  ///
  /// [sourcePath] n'est utilisé que comme source temporaire du
  /// multipart ; il n'est jamais copié dans un stockage local
  /// permanent.
  Future<String> storeImageFromPath({
    required String sourcePath,
    required ImageOwnerType ownerType,
  }) async {
    final sourceFile = File(sourcePath);

    if (!await sourceFile.exists()) {
      throw const ImageStorageException('Le fichier sélectionné est introuvable.');
    }

    final extension = p.extension(sourcePath).replaceFirst('.', '').toLowerCase();
    if (!_allowedExtensions.contains(extension)) {
      throw ImageStorageException(
        'Format d\'image non supporté (.$extension). '
            'Formats acceptés : ${_allowedExtensions.join(', ')}.',
      );
    }

    final int sizeBytes;
    try {
      sizeBytes = await sourceFile.length();
    } catch (e) {
      throw const ImageStorageException('Impossible de lire le fichier sélectionné.');
    }

    if (sizeBytes > _maxSizeBytes) {
      throw const ImageStorageException('Image trop volumineuse (maximum 8 Mo).');
    }

    try {
      final response = await ApiClient.instance.postMultipart(
        '/uploads/image',
        filePath: sourcePath,
        queryParams: {'owner': _ownerParam(ownerType)},
      ) as Map<String, dynamic>;

      final path = response['path'] as String?;
      if (path == null || path.isEmpty) {
        throw const ImageStorageException(
          "Réponse du serveur invalide lors de l'envoi de l'image.",
        );
      }
      return path;
    } on ApiException catch (e) {
      throw ImageStorageException("Erreur lors de l'envoi de l'image : ${e.message}");
    }
  }

  /// Supprime une référence d'image distante, de façon "best effort".
  ///
  /// - Ne fait rien si [imagePath] est nul ou vide.
  /// - Ne fait rien si le chemin correspond à un asset embarqué
  ///   (`assets/...`) : ces fichiers ne sont jamais gérés par ce
  ///   service.
  /// - Ne fait rien si la référence n'est pas une référence distante
  ///   connue (`/files/...`) : ce service ne supprime plus jamais de
  ///   fichier local.
  /// - Toute erreur (réseau, 404 backend...) est avalée
  ///   silencieusement : la suppression backend est elle-même
  ///   "best effort" (voir contrat `DELETE /uploads`, réponse 204).
  Future<void> deleteImage(String? imagePath) async {
    if (imagePath == null || imagePath.trim().isEmpty) return;
    if (_isAsset(imagePath)) return;
    if (!_isRemoteReference(imagePath)) return;

    try {
      await ApiClient.instance.delete('/uploads', body: {'path': imagePath});
    } catch (_) {
      // Suppression best-effort : on n'interrompt jamais l'appelant.
    }
  }

  /// Indique si la référence est exploitable telle quelle (asset ou
  /// référence distante). La disponibilité réelle d'une référence
  /// distante n'est pas vérifiée ici (pas d'appel réseau) : c'est au
  /// widget d'affichage (ex: `AppImage`) de gérer un éventuel échec de
  /// chargement via son `errorBuilder`.
  Future<bool> exists(String? imagePath) async {
    if (imagePath == null || imagePath.trim().isEmpty) return false;
    return _isAsset(imagePath) || _isRemoteReference(imagePath);
  }

  bool _isAsset(String imagePath) => imagePath.startsWith('assets/');

  bool _isRemoteReference(String imagePath) => imagePath.startsWith('/files/');

  String _ownerParam(ImageOwnerType ownerType) {
    switch (ownerType) {
      case ImageOwnerType.shop:
        return 'shop';
      case ImageOwnerType.product:
        return 'product';
      case ImageOwnerType.user:
        return 'user';
    }
  }
}