# Ecommercial

Application mobile de marketplace développée avec Flutter.

Ecommercial est une application de commerce multi-vendeurs permettant aux utilisateurs de consulter des commerces et leurs produits, rechercher des articles, gérer un panier, passer des commandes, effectuer des paiements de démonstration et visualiser certains produits en réalité augmentée.

Le projet est actuellement développé autour d'un fonctionnement local afin de disposer d'une première version autonome et fonctionnelle. Une migration progressive vers une architecture distribuée avec une API REST Node.js, Express et TypeScript est prévue.

---

## Sommaire

* [Présentation](#présentation)
* [Objectifs](#objectifs)
* [Fonctionnalités](#fonctionnalités)
* [Architecture actuelle](#architecture-actuelle)
* [Architecture cible](#architecture-cible)
* [Technologies](#technologies)
* [Structure du projet](#structure-du-projet)
* [Modèles de données](#modèles-de-données)
* [Authentification](#authentification)
* [Gestion des commerces](#gestion-des-commerces)
* [Gestion des produits](#gestion-des-produits)
* [Recherche](#recherche)
* [Panier et commandes](#panier-et-commandes)
* [Paiements](#paiements)
* [Réalité augmentée](#réalité-augmentée)
* [Géolocalisation](#géolocalisation)
* [Stockage local](#stockage-local)
* [Migration vers l'API REST](#migration-vers-lapi-rest)
* [Installation](#installation)
* [Configuration](#configuration)
* [Lancer l'application](#lancer-lapplication)
* [Développement](#développement)
* [Organisation du travail](#organisation-du-travail)
* [État du projet](#état-du-projet)
* [Feuille de route](#feuille-de-route)

---

# Présentation

Ecommercial est une application mobile de marketplace développée avec Flutter et Dart.

L'application permet de réunir plusieurs commerces et leurs produits au sein d'une même interface.

Un utilisateur peut notamment :

* parcourir les produits disponibles ;
* consulter les commerces ;
* rechercher un produit ;
* filtrer les produits par catégorie ;
* consulter les détails d'un produit ;
* consulter les détails d'un commerce ;
* ajouter des produits à son panier ;
* modifier les quantités ;
* passer une commande ;
* consulter ses commandes ;
* utiliser différents moyens de paiement de démonstration ;
* créer et gérer des commerces selon ses droits ;
* créer et gérer des produits selon ses droits ;
* sélectionner des images depuis son appareil ;
* associer un modèle 3D à un produit ;
* visualiser certains produits en réalité augmentée ;
* associer un commerce à une localisation géographique.

Le projet est conçu pour évoluer progressivement d'une application locale vers une véritable architecture client-serveur.

---

# Objectifs

Le projet poursuit plusieurs objectifs.

## Objectif fonctionnel

Construire une marketplace mobile complète permettant à plusieurs utilisateurs de publier des commerces et des produits et à d'autres utilisateurs de les consulter et de les acheter.

## Objectif technique

Construire progressivement une architecture capable de passer de :

```text
Flutter
   |
   v
SQLite local
```

à :

```text
Flutter
   |
   v
Services / Repository
   |
   v
API REST
   |
   v
Node.js + Express + TypeScript
   |
   v
Base de données serveur
```

Cette migration doit être progressive.

L'interface utilisateur ne doit pas dépendre directement de la technologie utilisée pour stocker les données.

---

# Fonctionnalités

## Marketplace

* Accueil
* Recherche
* Filtres par catégorie
* Liste des commerces
* Détails d'un commerce
* Liste des produits
* Détails d'un produit
* Produits associés à un commerce
* Gestion du stock
* Panier
* Commandes
* Historique des commandes
* Paiements de démonstration

## Vendeurs

* Création d'un commerce
* Modification d'un commerce
* Suppression d'un commerce
* Création d'un produit
* Modification d'un produit
* Suppression d'un produit
* Association d'un produit à un commerce
* Gestion des images
* Association d'un modèle 3D

## Utilisateurs

* Inscription
* Connexion
* Déconnexion
* Profil
* Identité persistante
* Association des commerces à leur propriétaire
* Association des produits à leur propriétaire

## Localisation

Les commerces peuvent être associés à une localisation géographique.

L'objectif est de conserver :

* une adresse lisible pour l'utilisateur ;
* des coordonnées géographiques ;
* une référence permettant d'ouvrir la localisation dans Google Maps.

La localisation est donc traitée comme une donnée structurée plutôt qu'une simple chaîne de caractères.

## Réalité augmentée

Les produits disposant d'un modèle `.glb` peuvent être visualisés en réalité augmentée.

L'objectif de cette fonctionnalité est de permettre à l'utilisateur de :

1. ouvrir la fiche d'un produit ;
2. lancer la vue AR ;
3. regarder son environnement réel ;
4. détecter une surface compatible ;
5. placer le modèle 3D ;
6. déplacer le modèle ;
7. le faire tourner ;
8. modifier sa taille.

La fonctionnalité AR est basée sur l'affichage de modèles glTF/GLB et sur les capacités AR disponibles sur Android.

---

# Architecture actuelle

La version actuelle est autonome et fonctionne localement.

```text
┌──────────────────────────────┐
│           Flutter            │
│                              │
│  Screens                     │
│  Widgets                     │
│  Services                    │
│  Models                      │
└──────────────┬───────────────┘
               │
               v
┌──────────────────────────────┐
│       DatabaseHelper         │
│                              │
│          SQLite              │
└──────────────────────────────┘
```

Les données principales sont actuellement stockées dans SQLite.

Les fichiers utilisateur tels que les images et les modèles 3D sont également gérés localement.

Cette architecture permet de développer et tester l'application sans serveur.

---

# Architecture cible

L'architecture finale doit séparer clairement l'interface utilisateur de la source de données.

```text
┌──────────────────────────────┐
│          Flutter             │
│                              │
│ Screens / Widgets            │
└──────────────┬───────────────┘
               │
               v
┌──────────────────────────────┐
│     Services / Repository    │
└──────────────┬───────────────┘
               │
               │ HTTP / JSON
               v
┌──────────────────────────────┐
│          REST API            │
│                              │
│ Node.js                     │
│ Express                     │
│ TypeScript                  │
└──────────────┬───────────────┘
               │
       ┌───────┴────────┐
       v                v
┌──────────────┐ ┌──────────────┐
│ Base serveur │ │ Stockage     │
│              │ │ fichiers     │
└──────────────┘ └──────────────┘
```

Le serveur sera dans un projet séparé du code Flutter.

L'application Flutter communiquera avec l'API via HTTP.

---

# Technologies

## Application mobile

* Flutter
* Dart
* Material Design
* SQLite
* `sqflite`
* `path_provider`
* `image_picker`
* `file_picker`
* `model_viewer_plus`

## Backend prévu

* Node.js
* Express
* TypeScript
* API REST
* Base de données serveur
* Authentification et autorisation côté serveur

## Développement

* Android Studio
* Flutter SDK
* Dart SDK
* Git
* GitHub

---

# Structure du projet

Structure actuelle de `lib/` :

```text
lib/
│
├── app.dart
├── main.dart
│
├── constants/
│   ├── product_categories.dart
│   └── shop_categories.dart
│
├── database/
│   ├── database_helper.dart
│   └── seed_data.dart
│
├── models/
│   ├── cart_item.dart
│   ├── order.dart
│   ├── order_item.dart
│   ├── order_status.dart
│   ├── product.dart
│   ├── shop.dart
│   └── user.dart
│
├── screens/
│   ├── ar_plugin_compile_check.dart
│   ├── ar_view_screen.dart
│   ├── blocking_order_screen.dart
│   ├── cart_screen.dart
│   ├── checkout_screen.dart
│   ├── home_screen.dart
│   ├── login_screen.dart
│   ├── mobile_money_payment_screen.dart
│   ├── order_confirmation_screen.dart
│   ├── order_detail_screen.dart
│   ├── order_list_screen.dart
│   ├── payment_method_screen.dart
│   ├── placeholder_screen.dart
│   ├── place_search_screen.dart
│   ├── product_detail_screen.dart
│   ├── product_form_screen.dart
│   ├── product_list_screen.dart
│   ├── profile_screen.dart
│   ├── search_screen.dart
│   ├── sell_screen.dart
│   ├── shop_detail_screen.dart
│   ├── shop_form_screen.dart
│   ├── shop_list_screen.dart
│   ├── shop_order_list_screen.dart
│   ├── signup_screen.dart
│   └── visa_payment_screen.dart
│
├── services/
│   ├── auth_service.dart
│   ├── cart_service.dart
│   ├── image_storage_service.dart
│   ├── location_service.dart
│   ├── mock_payment_service.dart
│   ├── model_3d_storage_service.dart
│   └── places_service.dart
│
├── theme/
│   └── app_theme.dart
│
├── utils/
│   └── formatters.dart
│
└── widgets/
    ├── app_image.dart
    ├── image_picker_field.dart
    ├── model_picker_field.dart
    └── product_card.dart
```

---

# Modèles de données

Les principaux modèles actuellement présents sont :

## User

Représente l'utilisateur de l'application.

Il est utilisé pour préparer la gestion multi-utilisateur et l'association des ressources à leur propriétaire.

## Shop

Représente un commerce.

Un commerce peut être associé à :

* un utilisateur ;
* un nom ;
* une description ;
* une catégorie ;
* une adresse ;
* une localisation ;
* une image.

## Product

Représente un produit.

Un produit est notamment associé à :

* un commerce ;
* un propriétaire ;
* un nom ;
* une description ;
* un prix ;
* un stock ;
* une catégorie ;
* une image ;
* éventuellement un modèle 3D.

## CartItem

Représente un produit ajouté au panier avec sa quantité.

## Order

Représente une commande.

## OrderItem

Représente une ligne de commande.

## OrderStatus

Centralise les différents états possibles d'une commande.

---

# Authentification

La première version de l'application fonctionne localement.

Une couche d'authentification existe déjà côté Flutter afin de préparer la transition vers une authentification serveur.

La cible est une authentification centralisée.

Les principales opérations prévues sont :

```text
POST /auth/register
POST /auth/login
GET  /users/me
```

L'utilisateur authentifié devra être identifiable côté serveur.

Cette identité sera ensuite utilisée pour contrôler l'accès aux ressources.

---

# Gestion des commerces

Un utilisateur pourra créer son propre commerce.

Les règles métier prévues sont :

```text
Utilisateur
    |
    +---- Commerce A
    |
    +---- Commerce B
```

Un utilisateur pourra :

* créer ses commerces ;
* modifier ses commerces ;
* supprimer ses commerces ;
* consulter les commerces des autres utilisateurs.

Il ne devra pas pouvoir modifier ou supprimer le commerce appartenant à un autre utilisateur.

Un commerce pourra être :

* physique ;
* virtuel.

Un commerce physique pourra posséder une localisation géographique.

---

# Gestion des produits

Un produit appartient à un commerce et possède également un propriétaire.

Un utilisateur pourra :

* créer ses produits ;
* modifier ses produits ;
* supprimer ses produits ;
* consulter les produits des autres utilisateurs ;
* acheter les produits disponibles.

Le contrôle de propriété devra être appliqué côté serveur après migration vers l'API.

La simple dissimulation d'un bouton dans Flutter ne sera pas considérée comme une protection suffisante.

---

# Recherche

La recherche permet actuellement de rechercher des produits selon plusieurs informations.

La recherche peut notamment prendre en compte :

* le nom du produit ;
* la description ;
* la catégorie ;
* le nom du commerce.

Les filtres peuvent être combinés.

Le filtre par catégorie repose sur les catégories définies dans l'application.

Dans l'architecture finale, cette recherche pourra être déplacée progressivement vers l'API.

---

# Panier et commandes

Le panier est actuellement géré localement en mémoire à travers `CartService`.

Il permet notamment :

* d'ajouter un produit ;
* de supprimer un produit ;
* d'augmenter une quantité ;
* de diminuer une quantité ;
* de respecter le stock disponible.

Lors du passage de commande, le stock est mis à jour.

La cible serveur devra garantir que la diminution du stock est effectuée de manière cohérente côté serveur afin d'éviter les incohérences lorsque plusieurs utilisateurs commandent simultanément.

Les commandes seront progressivement déplacées vers l'API REST.

---

# Paiements

L'application possède actuellement des écrans et services permettant de simuler différents moyens de paiement.

Ces mécanismes servent principalement à tester le parcours utilisateur.

Les paiements réels pourront être intégrés ultérieurement.

L'architecture devra permettre de remplacer progressivement les services de démonstration par de véritables services de paiement sans modifier profondément les écrans de l'application.

---

# Réalité augmentée

La réalité augmentée permet de visualiser un modèle 3D associé à un produit.

Les modèles sont actuellement représentés par des fichiers `.glb`.

Le modèle 3D est sélectionné depuis l'appareil lors de la création ou modification d'un produit.

Le stockage local est utilisé dans la version de développement actuelle.

La visualisation AR utilise `model_viewer_plus`.

Le scénario utilisateur recherché est :

```text
Fiche produit
     |
     v
Voir en AR
     |
     v
Caméra
     |
     v
Détection de surface
     |
     v
Placement du modèle GLB
     |
     ├── Déplacement
     ├── Rotation
     └── Redimensionnement
```

À terme, les modèles 3D seront stockés côté serveur ou dans un stockage de fichiers distant.

La base de données conservera alors une référence vers le fichier plutôt que le fichier lui-même.

---

# Géolocalisation

Les commerces peuvent être associés à une localisation.

Le fonctionnement recherché est différent d'une simple saisie d'adresse.

L'utilisateur doit pouvoir rechercher ou sélectionner un lieu existant et obtenir notamment :

* son nom ;
* son adresse ;
* sa latitude ;
* sa longitude ;
* une référence de lieu lorsque disponible.

L'application peut ensuite afficher l'adresse de manière lisible tout en conservant les coordonnées géographiques.

La localisation pourra également servir à ouvrir l'emplacement correspondant dans une application de cartographie.

La présence de `location_service.dart`, `places_service.dart` et `place_search_screen.dart` prépare cette fonctionnalité.

---

# Stockage local

La version actuelle est volontairement autonome.

Les données sont stockées localement avec SQLite.

Les images sont gérées par :

```text
image_storage_service.dart
```

Les modèles 3D sont gérés par :

```text
model_3d_storage_service.dart
```

Les fichiers sélectionnés par l'utilisateur sont donc séparés des données métier stockées dans SQLite.

Cette séparation facilitera la future migration vers un stockage serveur.

---

# Migration vers l'API REST

La migration ne doit pas être réalisée en réécrivant toute l'application.

Le principe est de conserver :

```text
UI
 |
 v
Services / Repository
 |
 v
Source de données
```

Actuellement :

```text
Source de données
        |
        v
     SQLite
```

À terme :

```text
Source de données
        |
        v
    REST API
```

L'objectif est que les écrans ne sachent pas directement si les données viennent de SQLite ou du serveur.

---

# API REST cible

Le backend sera développé avec :

```text
Node.js
Express
TypeScript
```

Les premiers endpoints prévus sont :

## Authentification

```http
POST /auth/register
POST /auth/login
GET  /users/me
```

## Commerces

```http
GET    /shops
POST   /shops
GET    /shops/:id
PUT    /shops/:id
DELETE /shops/:id
```

## Produits

```http
GET    /products
POST   /products
GET    /products/:id
PUT    /products/:id
DELETE /products/:id
```

## Commandes

```http
POST /orders
GET  /orders
GET  /orders/:id
```

Ces endpoints pourront évoluer en fonction des besoins du projet.

---

# Structure backend prévue

Le backend sera séparé du projet Flutter.

Une structure possible sera :

```text
server/
│
├── src/
│   ├── config/
│   ├── controllers/
│   ├── middleware/
│   ├── models/
│   ├── routes/
│   ├── services/
│   ├── repositories/
│   ├── types/
│   └── app.ts
│
├── package.json
├── tsconfig.json
└── README.md
```

La séparation entre routes, contrôleurs, services et accès aux données permettra de conserver une architecture évolutive.

---

# Communication Flutter / API

Pendant le développement local, l'API sera lancée sur la machine de développement.

L'application Flutter devra utiliser l'adresse correspondant à l'environnement de test.

Pour un appareil Android physique, `localhost` désigne le téléphone lui-même et non l'ordinateur exécutant le serveur.

Il faudra donc utiliser l'adresse IP locale de la machine sur le réseau lorsque le téléphone et l'ordinateur sont connectés au même réseau.

Exemple conceptuel :

```text
Ordinateur
192.168.x.x
    |
    | HTTP
    |
    v
Node.js : PORT
    |
    ^
    |
Téléphone Android
```

L'adresse et le port de l'API devront être configurables afin de ne pas devoir modifier les écrans Flutter.

---

# Installation

## Prérequis

Installer :

* Flutter SDK
* Dart SDK
* Android Studio
* Android SDK
* Git
* Node.js pour le futur backend
* npm

Vérifier Flutter :

```bash
flutter doctor
```

Vérifier Node.js :

```bash
node --version
```

Vérifier npm :

```bash
npm --version
```

---

# Installation de l'application Flutter

Cloner le dépôt :

```bash
git clone https://github.com/PrincyMihary/ecommercial.git
cd ecommercial
```

Installer les dépendances :

```bash
flutter pub get
```

Vérifier les appareils disponibles :

```bash
flutter devices
```

Lancer l'application :

```bash
flutter run
```

---

# Configuration Android

Le projet utilise actuellement une configuration Android basée notamment sur :

```text
compileSdk = 36
targetSdk  = 36
Java       = 17
Kotlin     = JVM 17
```

La configuration exacte doit rester synchronisée avec la version Flutter utilisée par le projet.

Les changements liés à Android doivent être effectués avec prudence afin de ne pas casser les plugins Flutter existants, notamment ceux utilisés pour les fichiers, les images, la géolocalisation et la réalité augmentée.

---

# Développement

Avant toute modification importante :

```bash
git status
```

Puis :

```bash
flutter analyze
```

Et lorsque cela est pertinent :

```bash
flutter test
```

Pour vérifier la compilation Android :

```bash
flutter build apk
```

Les modifications doivent rester ciblées.

Un changement fonctionnel ne doit pas entraîner de refactorisation inutile de parties non concernées.

---

# Organisation du travail

Le projet est développé en équipe.

Le dépôt GitHub centralise le travail des différents membres.

Les fonctionnalités doivent être développées de manière suffisamment isolée pour permettre :

* des commits compréhensibles ;
* des branches dédiées ;
* des revues de code ;
* des corrections indépendantes ;
* une intégration progressive.

Une fonctionnalité importante doit idéalement être séparée en plusieurs commits cohérents plutôt qu'en un seul commit massif.

Les messages de commit doivent décrire clairement la modification effectuée.

Exemples :

```text
Add product search filters
Implement cart quantity management
Add user authentication screens
Implement shop ownership checks
Add AR product viewer
Add place search for shop location
Create REST API structure
Migrate product service to REST API
```

---

# État du projet

## Version locale

La première version locale constitue le socle fonctionnel de l'application.

Les éléments suivants sont déjà intégrés ou en cours d'intégration :

* application Flutter ;
* navigation principale ;
* accueil ;
* recherche ;
* filtres ;
* commerces ;
* produits ;
* CRUD commerces ;
* CRUD produits ;
* sélection d'images ;
* stockage local des images ;
* sélection de fichiers `.glb` ;
* stockage local des modèles 3D ;
* panier ;
* gestion des quantités ;
* gestion du stock ;
* passage de commande ;
* écrans de paiement de démonstration ;
* authentification ;
* profil utilisateur ;
* gestion des commandes ;
* réalité augmentée ;
* géolocalisation et recherche de lieux.

Cette version locale sert de base de validation avant la migration complète vers le serveur.

---

# Feuille de route

## Phase 1 — Version locale

Objectif :

Obtenir une application Flutter autonome.

```text
Flutter
   |
   v
SQLite
```

Fonctionnalités :

* marketplace ;
* commerces ;
* produits ;
* recherche ;
* panier ;
* commandes ;
* paiements de démonstration ;
* authentification locale ;
* images ;
* modèles 3D ;
* AR ;
* localisation.

---

## Phase 2 — Identité utilisateur

Objectif :

Faire de l'utilisateur une véritable entité métier.

Principales règles :

```text
Utilisateur
    |
    +---- Commerces possédés
    |
    +---- Produits possédés
    |
    +---- Commandes
```

Un utilisateur pourra gérer uniquement ses propres ressources.

Les ressources publiques resteront accessibles à la consultation et à l'achat.

---

## Phase 3 — API REST

Création du backend :

```text
Node.js
   |
Express
   |
TypeScript
```

Mise en place progressive :

* configuration du serveur ;
* routes ;
* contrôleurs ;
* services ;
* repositories ;
* authentification ;
* autorisation ;
* produits ;
* commerces ;
* commandes ;
* utilisateurs.

---

## Phase 4 — Migration Flutter

Les écrans Flutter seront progressivement découplés de SQLite.

Architecture cible :

```text
Screen
  |
  v
Service / Repository
  |
  v
REST API
```

La migration sera effectuée fonctionnalité par fonctionnalité.

Par exemple :

```text
Products
   |
   v
API Products
```

puis :

```text
Shops
   |
   v
API Shops
```

puis :

```text
Orders
   |
   v
API Orders
```

SQLite pourra être conservé temporairement pendant la transition.

---

## Phase 5 — Architecture distribuée

Architecture finale :

```text
                    ┌──────────────────────┐
                    │       Flutter        │
                    │      Android         │
                    └──────────┬───────────┘
                               │
                            HTTP/JSON
                               │
                               v
                    ┌──────────────────────┐
                    │       REST API       │
                    │ Node.js + Express    │
                    │      TypeScript      │
                    └──────────┬───────────┘
                               │
                 ┌─────────────┴─────────────┐
                 │                           │
                 v                           v
        ┌─────────────────┐        ┌─────────────────┐
        │ Base de données │        │ Stockage fichiers│
        │ serveur         │        │                 │
        │                 │        │ Images / GLB    │
        └─────────────────┘        └─────────────────┘
```

À ce stade, plusieurs utilisateurs pourront utiliser simultanément la même marketplace.

---

# Principes d'architecture

Le projet suit plusieurs principes importants.

## Ne pas coupler l'interface à la base de données

Les écrans Flutter ne doivent pas construire directement leurs propres requêtes SQLite ou HTTP.

Les accès aux données doivent progressivement passer par des services ou repositories.

## Ne pas faire confiance au client

Les contrôles d'autorisation côté Flutter servent à l'expérience utilisateur.

La véritable autorisation devra être effectuée côté serveur après migration.

Par exemple :

```text
Utilisateur A
    |
    X
    |
Modifier le commerce de B
```

doit être refusé par l'API même si un client modifié tente d'appeler directement l'endpoint.

## Préserver le fonctionnement local pendant la transition

La migration vers l'API doit être progressive.

Le travail effectué sur SQLite n'est pas considéré comme perdu.

SQLite constitue la première implémentation de la source de données.

## Garder les fonctionnalités indépendantes

Les modules suivants doivent rester suffisamment découplés :

* authentification ;
* produits ;
* commerces ;
* recherche ;
* panier ;
* commandes ;
* paiements ;
* géolocalisation ;
* fichiers ;
* réalité augmentée.

Cela permettra de remplacer progressivement les implémentations locales par leurs équivalents serveur.

---

# Contribution

Toute contribution au projet doit respecter :

1. la structure existante ;
2. les conventions Dart et Flutter du projet ;
3. la séparation entre interface et logique métier ;
4. la gestion correcte des erreurs ;
5. la gestion des ressources locales ;
6. les règles de propriété des commerces et produits ;
7. la cohérence avec l'architecture cible.

Avant de créer une nouvelle abstraction, il faut vérifier qu'un service, modèle ou composant existant ne répond pas déjà au besoin.

---

# Licence

Le projet est actuellement développé dans le cadre du projet d'équipe Ecommercial.

Les modalités de distribution et de licence seront définies ultérieurement.

---

# Équipe

Ecommercial est développé comme un projet collaboratif par une équipe de quatre développeurs.

Le dépôt GitHub sert de point central pour le suivi du code source, des branches, des commits et de l'évolution du projet.

---

# Conclusion

Ecommercial a été conçu pour évoluer progressivement d'une application Flutter autonome vers une marketplace distribuée.

La stratégie retenue est volontairement progressive :

```text
V1 locale
   |
   v
SQLite + fichiers locaux
   |
   v
Identité utilisateur
   |
   v
API REST Node.js / Express / TypeScript
   |
   v
Migration progressive des fonctionnalités
   |
   v
Base de données serveur + stockage fichiers
   |
   v
Marketplace multi-utilisateurs
```

L'objectif n'est donc pas de remplacer brutalement l'application existante, mais de conserver le travail réalisé tout en remplaçant progressivement les composants locaux par des services distants.
