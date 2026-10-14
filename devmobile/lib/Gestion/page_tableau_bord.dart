import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:devmobile/Gestion/notification_intervention_service.dart';
import 'package:devmobile/Gestion/page_carte_interventions.dart';
import 'package:devmobile/Gestion/page_detail_intervention.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const Color couleurBleue = Color(0xFF073B70);
const Color couleurOrange = Color(0xFFFF7800);
const Color couleurFond = Color(0xFFF4F8FC);

class PageTableauBord extends StatefulWidget {
  final WidgetBuilder profilePageBuilder;

  const PageTableauBord({
    super.key,
    required this.profilePageBuilder,
  });

  @override
  State<PageTableauBord> createState() => _PageTableauBordState();
}

class _PageTableauBordState extends State<PageTableauBord> {
  final TextEditingController _rechercheController =
      TextEditingController();

  final CollectionReference<Map<String, dynamic>> _interventions =
      FirebaseFirestore.instance.collection('interventions');

  StreamSubscription<List<ConnectivityResult>>? _abonnementReseau;

  String _recherche = '';
  String _filtreStatut = 'Toutes';
  bool _triPriorite = true;
  bool _enLigne = true;

  final List<String> _statuts = [
    'Toutes',
    'En attente',
    'En cours',
    'Terminée',
  ];

  @override
  void initState() {
    super.initState();

    _surveillerReseau();

    // Conserver le système de notifications des nouvelles interventions.
    NotificationInterventionService.instance.demarrer();
  }

  Future<void> _surveillerReseau() async {
    try {
      final connectivite = Connectivity();
      final resultat = await connectivite.checkConnectivity();

      if (!mounted) return;

      setState(() {
        _enLigne =
            resultat.any((r) => r != ConnectivityResult.none);
      });

      _abonnementReseau =
          connectivite.onConnectivityChanged.listen((resultats) {
        if (!mounted) return;

        setState(() {
          _enLigne =
              resultats.any((r) => r != ConnectivityResult.none);
        });
      });
    } catch (erreur) {
      debugPrint('Erreur de connectivité : $erreur');

      if (mounted) {
        setState(() => _enLigne = false);
      }
    }
  }

  @override
  void dispose() {
    _rechercheController.dispose();
    _abonnementReseau?.cancel();

    // Arrêter proprement le service de notifications.
    unawaited(
      NotificationInterventionService.instance.arreter(),
    );

    super.dispose();
  }

  String _texte(
    dynamic valeur, [
    String defaut = 'Non renseigné',
  ]) {
    if (valeur == null || valeur.toString().trim().isEmpty) {
      return defaut;
    }

    return valeur.toString().trim();
  }

  String _normaliser(String valeur) {
    return valeur.trim().toLowerCase();
  }

  int _rangPriorite(String priorite) {
    switch (_normaliser(priorite)) {
      case 'critique':
      case 'urgente':
      case 'urgent':
        return 0;

      case 'haute':
      case 'haut':
      case 'élevée':
      case 'elevee':
        return 1;

      case 'normale':
      case 'normal':
      case 'moyenne':
      case 'moyen':
        return 2;

      case 'faible':
      case 'basse':
      case 'bas':
        return 3;

      default:
        return 4;
    }
  }

  Color _couleurStatut(String statut) {
    switch (_normaliser(statut)) {
      case 'en cours':
        return Colors.blue;

      case 'terminée':
      case 'terminee':
      case 'terminé':
      case 'termine':
        return Colors.green;

      case 'en attente':
      case 'disponible':
        return couleurOrange;

      default:
        return Colors.grey;
    }
  }

  Color _couleurPriorite(String priorite) {
    switch (_rangPriorite(priorite)) {
      case 0:
        return Colors.red;

      case 1:
        return Colors.deepOrange;

      case 2:
        return Colors.blue;

      case 3:
        return Colors.green;

      default:
        return Colors.grey;
    }
  }

  bool _correspondRecherche(Map<String, dynamic> data) {
    if (_recherche.trim().isEmpty) return true;

    final terme = _normaliser(_recherche);

    final champs = [
      data['titre'],
      data['client'],
      data['nomClient'],
      data['adresse'],
      data['description'],
      data['equipement'],
      data['priorite'],
      data['statut'],
      data['technicienNom'],
    ];

    return champs.any(
      (champ) =>
          (champ ?? '').toString().toLowerCase().contains(terme),
    );
  }

  DateTime? _dateIntervention(Map<String, dynamic> data) {
    final valeur = data['dateIntervention'] ?? data['createdAt'];

    if (valeur is Timestamp) return valeur.toDate();
    if (valeur is DateTime) return valeur;
    if (valeur is String) return DateTime.tryParse(valeur);

    return null;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtrerEtTrier(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    final resultat = documents.where((document) {
      final data = document.data();
      final statut = _texte(data['statut'], 'En attente');

      final statutCorrespond = _filtreStatut == 'Toutes' ||
          _normaliser(statut) == _normaliser(_filtreStatut);

      return statutCorrespond && _correspondRecherche(data);
    }).toList();

    resultat.sort((a, b) {
      final dataA = a.data();
      final dataB = b.data();

      if (_triPriorite) {
        final comparaisonPriorite = _rangPriorite(
          _texte(dataA['priorite'], ''),
        ).compareTo(
          _rangPriorite(_texte(dataB['priorite'], '')),
        );

        if (comparaisonPriorite != 0) {
          return comparaisonPriorite;
        }

        final dateA = _dateIntervention(dataA);
        final dateB = _dateIntervention(dataB);

        if (dateA != null && dateB != null) {
          return dateA.compareTo(dateB);
        }

        if (dateA != null) return -1;
        if (dateB != null) return 1;

        return _texte(dataA['titre'], '')
            .compareTo(_texte(dataB['titre'], ''));
      }

      return _texte(dataA['titre'], '')
          .toLowerCase()
          .compareTo(
            _texte(dataB['titre'], '').toLowerCase(),
          );
    });

    return resultat;
  }

  void _ouvrirDetails(
    String interventionId,
    Map<String, dynamic> donnees,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PageDetailIntervention(
          interventionId: interventionId,
          donneesInitiales: donnees,
        ),
      ),
    );
  }

  void _ouvrirCarte() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PageCarteInterventions(
          onOuvrirDetail: (interventionId, donnees) {
            _ouvrirDetails(interventionId, donnees);
          },
        ),
      ),
    );
  }

  void _ouvrirProfil() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: widget.profilePageBuilder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final utilisateur = FirebaseAuth.instance.currentUser;

    if (utilisateur == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('FieldTask Pro'),
          backgroundColor: couleurBleue,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text(
            'Connecte-toi pour accéder au tableau de bord.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: couleurFond,
      appBar: AppBar(
        backgroundColor: couleurBleue,
        foregroundColor: Colors.white,
        title: const Text(
          'Tableau de bord',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Voir la carte des interventions',
            icon: const Icon(Icons.map_outlined),
            onPressed: _ouvrirCarte,
          ),

          // Le bouton de notifications a été retiré.
          // Le service de notifications reste actif.

          IconButton(
            tooltip: 'Mon profil',
            icon: const Icon(Icons.person_outline),
            onPressed: _ouvrirProfil,
          ),

          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _enLigne
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _enLigne ? Icons.wifi : Icons.wifi_off,
                      size: 15,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _enLigne ? 'En ligne' : 'Hors ligne',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _construireEntete(utilisateur.email ?? ''),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                controller: _rechercheController,
                onChanged: (value) {
                  setState(() => _recherche = value);
                },
                decoration: InputDecoration(
                  hintText: 'Rechercher une intervention...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _recherche.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _rechercheController.clear();
                            setState(() => _recherche = '');
                          },
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            _construireFiltres(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Interventions partagées',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: couleurBleue,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _triPriorite = !_triPriorite;
                      });
                    },
                    icon: Icon(
                      _triPriorite
                          ? Icons.priority_high
                          : Icons.sort_by_alpha,
                    ),
                    label: Text(
                      _triPriorite ? 'Priorité' : 'Titre',
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: StreamBuilder<
                  QuerySnapshot<Map<String, dynamic>>>(
                stream: _interventions.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Impossible de charger les interventions.\n\n'
                          'Détail : ${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState ==
                          ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: couleurBleue,
                      ),
                    );
                  }

                  final documents = snapshot.data?.docs ?? [];
                  final interventions = _filtrerEtTrier(documents);

                  if (interventions.isEmpty) {
                    return _construireEtatVide(
                      documents.isEmpty
                          ? 'Aucune intervention enregistrée.'
                          : 'Aucune intervention ne correspond à ta recherche.',
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      try {
                        await _interventions.get(
                          const GetOptions(source: Source.server),
                        );
                      } catch (erreur) {
                        debugPrint(
                          'Erreur lors de l’actualisation : $erreur',
                        );
                      }
                    },
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        14,
                        4,
                        14,
                        24,
                      ),
                      itemCount: interventions.length,
                      itemBuilder: (context, index) {
                        final document = interventions[index];

                        return _carteIntervention(
                          document.id,
                          document.data(),
                          utilisateur.uid,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construireEntete(String email) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: couleurBleue.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.engineering_outlined,
              color: couleurBleue,
              size: 29,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bonjour, technicien !',
                  style: TextStyle(
                    color: couleurBleue,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(color: Colors.black54),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Consulte les missions et prends en charge une mission disponible.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construireFiltres() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 6,
        ),
        scrollDirection: Axis.horizontal,
        itemCount: _statuts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final statut = _statuts[index];
          final selectionne = _filtreStatut == statut;

          return ChoiceChip(
            label: Text(statut),
            selected: selectionne,
            selectedColor: couleurBleue,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: selectionne ? Colors.white : couleurBleue,
              fontWeight: FontWeight.w600,
            ),
            onSelected: (_) {
              setState(() => _filtreStatut = statut);
            },
          );
        },
      ),
    );
  }

  Widget _construireEtatVide(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 62,
              color: couleurBleue.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _carteIntervention(
    String id,
    Map<String, dynamic> data,
    String uid,
  ) {
    final titre = _texte(
      data['titre'],
      'Intervention sans titre',
    );

    final client = _texte(
      data['client'] ?? data['nomClient'],
    );

    final adresse = _texte(data['adresse']);
    final statut = _texte(data['statut'], 'En attente');
    final priorite = _texte(data['priorite'], 'Normale');

    final responsable =
        (data['technicienId'] ?? '').toString().trim();

    final estResponsable = responsable == uid;

    final statutNormalise = _normaliser(statut);

    final estDisponible = responsable.isEmpty &&
        (statutNormalise == 'en attente' ||
            statutNormalise == 'disponible');

    final responsableNom = _texte(
      data['technicienNom'],
      estResponsable ? 'Toi' : 'Un autre technicien',
    );

    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _ouvrirDetails(id, data),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      titre,
                      style: const TextStyle(
                        color: couleurBleue,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _badge(statut, _couleurStatut(statut)),
                ],
              ),

              const SizedBox(height: 10),

              _ligneInfo(Icons.business_outlined, client),
              _ligneInfo(Icons.location_pin, adresse),

              const SizedBox(height: 8),

              Row(
                children: [
                  const Text(
                    'Priorité : ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  _badge(priorite, _couleurPriorite(priorite)),
                ],
              ),

              if (responsable.isNotEmpty) ...[
                const SizedBox(height: 8),
                _ligneInfo(
                  Icons.person_outline,
                  estResponsable
                      ? 'Prise en charge par toi'
                      : 'Déjà prise en charge : $responsableNom',
                ),
              ],

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: estDisponible
                    ? FilledButton.icon(
                        onPressed: () => _ouvrirDetails(id, data),
                        icon: const Icon(
                          Icons.assignment_turned_in_outlined,
                        ),
                        label: const Text(
                          'Voir et prendre en charge',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: couleurBleue,
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: () => _ouvrirDetails(id, data),
                        icon: const Icon(Icons.visibility_outlined),
                        label: Text(
                          estResponsable
                              ? 'Continuer mon intervention'
                              : 'Consulter la fiche',
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ligneInfo(IconData icone, String texte) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icone,
            size: 17,
            color: Colors.black54,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              texte,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String texte, Color couleur) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texte,
        style: TextStyle(
          color: couleur,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
