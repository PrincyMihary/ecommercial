import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';
import 'product_detail_screen.dart';

/// Écran d'accueil.
///
/// Affiche les produits depuis SQLite, filtrés par la recherche texte
/// et/ou la catégorie sélectionnée (voir [DatabaseHelper.searchProducts]).
/// Chaque carte ouvre [ProductDetailScreen] ; la liste se rafraîchit
/// automatiquement au retour si une modification a eu lieu.
///
/// IMPORTANT (focus clavier) : la barre de recherche (et plus largement
/// le header + les catégories) est rendue EN DEHORS du [FutureBuilder]
/// qui charge les produits. Si elle était à l'intérieur, chaque
/// changement de [_productsFuture] ferait brièvement repasser le
/// FutureBuilder par `ConnectionState.waiting`, ce qui démonterait tout
/// le sous-arbre (y compris le TextField) et ferait perdre le focus
/// clavier à chaque frappe. Seule la zone des résultats est reconstruite
/// pendant le chargement ; la barre de recherche, elle, ne bouge jamais.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Product>> _productsFuture;

  /// Créés une seule fois pour toute la durée de vie de l'écran.
  /// Ne jamais les recréer dans build() ni dans _onSearchChanged().
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String _selectedCategory = 'Tout';

  static const List<String> _categories = [
    'Tout',
    'Mobilier',
    'Décoration',
    'Électronique',
    'Mode',
    'Artisanat',
  ];

  bool get _isFiltering =>
      _searchController.text.trim().isNotEmpty || _selectedCategory != 'Tout';

  @override
  void initState() {
    super.initState();
    _productsFuture = _search();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Interroge SQLite avec le texte de recherche courant et la
  /// catégorie sélectionnée. Le filtrage a lieu entièrement côté base
  /// (voir [DatabaseHelper.searchProducts]), jamais en mémoire ici.
  Future<List<Product>> _search() async {
    final rows = await DatabaseHelper.instance.searchProducts(
      query: _searchController.text,
      category: _selectedCategory,
    );
    return rows.map((row) => Product.fromMap(row)).toList();
  }

  /// Ne touche ni au controller ni au focusNode : seule la Future de
  /// résultats change, ce qui ne reconstruit que la zone de résultats
  /// (voir la structure du widget dans build()).
  void _onSearchChanged(String value) {
    setState(() {
      _productsFuture = _search();
    });
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
      _productsFuture = _search();
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _productsFuture = _search();
    });
    await _productsFuture;
  }

  Future<void> _openProduct(Product product) async {
    if (product.id == null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: product.id!)),
    );
    if (changed == true) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // Le header, la barre de recherche et les catégories sont fixes :
        // ils ne dépendent pas de _productsFuture et ne sont donc jamais
        // démontés pendant le chargement des résultats. C'est ce qui
        // garantit que le TextField (et son focus) reste stable pendant
        // toute la saisie.
        child: Column(
          children: [
            const SizedBox(height: 8),
            _buildHeader(context),
            const SizedBox(height: 16),
            _buildSearchBar(),
            const SizedBox(height: 20),
            _buildCategories(),
            const SizedBox(height: 20),
            Expanded(child: _buildResultsArea()),
          ],
        ),
      ),
    );
  }

  /// Seule cette zone dépend de [_productsFuture]. Le FutureBuilder ne
  /// peut donc démonter/reconstruire que la grille de produits (ou
  /// l'indicateur de chargement/l'état vide/l'erreur), jamais la barre
  /// de recherche.
  Widget _buildResultsArea() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Product>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              // AlwaysScrollableScrollPhysics permet au pull-to-refresh
              // de fonctionner même quand le contenu est un simple
              // indicateur centré.
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(child: CircularProgressIndicator()),
              ],
            );
          }

          if (snapshot.hasError) {
            return _buildError(snapshot.error.toString());
          }

          final products = snapshot.data ?? [];

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _buildSectionTitle(
                _isFiltering ? 'Résultats' : 'Recommandé pour toi',
              ),
              const SizedBox(height: 12),
              if (products.isEmpty)
                _buildEmptyState()
              else
                _buildProductGrid(products),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Accueil',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: AppColors.textPrimary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.textSecondary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Rechercher un produit, un commerce...',
                  isDense: true,
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              )
            else
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.tune, color: Colors.white, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _onCategorySelected(category),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accent : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                category,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Icon(Icons.arrow_forward, size: 18, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _buildProductGrid(List<Product> products) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductCard(
          product: product,
          onTap: () => _openProduct(product),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Center(
        child: Text(
          _isFiltering
              ? 'Aucun résultat pour cette recherche.'
              : 'Aucun produit trouvé dans la base locale.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.settings_outlined, size: 40, color: AppColors.danger),
                const SizedBox(height: 12),
                Text(
                  'Erreur lors du chargement des produits :\n$message',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}