import 'package:flutter/material.dart';

import '../models/product.dart';
import '../repositories/product_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';
import 'product_detail_screen.dart';
import '../constants/product_categories.dart';

/// Écran de recherche dédié (onglet "Recherche").
///
/// Migration REST : réutilise [ProductRepository.search]
/// (`GET /products/search?q=&category=`), la même méthode que
/// [HomeScreen], pour éviter toute duplication de logique de filtre.
/// Le filtrage a lieu entièrement côté backend, jamais en mémoire
/// ici — même principe que `HomeScreen._search`. L'état de recherche
/// (texte + catégorie) reste indépendant de celui de la Home : chaque
/// écran garde son propre filtre.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ProductRepository _productRepository = ProductRepository();

  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'Tout';
  late Future<List<Product>> _resultsFuture;

  static const List<String> _categories = ['Tout', ...kProductCategories];

  bool get _isFiltering =>
      _searchController.text.trim().isNotEmpty || _selectedCategory != 'Tout';

  @override
  void initState() {
    super.initState();
    _resultsFuture = _search();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Product>> _search() {
    return _productRepository.search(
      query: _searchController.text,
      category: _selectedCategory,
    );
  }

  void _onSearchChanged(String value) {
    setState(() {
      _resultsFuture = _search();
    });
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
      _resultsFuture = _search();
    });
  }

  Future<void> _openProduct(Product product) async {
    if (product.id == null) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: product.id!)),
    );
    // Toujours réinterroger au retour : couvre le cas où le produit a
    // été modifié ou supprimé depuis l'écran détail.
    if (!mounted) return;
    setState(() {
      _resultsFuture = _search();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recherche')),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            const SizedBox(height: 16),
            _buildCategories(),
            const SizedBox(height: 16),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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
                autofocus: false,
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

  Widget _buildResults() {
    return FutureBuilder<List<Product>>(
      future: _resultsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }

        final results = snapshot.data ?? [];

        if (results.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: Center(
              child: Text(
                _isFiltering
                    ? 'Aucun résultat pour cette recherche.'
                    : 'Aucun produit disponible.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          itemCount: results.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (context, index) {
            final product = results[index];
            return ProductCard(
              product: product,
              onTap: () => _openProduct(product),
            );
          },
        );
      },
    );
  }
}