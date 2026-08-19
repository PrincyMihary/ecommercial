/// Statuts possibles d'une commande, dans l'ordre de progression
/// "normal" (hors annulation/remboursement).
///
/// Valeurs stockées telles quelles en base (colonne `orders.status`).
class OrderStatus {
  static const String pending = 'pending';
  static const String paid = 'paid';
  static const String preparing = 'preparing';
  static const String ready = 'ready';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';

  /// Étape 4 : statut terminal distinct de `cancelled`, atteint via un
  /// remboursement (mocké) déclenché par le commerçant.
  static const String refunded = 'refunded';

  /// Ordre de progression "normale", utilisée pour la timeline
  /// visuelle. `cancelled`/`refunded` sont volontairement hors de
  /// cette liste : ce sont des états terminaux distincts, pas des
  /// étapes de la progression.
  static const List<String> progression = [
    pending,
    paid,
    preparing,
    ready,
    completed,
  ];

  /// États terminaux : une fois atteints, une commande n'évolue plus
  /// (voir [merchantTransitions]) ET ne bloque plus la suppression
  /// d'un produit/commerce qui y apparaît (voir
  /// `DatabaseHelper.getBlockingOrdersForProduct` /
  /// `getBlockingOrdersForShop`).
  static const List<String> terminalStatuses = [completed, cancelled, refunded];

  /// Transitions qu'un COMMERÇANT peut déclencher manuellement,
  /// contrôlées ici plutôt que dans l'UI (voir
  /// `DatabaseHelper.advanceOrderStatusForShop`).
  ///
  /// `pending -> paid` n'apparaît PAS ici : cette transition reste
  /// automatique, déclenchée par le flux de paiement
  /// (`markOrderAsPaid`), jamais par une action commerçant manuelle.
  static const Map<String, List<String>> merchantTransitions = {
    paid: [preparing, refunded],
    preparing: [ready, refunded],
    ready: [completed, refunded],
  };

  /// `true` si la transition [from] -> [to] est autorisée pour un
  /// commerçant. Ex : `preparing -> ready` : autorisé ;
  /// `completed -> pending` ou `refunded -> delivered` : refusés.
  static bool canTransition(String from, String to) =>
      merchantTransitions[from]?.contains(to) ?? false;

  /// Transitions disponibles depuis [status], pour construire les
  /// boutons d'action côté UI (jamais générées "en dur" dans l'UI).
  static List<String> availableTransitions(String status) =>
      merchantTransitions[status] ?? const [];

  static bool isTerminal(String status) => terminalStatuses.contains(status);

  static bool isCancelled(String status) => status == cancelled;

  static bool isRefunded(String status) => status == refunded;

  static String label(String status) {
    switch (status) {
      case pending:
        return 'En attente';
      case paid:
        return 'Payée';
      case preparing:
        return 'En préparation';
      case ready:
        return 'Prête';
      case completed:
        return 'Terminée';
      case cancelled:
        return 'Annulée';
      case refunded:
        return 'Remboursée';
      default:
        return status;
    }
  }
}