/**
 * Transposition exacte de lib/models/order_status.dart.
 */
export const OrderStatus = {
  pending: 'pending',
  paid: 'paid',
  preparing: 'preparing',
  ready: 'ready',
  completed: 'completed',
  cancelled: 'cancelled',
  refunded: 'refunded',
} as const;

export type OrderStatusValue = (typeof OrderStatus)[keyof typeof OrderStatus];

export const TERMINAL_STATUSES: OrderStatusValue[] = [
  OrderStatus.completed,
  OrderStatus.cancelled,
  OrderStatus.refunded,
];

/**
 * Transitions qu'un COMMERÇANT peut déclencher manuellement.
 * `pending -> paid` n'apparaît volontairement PAS ici : côté SQLite
 * cette transition était automatique (markOrderAsPaid). Côté backend,
 * elle est fusionnée dans POST /orders/checkout (voir §12/§13 du plan)
 * plutôt que de rester une transition manuelle séparée.
 */
export const MERCHANT_TRANSITIONS: Record<string, OrderStatusValue[]> = {
  [OrderStatus.paid]: [OrderStatus.preparing, OrderStatus.refunded],
  [OrderStatus.preparing]: [OrderStatus.ready, OrderStatus.refunded],
  [OrderStatus.ready]: [OrderStatus.completed, OrderStatus.refunded],
};

export function canTransition(from: string, to: string): boolean {
  return MERCHANT_TRANSITIONS[from]?.includes(to as OrderStatusValue) ?? false;
}

export function availableTransitions(status: string): OrderStatusValue[] {
  return MERCHANT_TRANSITIONS[status] ?? [];
}

export function isTerminal(status: string): boolean {
  return TERMINAL_STATUSES.includes(status as OrderStatusValue);
}

export function label(status: string): string {
  switch (status) {
    case OrderStatus.pending:
      return 'En attente';
    case OrderStatus.paid:
      return 'Payée';
    case OrderStatus.preparing:
      return 'En préparation';
    case OrderStatus.ready:
      return 'Prête';
    case OrderStatus.completed:
      return 'Terminée';
    case OrderStatus.cancelled:
      return 'Annulée';
    case OrderStatus.refunded:
      return 'Remboursée';
    default:
      return status;
  }
}
