import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import 'api_client.dart';

/// Erreur métier levée par [Model3dStorageService], avec un message déjà
/// adapté à un affichage utilisateur (SnackBar, dialogue...).
class Model3dStorageException implements Exception {
  final String message;

  const Model3dStorageException(this.message);

  @override
  String toString() => message;
}

/// Service central de gestion des modèles 3D `.glb`.
///
/// Miroir de [ImageStorageService], mais pour les modèles 3D. Depuis
/// la migration vers le backend, ce service n'est PLUS un stockage
/// local permanent : il se contente de
/// - ouvrir le sélecteur de FICHIERS du système via `file_picker`
///   (jamais `image_picker`), restreint aux `.glb` ;
/// - envoyer le fichier temporairement sélectionné au backend via
///   `POST /uploads/model` (multipart, champ `file`) ;
/// - retourner la référence distante (`path`) renvoyée par le serveur ;
/// - supprimer une référence distante via `DELETE /uploads`.
///
/// Le fichier sélectionné par `file_picker` ne sert que de source au
/// multipart : il n'est jamais copié dans
/// `ApplicationDocumentsDirectory`. Le backend génère lui-même le nom
/// de fichier final.
class Model3dStorageService {
  Model3dStorageService._();

  static final Model3dStorageService instance = Model3dStorageService._();

  static const List<String> _allowedExtensions = ['glb'];

  /// Taille maximale acceptée pour un modèle 3D (50 Mo), vérifiée
  /// côté Flutter avant l'envoi, en plus de toute limite backend.
  static const int _maxSizeBytes = 50 * 1024 * 1024;

  /// Ouvre le sélecteur de fichiers du système via `file_picker`,
  /// restreint aux `.glb`, puis envoie le fichier choisi au backend.
  ///
  /// Retourne la référence distante (`path`, ex :
  /// `/files/models/model_....glb`), ou `null` si l'utilisateur a
  /// annulé la sélection. Lève une [Model3dStorageException] en cas
  /// de fichier invalide ou d'erreur d'envoi.
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

  /// Valide puis envoie un fichier `.glb` déjà présent sur l'appareil
  /// (à [sourcePath]) au backend, et retourne la référence distante
  /// (`path`) renvoyée par le serveur.
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

    try {
      final response = await ApiClient.instance.postMultipart(
        '/uploads/model',
        filePath: sourcePath,
      ) as Map<String, dynamic>;

      final path = response['path'] as String?;
      if (path == null || path.isEmpty) {
        throw const Model3dStorageException(
          "Réponse du serveur invalide lors de l'envoi du modèle 3D.",
        );
      }
      return path;
    } on ApiException catch (e) {
      throw Model3dStorageException(
        "Erreur lors de l'envoi du modèle 3D : ${e.message}",
      );
    }
  }

  /// Supprime une référence de modèle 3D distante, de façon
  /// "best effort".
  ///
  /// - Ne fait rien si [modelPath] est nul ou vide.
  /// - Ne fait rien si le chemin correspond à un asset embarqué
  ///   (`assets/...`).
  /// - Ne fait rien si la référence n'est pas une référence distante
  ///   connue (`/files/...`) : ce service ne supprime plus jamais de
  ///   fichier local.
  /// - Toute erreur est avalée silencieusement (suppression backend
  ///   elle-même "best effort", réponse 204).
  Future<void> deleteModel(String? modelPath) async {
    if (modelPath == null || modelPath.trim().isEmpty) return;
    if (_isAsset(modelPath)) return;
    if (!_isRemoteReference(modelPath)) return;

    try {
      await ApiClient.instance.delete('/uploads', body: {'path': modelPath});
    } catch (_) {
      // Suppression best-effort : on n'interrompt jamais l'appelant.
    }
  }

  /// Indique si la référence est exploitable telle quelle (asset ou
  /// référence distante).
  Future<bool> exists(String? modelPath) async {
    if (modelPath == null || modelPath.trim().isEmpty) return false;
    return _isAsset(modelPath) || _isRemoteReference(modelPath);
  }

  bool _isAsset(String modelPath) => modelPath.startsWith('assets/');

  bool _isRemoteReference(String modelPath) => modelPath.startsWith('/files/');
}