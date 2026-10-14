import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:devmobile/Gestion/page_creer_compte.dart';
import 'package:devmobile/Gestion/page_profile.dart';
import 'package:devmobile/Gestion/page_tableau_bord.dart';

class PageConexion extends StatefulWidget {
  const PageConexion({super.key});

  @override
  State<PageConexion> createState() => _PageConexionState();
}

class _PageConexionState extends State<PageConexion> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController motDePasseController =
      TextEditingController();

  bool cachette = true;
  bool chargement = false;

  // Connexion à Firebase
  Future<void> connecter() async {
    final email = emailController.text.trim();
    final password = motDePasseController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir tous les champs.'),
        ),
      );
      return;
    }

    setState(() {
      chargement = true;
    });

    try {
      // 1. Authentifier l'utilisateur
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = userCredential.user;

      if (user == null) {
        throw Exception('Utilisateur non identifié.');
      }

      // 2. Vérifier si l'utilisateur est un agent
      final agentDoc = await FirebaseFirestore.instance
          .collection('agents')
          .doc(user.uid)
          .get();

      // 3. Vérifier si l'utilisateur est dans utilisateurs
      final utilisateurDoc = await FirebaseFirestore.instance
          .collection('utilisateurs')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      if (agentDoc.exists || utilisateurDoc.exists) {
        // 4. Rediriger vers le tableau de bord
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PageTableauBord(
              profilePageBuilder: (_) => const PageProfile(),
            ),
          ),
        );
      } else {
        // Aucun profil correspondant dans Firestore
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Aucun profil trouvé. Vérifiez votre inscription.',
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'invalid-email':
          message = 'L’adresse e-mail est invalide.';
          break;
        case 'user-not-found':
          message = 'Aucun compte ne correspond à cet e-mail.';
          break;
        case 'wrong-password':
          message = 'Mot de passe incorrect.';
          break;
        case 'invalid-credential':
          message = 'E-mail ou mot de passe incorrect.';
          break;
        case 'user-disabled':
          message = 'Ce compte a été désactivé.';
          break;
        case 'too-many-requests':
          message = 'Trop de tentatives. Réessayez plus tard.';
          break;
        case 'network-request-failed':
          message = 'Vérifiez votre connexion Internet.';
          break;
        default:
          message = 'Erreur de connexion : ${e.message ?? e.code}';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur Firestore : ${e.message ?? e.code}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Une erreur est survenue : $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          chargement = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    motDePasseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/FTProFond.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.90),
                  border: Border.all(color: Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Center(
                      child: CircleAvatar(
                        radius: 55,
                        backgroundColor: Colors.white,
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logoFTP.png',
                            width: 105,
                            height: 105,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.engineering,
                                size: 65,
                                color: Colors.green,
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'FieldTask Pro',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Connectez-vous à votre espace',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Champ e-mail
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enabled: !chargement,
                      decoration: InputDecoration(
                        labelText: 'Adresse e-mail',
                        hintText: 'exemple@email.com',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Champ mot de passe
                    TextField(
                      controller: motDePasseController,
                      obscureText: cachette,
                      textInputAction: TextInputAction.done,
                      enabled: !chargement,
                      onSubmitted: (_) {
                        if (!chargement) connecter();
                      },
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: cachette
                              ? 'Afficher le mot de passe'
                              : 'Masquer le mot de passe',
                          onPressed: () {
                            setState(() {
                              cachette = !cachette;
                            });
                          },
                          icon: Icon(
                            cachette
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    // Bouton connexion
                    ElevatedButton(
                      onPressed: chargement ? null : connecter,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: chargement
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Se connecter',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),

                    const SizedBox(height: 15),

                    // Bouton création de compte
                    OutlinedButton(
                      onPressed: chargement
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      PageCreerCompte(),
                                ),
                              );
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green.shade800,
                        minimumSize: const Size(double.infinity, 50),
                        side: const BorderSide(color: Colors.green),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Créer un compte'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
