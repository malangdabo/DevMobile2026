
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';

import 'intervention_service.dart';

const Color couleurBleue = Color(0xFF073B70);
const Color couleurOrange = Color(0xFFFF7800);
const Color couleurFond = Color(0xFFF4F8FC);

class PageDetailIntervention extends StatefulWidget {
  const PageDetailIntervention({
    super.key,
    required this.interventionId,
    this.donneesInitiales,
  });

  final String interventionId;
  final Map<String, dynamic>? donneesInitiales;

  @override
  State<PageDetailIntervention> createState() =>
      _PageDetailInterventionState();
}

class _PageDetailInterventionState extends State<PageDetailIntervention> {
  final InterventionService _service = InterventionService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _notesController = TextEditingController();
  final GlobalKey _signatureKey = GlobalKey();

  final List<File> _photosEnAttente = [];
  final List<Offset?> _pointsSignature = [];

  bool _enregistrement = false;
  bool _champsInitialises = false;
  bool _signatureModifiee = false;

  String get _uid => _auth.currentUser?.uid ?? '';

  DocumentReference<Map<String, dynamic>> get _reference =>
      _db.collection('interventions').doc(widget.interventionId);

  String _normaliser(Object? valeur) =>
      (valeur ?? '').toString().trim().toLowerCase();

  bool _estTerminee(String? statut) {
    final valeur = _normaliser(statut);
    return valeur == 'terminée' ||
        valeur == 'terminee' ||
        valeur == 'terminé' ||
        valeur == 'termine';
  }

  bool _estDisponible(Map<String, dynamic> data) {
    final technicienId = (data['technicienId'] ?? '').toString().trim();
    final statut = _normaliser(data['statut']);

    return technicienId.isEmpty &&
        (statut == 'en attente' || statut == 'disponible');
  }

  bool _estResponsable(Map<String, dynamic> data) {
    return (data['technicienId'] ?? '').toString() == _uid &&
        _uid.isNotEmpty;
  }

  void _initialiserChamps(Map<String, dynamic> data) {
    if (_champsInitialises) return;

    _notesController.text = (data['notes'] ?? '').toString();
    _champsInitialises = true;
  }

  void _message(String message, {bool erreur = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: erreur ? Colors.red.shade700 : couleurBleue,
      ),
    );
  }

  Future<void> _prendreEnCharge() async {
    if (_enregistrement) return;

    setState(() => _enregistrement = true);

    try {
      await _service.prendreEnCharge(widget.interventionId);
      _message('Intervention prise en charge avec succès.');
    } catch (e) {
      _message(
        e.toString().replaceFirst('Exception: ', ''),
        erreur: true,
      );
    } finally {
      if (mounted) setState(() => _enregistrement = false);
    }
  }

  Future<void> _ajouterPhoto(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1800,
      );

      if (photo == null || !mounted) return;

      setState(() => _photosEnAttente.add(File(photo.path)));
    } catch (e) {
      _message('Impossible de sélectionner la photo : $e', erreur: true);
    }
  }

  Future<void> _afficherChoixPhoto() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: couleurBleue),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(context);
                _ajouterPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: couleurBleue),
              title: const Text('Choisir dans la galerie'),
              onTap: () {
                Navigator.pop(context);
                _ajouterPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _effacerSignature() {
    setState(() {
      _pointsSignature.clear();
      _signatureModifiee = true;
    });
  }

  bool get _signatureContientDesTraits =>
      _pointsSignature.any((point) => point != null);

  Future<String?> _recupererSignatureBase64() async {
    if (!_signatureContientDesTraits) return null;

    final contexte = _signatureKey.currentContext;
    if (contexte == null) {
      throw Exception('La zone de signature est indisponible.');
    }

    final objet = contexte.findRenderObject();
    if (objet is! RenderRepaintBoundary) {
      throw Exception('Impossible de capturer la signature.');
    }

    final ui.Image image = await objet.toImage(pixelRatio: 3);
    try {
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        throw Exception('Impossible de convertir la signature en PNG.');
      }

      return base64Encode(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
      );
    } finally {
      image.dispose();
    }
  }

  Future<void> _enregistrer(
    Map<String, dynamic> data, {
    required bool terminer,
  }) async {
    if (_enregistrement) return;

    setState(() => _enregistrement = true);

    try {
      if (!_estResponsable(data)) {
        throw Exception(
          'Vous devez prendre en charge cette intervention avant de la modifier.',
        );
      }

      // 1. Envoyer les nouvelles photos vers Cloudinary.
      for (final photo in List<File>.from(_photosEnAttente)) {
        await _service.ajouterPhoto(
          interventionId: widget.interventionId,
          fichier: photo,
        );
      }

      if (mounted) {
        setState(() => _photosEnAttente.clear());
      }

      // 2. Envoyer la signature vers Cloudinary si elle a été dessinée.
      String? signatureUrl;
      if (_signatureModifiee && _signatureContientDesTraits) {
        final signatureBase64 = await _recupererSignatureBase64();

        if (signatureBase64 != null) {
          signatureUrl = await _service.televerserSignature(
            interventionId: widget.interventionId,
            signatureBase64: signatureBase64,
          );
        }
      }

      // 3. Enregistrer les notes, la signature et le statut dans Firestore.
      await _service.enregistrerTravail(
        interventionId: widget.interventionId,
        notes: _notesController.text,
        statut: terminer ? 'Terminée' : 'En cours',
        signatureUrl: signatureUrl,
      );

      if (!mounted) return;

      setState(() {
        _pointsSignature.clear();
        _signatureModifiee = false;
      });

      _message(
        terminer
            ? 'Intervention terminée. Signature et travail enregistrés.'
            : 'Travail enregistré avec succès.',
      );
    } catch (e) {
      _message(
        e.toString().replaceFirst('Exception: ', ''),
        erreur: true,
      );
    } finally {
      if (mounted) setState(() => _enregistrement = false);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: couleurFond,
      appBar: AppBar(
        title: const Text('Détail de l’intervention'),
        backgroundColor: couleurBleue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _reference.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Erreur lors du chargement de l’intervention.'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final document = snapshot.data!;

          if (!document.exists || document.data() == null) {
            return const Center(
              child: Text('Cette intervention n’existe pas.'),
            );
          }

          final data = document.data()!;
          _initialiserChamps(data);

          final titre = (data['titre'] ??
                  data['objet'] ??
                  data['description'] ??
                  'Intervention')
              .toString();

          final client = (data['client'] ??
                  data['nomClient'] ??
                  'Client non renseigné')
              .toString();

          final statut = (data['statut'] ?? 'En attente').toString();
          final photosData = data['photos'];
          final photos = photosData is List
              ? photosData.map((e) => e.toString()).toList()
              : <String>[];

          final signatureUrl =
              (data['signatureClientUrl'] ?? '').toString().trim();

          final terminee = _estTerminee(statut);
          final disponible = _estDisponible(data);
          final responsable = _estResponsable(data);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _carte(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titre,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: couleurBleue,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ligneInfo(Icons.person_outline, 'Client', client),
                    _ligneInfo(Icons.flag_outlined, 'Statut', statut),
                    if ((data['adresse'] ?? '').toString().isNotEmpty)
                      _ligneInfo(
                        Icons.location_on_outlined,
                        'Adresse',
                        data['adresse'].toString(),
                      ),
                    if ((data['priorite'] ?? '').toString().isNotEmpty)
                      _ligneInfo(
                        Icons.priority_high,
                        'Priorité',
                        data['priorite'].toString(),
                      ),
                    if ((data['description'] ?? '').toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(data['description'].toString()),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (disponible)
                _carte(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cette intervention est disponible.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              _enregistrement ? null : _prendreEnCharge,
                          icon: const Icon(Icons.assignment_turned_in),
                          label: const Text('Prendre en charge'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: couleurOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (terminee)
                _afficherInterventionTerminee(
                  data,
                  photos,
                  signatureUrl,
                )
              else if (responsable)
                _formulaireTravail(data, photos, signatureUrl)
              else
                _carte(
                  child: const Text(
                    'Cette intervention est déjà attribuée à un autre '
                    'technicien, ou son statut ne permet pas sa prise en charge.',
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _formulaireTravail(
    Map<String, dynamic> data,
    List<String> photos,
    String signatureUrl,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _carte(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Compte rendu du technicien',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: couleurBleue,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notes du travail effectué',
                  hintText: 'Décrivez les actions réalisées...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Photos de preuve',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${photos.length} photo(s) déjà enregistrée(s) · '
                '${_photosEnAttente.length} nouvelle(s)',
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final url in photos)
                    _vignettePhoto(
                      Image.network(
                        url,
                        width: 95,
                        height: 95,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(
                          width: 95,
                          height: 95,
                          child: Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                  for (int i = 0; i < _photosEnAttente.length; i++)
                    _vignettePhoto(
                      Image.file(
                        _photosEnAttente[i],
                        width: 95,
                        height: 95,
                        fit: BoxFit.cover,
                      ),
                      onRemove: () {
                        setState(() => _photosEnAttente.removeAt(i));
                      },
                    ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed:
                    _enregistrement ? null : _afficherChoixPhoto,
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Ajouter une photo'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _carte(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Signature du client',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: couleurBleue,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Demandez au client de signer dans la zone blanche '
                'avec son doigt.',
              ),
              const SizedBox(height: 12),
              if (signatureUrl.isNotEmpty && !_signatureModifiee) ...[
                const Text(
                  'Signature déjà enregistrée :',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    height: 120,
                    color: Colors.white,
                    child: Image.network(
                      signatureUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text('Impossible de charger la signature.'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              RepaintBoundary(
                key: _signatureKey,
                child: Container(
                  width: double.infinity,
                  height: 190,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.blueGrey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (details) {
                      setState(() {
                        _signatureModifiee = true;
                        _pointsSignature.add(details.localPosition);
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        _signatureModifiee = true;
                        _pointsSignature.add(details.localPosition);
                      });
                    },
                    onPanEnd: (_) {
                      setState(() => _pointsSignature.add(null));
                    },
                    child: CustomPaint(
                      painter: _SignaturePainter(_pointsSignature),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Signez ci-dessus',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _enregistrement ? null : _effacerSignature,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Effacer'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _carte(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enregistrement',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: couleurBleue,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _enregistrement
                    ? null
                    : () => _enregistrer(data, terminer: false),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Enregistrer le travail'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: couleurBleue,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _enregistrement
                    ? null
                    : () => _confirmerTerminaison(data),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Terminer l’intervention'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: couleurOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              if (_enregistrement) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 8),
                const Text(
                  'Enregistrement des données...',
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmerTerminaison(
    Map<String, dynamic> data,
  ) async {
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminer l’intervention ?'),
        content: const Text(
          'Vérifiez les photos, les notes et la signature du client. '
          'Une photo et une signature sont obligatoires.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmer == true && mounted) {
      await _enregistrer(data, terminer: true);
    }
  }

  Widget _afficherInterventionTerminee(
    Map<String, dynamic> data,
    List<String> photos,
    String signatureUrl,
  ) {
    return _carte(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 42,
          ),
          const SizedBox(height: 8),
          const Text(
            'Intervention terminée',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: couleurBleue,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Compte rendu',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            (data['notes'] ?? 'Aucune note enregistrée.').toString(),
          ),
          const SizedBox(height: 18),
          const Text(
            'Photos de preuve',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (photos.isEmpty)
            const Text('Aucune photo enregistrée.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: photos
                  .map(
                    (url) => _vignettePhoto(
                      Image.network(
                        url,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(
                          width: 100,
                          height: 100,
                          child: Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 18),
          const Text(
            'Signature du client',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (signatureUrl.isEmpty)
            const Text('Aucune signature enregistrée.')
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                height: 150,
                color: Colors.white,
                child: Image.network(
                  signatureUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text('Impossible de charger la signature.'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _carte({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _ligneInfo(IconData icone, String libelle, String valeur) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 19, color: couleurBleue),
          const SizedBox(width: 8),
          Text(
            '$libelle : ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Expanded(child: Text(valeur)),
        ],
      ),
    );
  }

  Widget _vignettePhoto(
    Widget image, {
    VoidCallback? onRemove,
  }) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: image,
        ),
        if (onRemove != null)
          Positioned(
            top: 2,
            right: 2,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              icon: const Icon(Icons.cancel, color: Colors.red),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.points);

  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final pinceau = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      if (point == null) continue;

      if (i + 1 < points.length && points[i + 1] != null) {
        canvas.drawLine(point, points[i + 1]!, pinceau);
      } else {
        canvas.drawCircle(point, 1.5, pinceau);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
