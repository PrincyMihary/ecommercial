import 'dart:io';
import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Type de propriétaire d'une image, utilisé pour organiser le stockage
/// en sous-dossiers dédiés :
///
///   <Documents>/uploads/shops/
///   <Documents>/uploads/products/
///   <Documents>/uploads/users/
///
/// `user` n'est pas encore utilisé (pas de fonctionnalité User dans le
/// projet actuel) mais l'API est prête pour l'accueillir sans
/// modification.
enum ImageOwnerType { shop, product, user }

/// Erreur métier levée par [ImageStorageService], avec un message déjà
/// adapté à un affichage utilisateur (SnackBar, dialogue...).
class ImageStorageException implements Exception {
  final String message;

  const ImageStorageException(this.message);

  @override
  String toString() => message;
}

/// Service central de gestion des images locales de l'application.
///
/// Responsabilités :
/// - ouvrir le sélecteur d'IMAGES du système via `image_picker` ;
/// - copier l'image choisie dans le stockage privé de l'app, sous un
///   nom de fichier unique généré (jamais le nom original) ;
/// - supprimer une image du stockage privé ;
/// - vérifier l'existence d'une image.
///
/// Ce service ne connaît ni Product, ni Shop, ni SQLite : il ne
/// manipule que des chemins de fichiers. Les écrans/formulaires
/// restent responsables de la logique métier (quand copier, quand
/// supprimer l'ancienne image, quand mettre à jour la base).
///
/// IMPORTANT : ce service est exclusivement dédié aux IMAGES et
/// n'utilise jamais `file_picker`. La sélection de fichiers génériques
/// (futurs modèles `.glb`) relève d'un futur service séparé
/// (`Model3dStorageService`), qui lui utilisera `file_picker`.
class ImageStorageService {
  ImageStorageService._();

  static final ImageStorageService instance = ImageStorageService._();

  static const List<String> _allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

  /// Taille maximale acceptée pour une image (8 Mo), volontairement
  /// généreuse pour un prototype tout en évitant les fichiers aberrants.
  static const int _maxSizeBytes = 8 * 1024 * 1024;

  /// Ouvre le sélecteur d'images du système via `image_picker`, puis
  /// copie l'image choisie dans le dossier privé correspondant à
  /// [ownerType].
  ///
  /// Retourne le chemin local final, ou `null` si l'utilisateur a
  /// annulé la sélection. Lève une [ImageStorageException] en cas de
  /// fichier invalide ou d'erreur de copie.
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

  /// Copie une image déjà présente sur l'appareil (à [sourcePath]) vers
  /// le stockage privé de l'application, sous un nom unique.
  ///
  /// Utile pour réutiliser la logique de copie/validation en dehors du
  /// sélecteur système si besoin (ex: import programmatique).
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

    final targetDir = await _ensureUploadsDir(ownerType);
    final fileName = _generateFileName(ownerType, extension);
    final destinationPath = p.join(targetDir.path, fileName);

    try {
      await sourceFile.copy(destinationPath);
    } catch (e) {
      throw ImageStorageException('Erreur lors de la copie de l\'image : $e');
    }

    return destinationPath;
  }

  /// Supprime une image du stockage privé, de façon "best effort".
  ///
  /// - Ne fait rien si [imagePath] est nul ou vide.
  /// - Ne fait rien si le chemin correspond à un asset embarqué
  ///   (`assets/...`) : ces fichiers ne sont jamais gérés par ce
  ///   service et ne doivent jamais être supprimés.
  /// - Si le fichier n'existe déjà plus, ce n'est PAS considéré comme
  ///   une erreur.
  /// - Toute autre erreur de suppression est avalée silencieusement.
  Future<void> deleteImage(String? imagePath) async {
    if (imagePath == null || imagePath.trim().isEmpty) return;
    if (_isAsset(imagePath)) return;

    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Suppression best-effort : on n'interrompt jamais l'appelant.
    }
  }

  /// Indique si le chemin correspond à un fichier réellement présent.
  /// Les assets sont considérés comme "existants" par convention :
  /// leur disponibilité réelle est vérifiée par [AppImage] via
  /// `errorBuilder`, pas par ce service.
  Future<bool> exists(String? imagePath) async {
    if (imagePath == null || imagePath.trim().isEmpty) return false;
    if (_isAsset(imagePath)) return true;
    return File(imagePath).exists();
  }

  bool _isAsset(String imagePath) => imagePath.startsWith('assets/');

  Future<Directory> _ensureUploadsDir(ImageOwnerType ownerType) async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(documentsDir.path, 'uploads', _folderName(ownerType)));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _folderName(ImageOwnerType ownerType) {
    switch (ownerType) {
      case ImageOwnerType.shop:
        return 'shops';
      case ImageOwnerType.product:
        return 'products';
      case ImageOwnerType.user:
        return 'users';
    }
  }

  String _filePrefix(ImageOwnerType ownerType) {
    switch (ownerType) {
      case ImageOwnerType.shop:
        return 'shop';
      case ImageOwnerType.product:
        return 'product';
      case ImageOwnerType.user:
        return 'user';
    }
  }

  /// Génère un nom de fichier unique, jamais dérivé du nom original
  /// fourni par l'utilisateur (sécurité + évite les collisions).
  String _generateFileName(ImageOwnerType ownerType, String extension) {
    final prefix = _filePrefix(ownerType);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '${prefix}_${timestamp}_$random.$extension';
  }
}