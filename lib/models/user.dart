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
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int,
      fullName: map['full_name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String?,
      createdAt: map['created_at'] as String? ?? '',
    );
  }
}