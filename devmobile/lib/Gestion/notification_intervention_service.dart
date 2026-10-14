import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class NotificationInterventionService {
  NotificationInterventionService._();

  static final NotificationInterventionService instance =
      NotificationInterventionService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _abonnement;

  final Set<String> _interventionsConnues = <String>{};

  bool _premierChargementTermine = false;

  /// Démarre la surveillance des nouvelles interventions.
  void demarrer() {
    if (_abonnement != null) return;

    final utilisateur = _auth.currentUser;

    if (utilisateur == null) {
      debugPrint(
        'Notification : aucun utilisateur connecté.',
      );
      return;
    }

    _interventionsConnues.clear();
    _premierChargementTermine = false;

    _abonnement = _db
        .collection('interventions')
        .snapshots()
        .listen(
      (snapshot) async {
        // Ignorer les interventions présentes au démarrage.
        if (!_premierChargementTermine) {
          for (final document in snapshot.docs) {
            _interventionsConnues.add(document.id);
          }

          _premierChargementTermine = true;
          return;
        }

        for (final changement in snapshot.docChanges) {
          if (changement.type != DocumentChangeType.added) {
            continue;
          }

          final document = changement.doc;
          final interventionId = document.id;

          // Éviter de traiter deux fois la même intervention.
          if (!_interventionsConnues.add(interventionId)) {
            continue;
          }

          // Récupérer les données de l'intervention.
          final donneesIntervention = document.data();

          // Vérifier que les données sont disponibles.
          if (donneesIntervention == null) {
            debugPrint(
              'Intervention sans données : $interventionId',
            );
            continue;
          }

          final titre =
              (donneesIntervention['titre'] ??
                      'Nouvelle intervention')
                  .toString();

          final statut =
              (donneesIntervention['statut'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();

          final technicienId =
              (donneesIntervention['technicienId'] ?? '')
                  .toString()
                  .trim();

          // Ne notifier que les interventions disponibles.
          if (statut != 'en attente' &&
              statut != 'disponible') {
            continue;
          }

          // Ignorer les interventions déjà attribuées.
          if (technicienId.isNotEmpty) {
            continue;
          }

          final client =
              (donneesIntervention['client'] ??
                      donneesIntervention['nomClient'] ??
                      '')
                  .toString();

          final adresse =
              (donneesIntervention['adresse'] ?? '')
                  .toString();

          try {
            await _creerNotification(
              utilisateurId: utilisateur.uid,
              interventionId: interventionId,
              titreIntervention: titre,
              client: client,
              adresse: adresse,
            );
          } catch (erreur, stackTrace) {
            debugPrint(
              'Erreur de création de notification : $erreur',
            );
            debugPrintStack(stackTrace: stackTrace);
          }
        }
      },
      onError: (Object erreur) {
        debugPrint(
          'Erreur de surveillance Firestore : $erreur',
        );
      },
    );
  }

  /// Crée une notification dans la collection notifications.
  Future<void> _creerNotification({
    required String utilisateurId,
    required String interventionId,
    required String titreIntervention,
    required String client,
    required String adresse,
  }) async {
    final notificationId =
        '${utilisateurId}_$interventionId';

    final reference =
        _db.collection('notifications').doc(notificationId);

    // Éviter de créer plusieurs fois la même notification.
    final existante = await reference.get();

    if (existante.exists) {
      debugPrint(
        'Notification déjà existante : $notificationId',
      );
      return;
    }

    final message = <String>[
      titreIntervention,
      if (client.trim().isNotEmpty) client.trim(),
      if (adresse.trim().isNotEmpty) adresse.trim(),
    ].join(' — ');

    await reference.set({
      'utilisateurId': utilisateurId,
      'interventionId': interventionId,
      'titre': 'Nouvelle intervention disponible',
      'message': message,
      'type': 'intervention',
      'lue': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    debugPrint(
      'Notification créée pour l’intervention $interventionId',
    );
  }

  /// Arrête la surveillance des interventions.
  Future<void> arreter() async {
    await _abonnement?.cancel();

    _abonnement = null;
    _premierChargementTermine = false;
    _interventionsConnues.clear();
  }
}
