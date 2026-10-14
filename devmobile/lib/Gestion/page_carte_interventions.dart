
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

typedef OuvrirDetailIntervention = void Function(
  String interventionId,
  Map<String, dynamic> donnees,
);

const Color couleurBleue = Color(0xFF073B70);

class PageCarteInterventions extends StatefulWidget {
  final OuvrirDetailIntervention? onOuvrirDetail;

  const PageCarteInterventions({
    super.key,
    this.onOuvrirDetail,
  });

  @override
  State<PageCarteInterventions> createState() =>
      _PageCarteInterventionsState();
}

class _PageCarteInterventionsState
    extends State<PageCarteInterventions> {
  final MapController _mapController = MapController();
  final TextEditingController _rechercheController =
      TextEditingController();

  String _recherche = '';
  String _filtreStatut = 'Tous';

  bool _mapPret = false;
  bool _centrageInitialEffectue = false;

  List<_InterventionLocalisee> _dernieresPositions = [];

  static const LatLng _positionDakar = LatLng(14.7167, -17.4677);

  double? _convertirEnDouble(dynamic valeur) {
    if (valeur is num) return valeur.toDouble();

    if (valeur is String) {
      return double.tryParse(valeur.trim());
    }

    return null;
  }

  LatLng? _extrairePosition(Map<String, dynamic> donnees) {
    double? latitude = _convertirEnDouble(donnees['latitude']);
    double? longitude = _convertirEnDouble(donnees['longitude']);

    final localisation = donnees['localisation'];

    if (localisation is GeoPoint) {
      latitude ??= localisation.latitude;
      longitude ??= localisation.longitude;
    }

    if (latitude == null || longitude == null) return null;

    if (!latitude.isFinite || !longitude.isFinite) return null;

    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    if (latitude == 0 && longitude == 0) return null;

    return LatLng(latitude, longitude);
  }

  Color _couleurStatut(String statut) {
    switch (statut.toLowerCase().trim()) {
      case 'en attente':
        return Colors.orange;
      case 'en cours':
        return Colors.blue;
      case 'terminée':
      case 'terminee':
      case 'terminé':
      case 'termine':
        return Colors.green;
      default:
        return Colors.red;
    }
  }

  List<_InterventionLocalisee> _filtrer(
    List<_InterventionLocalisee> interventions,
  ) {
    return interventions.where((intervention) {
      final donnees = intervention.donnees;
      final statut = (donnees['statut'] ?? '').toString();

      final texte = [
        donnees['titre'],
        donnees['client'],
        donnees['adresse'],
        donnees['equipement'],
        donnees['description'],
      ].where((valeur) => valeur != null).join(' ').toLowerCase();

      final recherche = _recherche.toLowerCase().trim();
      final correspondRecherche = texte.contains(recherche);

      final correspondStatut = _filtreStatut == 'Tous' ||
          statut.toLowerCase().trim() ==
              _filtreStatut.toLowerCase().trim();

      return correspondRecherche && correspondStatut;
    }).toList();
  }

  void _onMapReady() {
    _mapPret = true;
    _centrerSiNecessaire(_dernieresPositions);
  }

  void _centrerSiNecessaire(
    List<_InterventionLocalisee> interventions,
  ) {
    if (!_mapPret ||
        _centrageInitialEffectue ||
        interventions.isEmpty) {
      return;
    }

    _ajusterVue(interventions);
    _centrageInitialEffectue = true;
  }

  void _ajusterVue(
    List<_InterventionLocalisee> interventions,
  ) {
    if (!_mapPret || interventions.isEmpty) return;

    final positions = interventions
        .map((intervention) => intervention.position)
        .toList();

    if (positions.length == 1) {
      _mapController.move(positions.first, 15);
    } else {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(positions),
          padding: const EdgeInsets.all(55),
          maxZoom: 16,
        ),
      );
    }
  }

  void _ouvrirIntervention(
    _InterventionLocalisee intervention,
  ) {
    if (widget.onOuvrirDetail != null) {
      widget.onOuvrirDetail!(
        intervention.id,
        intervention.donnees,
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final donnees = intervention.donnees;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (donnees['titre'] ?? 'Intervention').toString(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Client : ${donnees['client'] ?? 'Non renseigné'}',
              ),
              Text(
                'Adresse : ${donnees['adresse'] ?? 'Non renseignée'}',
              ),
              Text(
                'Statut : ${donnees['statut'] ?? 'Non renseigné'}',
              ),
              Text(
                'Priorité : ${donnees['priorite'] ?? 'Non renseignée'}',
              ),
              const SizedBox(height: 12),
              Text('Latitude : ${intervention.position.latitude}'),
              Text('Longitude : ${intervention.position.longitude}'),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  // Correction : cette méthode retourne un Marker.
  Marker _construireMarqueur(
    _InterventionLocalisee intervention,
  ) {
    final donnees = intervention.donnees;
    final statut = (donnees['statut'] ?? '').toString();
    final couleur = _couleurStatut(statut);

    return Marker(
      point: intervention.position,
      width: 48,
      height: 58,
      child: GestureDetector(
        onTap: () => _ouvrirIntervention(intervention),
        child: Tooltip(
          message: (donnees['titre'] ?? 'Intervention').toString(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: couleur,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.build,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              Container(
                width: 3,
                height: 12,
                color: couleur,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _rechercheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carte des interventions'),
        backgroundColor: couleurBleue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('interventions')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Erreur de chargement des interventions :\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final interventions = <_InterventionLocalisee>[];

          for (final document in snapshot.data?.docs ?? []) {
            final donnees = document.data();
            final position = _extrairePosition(donnees);

            if (position != null) {
              interventions.add(
                _InterventionLocalisee(
                  id: document.id,
                  donnees: donnees,
                  position: position,
                ),
              );
            }
          }

          _dernieresPositions = interventions;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _centrerSiNecessaire(_dernieresPositions);
            }
          });

          final interventionsFiltrees = _filtrer(interventions);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: TextField(
                  controller: _rechercheController,
                  onChanged: (valeur) {
                    setState(() => _recherche = valeur);
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: DropdownButtonFormField<String>(
                  initialValue: _filtreStatut,
                  decoration: const InputDecoration(
                    labelText: 'Filtrer par statut',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Tous',
                      child: Text('Tous les statuts'),
                    ),
                    DropdownMenuItem(
                      value: 'En attente',
                      child: Text('En attente'),
                    ),
                    DropdownMenuItem(
                      value: 'En cours',
                      child: Text('En cours'),
                    ),
                    DropdownMenuItem(
                      value: 'Terminée',
                      child: Text('Terminée'),
                    ),
                  ],
                  onChanged: (valeur) {
                    if (valeur != null) {
                      setState(() => _filtreStatut = valeur);
                    }
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: couleurBleue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${interventionsFiltrees.length} intervention(s) '
                        'sur la carte',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter:
                            interventionsFiltrees.isNotEmpty
                                ? interventionsFiltrees.first.position
                                : _positionDakar,
                        initialZoom: 12,
                        onMapReady: _onMapReady,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'devmobile',
                          maxNativeZoom: 19,
                        ),

                        // Correction : MarkerLayer reçoit une List<Marker>.
                        MarkerLayer(
                          markers: interventionsFiltrees
                              .map<Marker>(_construireMarqueur)
                              .toList(),
                        ),

                        RichAttributionWidget(
                          attributions: const [
                            TextSourceAttribution(
                              '© OpenStreetMap contributors',
                            ),
                          ],
                        ),
                      ],
                    ),

                    Positioned(
                      right: 16,
                      bottom: 24,
                      child: FloatingActionButton(
                        heroTag: 'recentrerCarte',
                        backgroundColor: Colors.white,
                        foregroundColor: couleurBleue,
                        tooltip: 'Afficher toutes les interventions',
                        onPressed: () {
                          if (interventionsFiltrees.isNotEmpty) {
                            _ajusterVue(interventionsFiltrees);
                          } else {
                            _mapController.move(_positionDakar, 12);
                          }
                        },
                        child: const Icon(Icons.center_focus_strong),
                      ),
                    ),

                    if (interventionsFiltrees.isEmpty)
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              interventions.isEmpty
                                  ? 'Aucune intervention avec des coordonnées '
                                      'valides dans Firestore.'
                                  : 'Aucune intervention ne correspond '
                                      'à votre recherche ou à ce filtre.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.all(10),
                color: Colors.grey.shade100,
                child: const Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _Legende(
                      couleur: Colors.orange,
                      texte: 'En attente',
                    ),
                    _Legende(
                      couleur: Colors.blue,
                      texte: 'En cours',
                    ),
                    _Legende(
                      couleur: Colors.green,
                      texte: 'Terminée',
                    ),
                    _Legende(
                      couleur: Colors.red,
                      texte: 'Autre statut',
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InterventionLocalisee {
  final String id;
  final Map<String, dynamic> donnees;
  final LatLng position;

  const _InterventionLocalisee({
    required this.id,
    required this.donnees,
    required this.position,
  });
}

class _Legende extends StatelessWidget {
  final Color couleur;
  final String texte;

  const _Legende({
    required this.couleur,
    required this.texte,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 12, color: couleur),
        const SizedBox(width: 4),
        Text(
          texte,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
