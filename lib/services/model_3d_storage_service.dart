import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Erreur métier levée par [Model3dStorageService], avec un message déjà
/// adapté à un affichage utilisateur (SnackBar, dialogue...).
class Model3dStorageException implements Exception {
  final String message;

  const Model3dStorageException(this.message);

  @override
  String toString() => message;
}

/// Service central de gestion des modèles 3D `.glb` locaux.
///
/// Miroir de [ImageStorageService], mais pour les modèles 3D :
/// - ouvre le sélecteur de FICHIERS du système via `file_picker`
///   (jamais `image_picker`) ;
/// - copie le fichier `.glb` choisi dans le stockage privé de l'app,
///   sous un nom de fichier unique généré ;
/// - supprime un modèle du stockage privé ;
/// - vérifie l'existence d'un modèle.
///
/// Ce service ne connaît ni Product, ni SQLite : il ne manipule que
/// des chemins de fichiers. C'est à [ProductFormScreen] de décider
/// quand appeler quoi (même répartition des responsabilités que pour
/// les images).
class Model3dStorageService {
  Model3dStorageService._();

  static final Model3dStorageService instance = Model3dStorageService._();

  static const List<String> _allowedExtensions = ['glb'];

  /// Taille maximale acceptée pour un modèle 3D (50 Mo). Les fichiers
  /// `.glb` sont généralement plus volumineux que des images ; cette
  /// limite reste généreuse pour un prototype tout en évitant les
  /// fichiers aberrants.
  static const int _maxSizeBytes = 50 * 1024 * 1024;

  /// Ouvre le sélecteur de fichiers du système via `file_picker`,
  /// restreint aux `.glb`, puis copie le fichier choisi dans le
  /// dossier privé `uploads/models/`.
  ///
  /// Retourne le chemin local final, ou `null` si l'utilisateur a
  /// annulé la sélection. Lève une [Model3dStorageException] en cas
  /// de fichier invalide ou d'erreur de copie.
  Future<String?> pickAndStoreModel() async {
    FilePickerResult? result;

    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
        allowMultiple: false,
      );
    } catch (e) {
      throw const Model3dStorageException(
        "Impossible d'ouvrir le sélecteur de fichiers.",
      );
    }

    if (result == null || result.files.isEmpty) {
      // Sélection annulée par l'utilisateur : pas une erreur.
      return null;
    }

    final pickedPath = result.files.single.path;
    if (pickedPath == null) {
      // Peut arriver avec certains fournisseurs de fichiers virtuels
      // (ex: Google Drive) qui ne donnent pas de chemin réel.
      throw const Model3dStorageException(
        "Ce fichier n'est pas accessible directement. "
            "Choisissez un fichier stocké sur l'appareil.",
      );
    }

    return storeModelFromPath(sourcePath: pickedPath);
  }

  /// Copie un fichier `.glb` déjà présent sur l'appareil (à
  /// [sourcePath]) vers le stockage privé de l'application, sous un
  /// nom unique.
  Future<String> storeModelFromPath({required String sourcePath}) async {
    final sourceFile = File(sourcePath);

    if (!await sourceFile.exists()) {
      throw const Model3dStorageException('Le fichier sélectionné est introuvable.');
    }

    final extension = p.extension(sourcePath).replaceFirst('.', '').toLowerCase();
    if (!_allowedExtensions.contains(extension)) {
      throw Model3dStorageException(
        'Format non supporté (.$extension). Seul le format .glb est accepté.',
      );
    }

    final int sizeBytes;
    try {
      sizeBytes = await sourceFile.length();
    } catch (e) {
      throw const Model3dStorageException('Impossible de lire le fichier sélectionné.');
    }

    if (sizeBytes > _maxSizeBytes) {
      throw const Model3dStorageException('Modèle 3D trop volumineux (maximum 50 Mo).');
    }

    final targetDir = await _ensureUploadsDir();
    final fileName = _generateFileName(extension);
    final destinationPath = p.join(targetDir.path, fileName);

    try {
      await sourceFile.copy(destinationPath);
    } catch (e) {
      throw Model3dStorageException('Erreur lors de la copie du modèle 3D : $e');
    }

    return destinationPath;
  }

  /// Supprime un modèle 3D du stockage privé, de façon "best effort".
  ///
  /// - Ne fait rien si [modelPath] est nul ou vide.
  /// - Ne fait rien si le chemin correspond à un asset embarqué
  ///   (`assets/...`).
  /// - Un fichier déjà absent n'est PAS considéré comme une erreur.
  /// - Toute autre erreur de suppression est avalée silencieusement.
  Future<void> deleteModel(String? modelPath) async {
    if (modelPath == null || modelPath.trim().isEmpty) return;
    if (_isAsset(modelPath)) return;

    try {
      final file = File(modelPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Suppression best-effort : on n'interrompt jamais l'appelant.
    }
  }

  /// Indique si le chemin correspond à un fichier réellement présent.
  /// Les assets sont considérés comme "existants" par convention.
  Future<bool> exists(String? modelPath) async {
    if (modelPath == null || modelPath.trim().isEmpty) return false;
    if (_isAsset(modelPath)) return true;
    return File(modelPath).exists();
  }

  bool _isAsset(String modelPath) => modelPath.startsWith('assets/');

  Future<Directory> _ensureUploadsDir() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(documentsDir.path, 'uploads', 'models'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Génère un nom de fichier unique, jamais dérivé du nom original
  /// fourni par l'utilisateur.
  String _generateFileName(String extension) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return 'model_${timestamp}_$random.$extension';
  }
}