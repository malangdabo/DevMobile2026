
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class InterventionService {
  InterventionService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  static const String _cloudName = 'jfilpioq';
  static const String _uploadPreset = 'monimage';

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('interventions');

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Vous devez être connecté.');
    }
    return user.uid;
  }

  String _normaliser(Object? valeur) =>
      (valeur ?? '').toString().trim().toLowerCase();

  Future<Map<String, dynamic>> _lireIntervention(
    String interventionId,
  ) async {
    final doc = await _collection.doc(interventionId).get();

    if (!doc.exists || doc.data() == null) {
      throw Exception('Cette intervention n’existe pas.');
    }

    return doc.data()!;
  }

  void _verifierResponsable(Map<String, dynamic> data) {
    if ((data['technicienId'] ?? '').toString() != _uid) {
      throw Exception(
        'Vous devez prendre en charge cette intervention avant de la modifier.',
      );
    }
  }

  /// Prendre en charge une intervention.
  /// La transaction empêche deux techniciens de prendre simultanément
  /// la même intervention.
  Future<void> prendreEnCharge(String interventionId) async {
    final reference = _collection.doc(interventionId);
    final uid = _uid;

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);

      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('Intervention introuvable.');
      }

      final data = snapshot.data()!;
      final technicienActuel =
          (data['technicienId'] ?? '').toString().trim();
      final statut = _normaliser(data['statut']);

      if (technicienActuel.isNotEmpty && technicienActuel != uid) {
        throw Exception('Cette intervention est déjà prise en charge.');
      }

      if (statut == 'terminée' ||
          statut == 'terminee' ||
          statut == 'terminé' ||
          statut == 'termine') {
        throw Exception('Cette intervention est déjà terminée.');
      }

      if (technicienActuel == uid) {
        return;
      }

      if (statut != 'en attente' && statut != 'disponible') {
        throw Exception(
          'Cette intervention n’est pas disponible à la prise en charge.',
        );
      }

      transaction.update(reference, {
        'technicienId': uid,
        'prisEnChargePar': uid,
        'statut': 'En cours',
        'datePriseEnCharge': FieldValue.serverTimestamp(),
        'derniereModification': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Envoie une photo sur Cloudinary et sauvegarde son URL dans Firestore.
  Future<String> ajouterPhoto({
    required String interventionId,
    required File fichier,
  }) async {
    final reference = _collection.doc(interventionId);
    final data = await _lireIntervention(interventionId);
    _verifierResponsable(data);

    if (!await fichier.exists()) {
      throw Exception('Le fichier photo est introuvable.');
    }

    final requete = http.MultipartRequest(
      'POST',
      Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      ),
    );

    requete.fields['upload_preset'] = _uploadPreset;
    requete.fields['folder'] = 'fieldtask_pro/interventions/$interventionId/photos';
    requete.files.add(
      await http.MultipartFile.fromPath('file', fichier.path),
    );

    final reponse = await requete.send();
    final contenu = await reponse.stream.bytesToString();

    if (reponse.statusCode < 200 || reponse.statusCode >= 300) {
      throw Exception('Échec de l’envoi de la photo sur Cloudinary : $contenu');
    }

    final resultat = jsonDecode(contenu) as Map<String, dynamic>;
    final url = resultat['secure_url']?.toString();

    if (url == null || url.isEmpty) {
      throw Exception('Cloudinary n’a pas retourné l’URL de la photo.');
    }

    await reference.update({
      'photos': FieldValue.arrayUnion([url]),
      'derniereModification': FieldValue.serverTimestamp(),
    });

    return url;
  }

  /// Envoie la signature PNG encodée en Base64 sur Cloudinary.
  /// Retourne l'URL sécurisée de l'image.
  Future<String> televerserSignature({
    required String interventionId,
    required String signatureBase64,
  }) async {
    final data = await _lireIntervention(interventionId);
    _verifierResponsable(data);

    final contenuBase64 = signatureBase64.contains(',')
        ? signatureBase64.split(',').last
        : signatureBase64;

    final octets = base64Decode(contenuBase64);

    if (octets.isEmpty) {
      throw Exception('La signature est vide.');
    }

    final requete = http.MultipartRequest(
      'POST',
      Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      ),
    );

    requete.fields['upload_preset'] = _uploadPreset;
    requete.fields['folder'] =
        'fieldtask_pro/interventions/$interventionId/signatures';

    requete.files.add(
      http.MultipartFile.fromBytes(
        'file',
        octets,
        filename: 'signature_$interventionId.png',
      ),
    );

    final reponse = await requete.send();
    final contenu = await reponse.stream.bytesToString();

    if (reponse.statusCode < 200 || reponse.statusCode >= 300) {
      throw Exception(
        'Échec de l’envoi de la signature sur Cloudinary : $contenu',
      );
    }

    final resultat = jsonDecode(contenu) as Map<String, dynamic>;
    final url = resultat['secure_url']?.toString();

    if (url == null || url.isEmpty) {
      throw Exception('Cloudinary n’a pas retourné l’URL de la signature.');
    }

    return url;
  }

  /// Enregistre les notes et le statut.
  /// Pour terminer, il faut au moins une photo et une signature enregistrées.
  Future<void> enregistrerTravail({
    required String interventionId,
    required String notes,
    required String statut,
    String? signatureUrl,
  }) async {
    final reference = _collection.doc(interventionId);
    final data = await _lireIntervention(interventionId);
    _verifierResponsable(data);

    final statutNormalise = _normaliser(statut);
    final estTerminee = statutNormalise == 'terminée' ||
        statutNormalise == 'terminee' ||
        statutNormalise == 'terminé' ||
        statutNormalise == 'termine';

    final photos = data['photos'];
    final listePhotos = photos is List ? photos : <dynamic>[];

    final signatureExistante =
        (data['signatureClientUrl'] ?? '').toString().trim();

    final signatureFinale =
        (signatureUrl ?? '').trim().isNotEmpty
            ? signatureUrl!.trim()
            : signatureExistante;

    if (estTerminee && listePhotos.isEmpty) {
      throw Exception(
        'Ajoutez au moins une photo avant de terminer l’intervention.',
      );
    }

    if (estTerminee &&
        (signatureFinale == null || signatureFinale.isEmpty)) {
      throw Exception(
        'La signature du client est obligatoire pour terminer.',
      );
    }

    final misesAJour = <String, dynamic>{
      'notes': notes.trim(),
      'statut': estTerminee ? 'Terminée' : 'En cours',
      'technicienId': _uid,
      'derniereModification': FieldValue.serverTimestamp(),
    };

    if (signatureFinale != null && signatureFinale.isNotEmpty) {
      misesAJour['signatureClientUrl'] = signatureFinale;
    }

    if (estTerminee) {
      misesAJour['dateTerminaison'] = FieldValue.serverTimestamp();
    }

    await reference.update(misesAJour);
  }
}
