
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationLocaleService {
  NotificationLocaleService._();

  static final NotificationLocaleService instance =
      NotificationLocaleService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _abonnement;

  final Set<String> _interventionsConnues = <String>{};

  bool _initialise = false;
  bool _premierChargement = true;

  /// Initialise les notifications et écoute Firestore.
  Future<void> initialiser() async {
    if (_initialise) return;

    const parametresAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const parametres = InitializationSettings(
      android: parametresAndroid,
    );

    await _plugin.initialize(
      settings: parametres,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();

    _initialise = true;

    _abonnement = FirebaseFirestore.instance
        .collection('interventions')
        .snapshots()
        .listen(
      _traiterChangements,
      onError: (Object erreur) {
        print('Erreur écoute interventions : $erreur');
      },
    );
  }

  /// Détecte les nouvelles interventions.
  Future<void> _traiterChangements(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    // Au premier chargement, mémoriser les interventions existantes.
    if (_premierChargement) {
      for (final document in snapshot.docs) {
        _interventionsConnues.add(document.id);
      }

      _premierChargement = false;
      return;
    }

    for (final changement in snapshot.docChanges) {
      if (changement.type != DocumentChangeType.added) {
        continue;
      }

      final document = changement.doc;

      // Éviter les doublons pendant cette session.
      if (!_interventionsConnues.add(document.id)) {
        continue;
      }

      final data = document.data();

      final String titreIntervention =
          data?['titre']?.toString() ??
          'Nouvelle intervention';

      final String client =
          data?['client']?.toString() ??
          data?['nomClient']?.toString() ??
          'Client non renseigné';

      try {
        await _afficherNotification(
          id: document.id.hashCode & 0x7fffffff,
          titre: 'Nouvelle intervention',
          message: '$titreIntervention — $client',
        );
      } catch (erreur) {
        print('Erreur affichage notification : $erreur');
      }
    }
  }

  /// Affiche une notification Android.
  Future<void> _afficherNotification({
    required int id,
    required String titre,
    required String message,
  }) async {
    const detailsAndroid = AndroidNotificationDetails(
      'fieldtask_interventions',
      'Nouvelles interventions',
      channelDescription:
          'Alertes lors de l’ajout de nouvelles interventions',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const details = NotificationDetails(
      android: detailsAndroid,
    );

    await _plugin.show(
      id: id,
      title: titre,
      body: message,
      notificationDetails: details,
    );
  }

  /// Arrête l'écoute Firestore.
  Future<void> fermer() async {
    await _abonnement?.cancel();

    _abonnement = null;
    _initialise = false;
    _premierChargement = true;

    _interventionsConnues.clear();
  }
}
