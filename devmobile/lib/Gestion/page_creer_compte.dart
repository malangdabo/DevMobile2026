
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:devmobile/Gestion/page_conexion.dart';

class PageCreerCompte extends StatefulWidget {
  const PageCreerCompte({super.key});

  @override
  State<PageCreerCompte> createState() => _PageCreerCompteState();
}

class _PageCreerCompteState extends State<PageCreerCompte> {
  final _formKey = GlobalKey<FormState>();

  final nomController = TextEditingController();
  final prenomController = TextEditingController();
  final emailController = TextEditingController();
  final telephoneController = TextEditingController();
  final zoneController = TextEditingController();
  final motDePasseController = TextEditingController();
  final confirmationController = TextEditingController();

  bool cachette = true;
  bool chargement = false;

  String roleSelectionne = 'Technicien de terrain';

  final List<String> roles = [
    'Technicien de terrain',
    'Administrateur',
    'Superviseur',
  ];

  static const Color bleuMarine = Color(0xFF073B70);
  static const Color orange = Color(0xFFFF7800);

  @override
  void dispose() {
    nomController.dispose();
    prenomController.dispose();
    emailController.dispose();
    telephoneController.dispose();
    zoneController.dispose();
    motDePasseController.dispose();
    confirmationController.dispose();
    super.dispose();
  }

  Future<void> creerCompte() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => chargement = true);

    try {
      final nom = nomController.text.trim();
      final prenom = prenomController.text.trim();
      final email = emailController.text.trim();
      final telephone = telephoneController.text.trim();
      final zone = zoneController.text.trim();

      // 1. Création du compte Firebase Authentication.
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: motDePasseController.text,
      );

      final user = userCredential.user;

      if (user == null) {
        throw Exception("Impossible de créer l'utilisateur.");
      }

      // 2. Enregistrement des informations du profil dans Firestore.
      await FirebaseFirestore.instance
          .collection('utilisateurs')
          .doc(user.uid)
          .set({
        'uid': user.uid,
        'nom': nom,
        'prenom': prenom,
        'email': email,
        'telephone': telephone,
        'role': roleSelectionne,
        'zone': zone,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bienvenue $prenom ! Ton compte est créé.'),
          backgroundColor: Colors.green,
        ),
      );

      // 3. Retourner à la page de connexion.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PageConexion(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'weak-password':
          message = 'Le mot de passe est trop faible.';
          break;
        case 'email-already-in-use':
          message = 'Cette adresse e-mail est déjà utilisée.';
          break;
        case 'invalid-email':
          message = 'L’adresse e-mail est invalide.';
          break;
        case 'network-request-failed':
          message = 'Vérifie ta connexion Internet.';
          break;
        default:
          message = e.message ?? 'Erreur lors de la création du compte.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => chargement = false);
      }
    }
  }

  InputDecoration decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: bleuMarine),
      filled: true,
      fillColor: Colors.white.withOpacity(0.85),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD8E6F3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: orange, width: 1.5),
      ),
    );
  }

  Widget champTexte({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: keyboardType == TextInputType.text
          ? TextCapitalization.words
          : TextCapitalization.none,
      decoration: decoration(label, icon),
      validator: validator ??
          (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Ce champ est obligatoire.';
            }
            return null;
          },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF5FF),
      body: Container(
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
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 460),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.94),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: Colors.white),
                  boxShadow: [
                    BoxShadow(
                      color: bleuMarine.withOpacity(0.12),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.engineering,
                        color: bleuMarine,
                        size: 54,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'FieldTask Pro',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.bold,
                          color: bleuMarine,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Créer votre compte technicien',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 25),

                      champTexte(
                        controller: nomController,
                        label: 'Nom',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 14),

                      champTexte(
                        controller: prenomController,
                        label: 'Prénom',
                        icon: Icons.person,
                      ),
                      const SizedBox(height: 14),

                      champTexte(
                        controller: emailController,
                        label: 'Adresse e-mail',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'L’e-mail est obligatoire.';
                          }
                          if (!RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          ).hasMatch(value.trim())) {
                            return 'Saisis une adresse e-mail valide.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      champTexte(
                        controller: telephoneController,
                        label: 'Téléphone',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 14),

                      champTexte(
                        controller: zoneController,
                        label: 'Zone d’intervention',
                        icon: Icons.location_on_outlined,
                      ),
                      const SizedBox(height: 14),

                      DropdownButtonFormField<String>(
                        value: roleSelectionne,
                        decoration: decoration(
                          'Rôle',
                          Icons.badge_outlined,
                        ),
                        items: roles.map((role) {
                          return DropdownMenuItem(
                            value: role,
                            child: Text(
                              role,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => roleSelectionne = value);
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: motDePasseController,
                        obscureText: cachette,
                        decoration: decoration(
                          'Mot de passe',
                          Icons.lock_outline,
                        ).copyWith(
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() => cachette = !cachette);
                            },
                            icon: Icon(
                              cachette
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Le mot de passe est obligatoire.';
                          }
                          if (value.length < 6) {
                            return 'Minimum 6 caractères.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: confirmationController,
                        obscureText: cachette,
                        decoration: decoration(
                          'Confirmer le mot de passe',
                          Icons.lock_reset,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Confirme ton mot de passe.';
                          }
                          if (value != motDePasseController.text) {
                            return 'Les mots de passe sont différents.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: chargement ? null : creerCompte,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: chargement
                              ? const SizedBox(
                                  height: 23,
                                  width: 23,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Créer mon compte',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextButton(
                        onPressed: chargement
                            ? null
                            : () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PageConexion(),
                                  ),
                                );
                              },
                        child: const Text(
                          'Déjà un compte ? Se connecter',
                          style: TextStyle(color: bleuMarine),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
