import 'package:flutter/material.dart';
import "package:devmobile/Gestion/page_conexion.dart";
import "package:devmobile/Gestion/page_creer_compte.dart";
import 'package:devmobile/Gestion/page_profile.dart';
import 'package:devmobile/Gestion/page_tableau_bord.dart';
import 'package:devmobile/Gestion/notification_locale_service.dart';


import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
await NotificationLocaleService.instance.initialiser();
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FieldTask Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MaPageAccueil(),
    );
  }
}

class MaPageAccueil extends StatefulWidget {
  const MaPageAccueil({super.key});

  @override
  State<MaPageAccueil> createState() => _MaPageAccueilState();
}

class _MaPageAccueilState extends State<MaPageAccueil> {
  @override
  Widget build(BuildContext context) {
    return PageConexion();
  }
}
