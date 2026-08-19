import 'dart:async';
import 'package:flutter/material.dart';

import '../services/places_service.dart';
import '../theme/app_theme.dart';

/// Interface de recherche de lieu Google Places.
///
/// Retourne un [PlaceSelection] via `Navigator.pop` si l'utilisateur
/// choisit un résultat, ou `null` s'il annule.
class PlaceSearchScreen extends StatefulWidget {
  const PlaceSearchScreen({super.key});

  @override
  State<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends State<PlaceSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = [];
  bool _isSearching = false;
  bool _isResolving = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search(String value) async {
    setState(() {
      _isSearching = true;
      _error = null;
    });
    try {
      final results = await PlacesService.instance.autocomplete(value);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isSearching = false;
      });
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    setState(() => _isResolving = true);
    try {
      final selection = await PlacesService.instance.getPlaceDetails(suggestion.placeId);
      if (!mounted) return;
      Navigator.pop(context, selection);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResolving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sélection du lieu : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choisir l\'emplacement')),
      body: AbsorbPointer(
        absorbing: _isResolving,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: 'Rechercher un commerce, bâtiment ou lieu...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _controller.clear();
                      _onChanged('');
                    },
                  )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            if (PlacesService.instance.isMockMode)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Mode démo : résultats simulés (aucune clé Google Places configurée).',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            if (_isSearching || _isResolving) const LinearProgressIndicator(minHeight: 2),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ),
            Expanded(
              child: ListView.separated(
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final s = _suggestions[index];
                  return ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(s.primaryText),
                    subtitle: s.secondaryText.isNotEmpty ? Text(s.secondaryText) : null,
                    onTap: _isResolving ? null : () => _selectSuggestion(s),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}