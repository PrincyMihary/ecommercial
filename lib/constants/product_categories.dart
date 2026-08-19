/// Catégories de PRODUITS (liste fermée, choisie par le vendeur dans
/// le formulaire produit). Valeurs stockées telles quelles dans
/// `products.category` (colonne TEXT) — ne pas renommer une valeur
/// une fois des produits enregistrés avec elle sans migration.
///
/// Liste centralisée : `ProductFormScreen` (sélection) et
/// `SearchScreen` (filtre) doivent tous deux importer cette liste
/// plutôt que d'en redéfinir une localement, pour que le filtre ne
/// puisse jamais proposer une valeur que le formulaire n'écrirait
/// pas (et inversement).
///
/// NOTE : distincte de `kShopCategories` (catégories de commerce) —
/// ce sont deux domaines différents (type de commerce vs type de
/// produit vendu), donc deux listes séparées volontairement.
const List<String> kProductCategories = [
  'Mobilier — Assise & Repos',
  'Mobilier — Rangement & Organisation',
  'Mobilier — Surfaces & Repas',
  'Mobilier — Sommeil & Confort',
  'Luminaires & Éclairage',
  "Textiles & Tissus d'ameublement",
  'Décoration murale',
  'Objets déco & Art de la table',
  'Artisanat & Fabrication maison',
  'Accessoires multifonctions',
  'Jardin & Extérieur',
  'Électronique domestique & Smart Home',
  'Vêtements',
];