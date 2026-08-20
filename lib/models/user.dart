/// Représente un utilisateur de l'application.
///
/// Volontairement dépourvu de toute information de mot de passe
/// (hash, sel) : ces champs restent internes à
/// `DatabaseHelper`/`AuthService` et ne doivent jamais circuler dans
/// l'UI ni être exposés via ce modèle.
///
/// Pensé pour permettre plus tard, sans le modifier :
/// - `shops.owner_id` référençant `users.id` (1 utilisateur -> 0 ou 1
///   commerce) ;
/// - un lien equivalent pour la propriété des produits (via le
///   commerce) ;
/// - un lien `orders.user_id` pour l'historique des commandes.
class User {
  final int id;
  final String fullName;
  final String email;
  final String? phone;
  final String createdAt;

  const User({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.createdAt,
  });

  /// Construit un [User] à partir d'une ligne SQLite. Ignore
  /// silencieusement `password_hash` / `password_salt` si présents
  /// dans la map (ils ne sont jamais utilisés ici).
  ///
  /// Conservé pour compatibilité (plus utilisé par [AuthService] depuis
  /// la migration REST, voir [User.fromApiJson]), au cas où un autre
  /// appelant lirait encore une ligne `users` SQLite brute.
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int,
      fullName: map['full_name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String?,
      createdAt: map['created_at'] as String? ?? '',
    );
  }

  /// Construit un [User] à partir du JSON renvoyé par le backend REST
  /// (`{token, user: {...}}` sur /auth/register et /auth/login, ou le
  /// corps direct de GET /users/me) — voir migration_plan.md §6-8.
  ///
  /// Contrairement à [User.fromMap] (colonnes SQLite en snake_case),
  /// le contrat REST utilise des clés camelCase (`fullName`,
  /// `createdAt`). `id` est un `number` JSON déjà sûr (voir
  /// `toSafeApiId` côté backend) : aucune conversion supplémentaire
  /// n'est nécessaire ni souhaitable ici.
  factory User.fromApiJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}