
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'page_conexion.dart';

class PageProfile extends StatefulWidget {
  final VoidCallback? onLogout;

  const PageProfile({
    super.key,
    this.onLogout,
  });

  @override
  State<PageProfile> createState() => _PageProfileState();
}

class _PageProfileState extends State<PageProfile> {
  static const Color navy = Color(0xFF073B70);
  static const Color orange = Color(0xFFFF7800);
  static const Color lightBlue = Color(0xFFEAF5FF);

  String fullName = '';
  String email = '';
  String phone = '';
  String role = 'Technicien de terrain';
  String zone = '';

  bool chargementProfil = true;
  bool enregistrement = false;
  bool _chargement = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    chargerProfil();
  }

  // Charger le profil depuis Firestore.
  Future<void> chargerProfil() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        if (!mounted) return;
        setState(() => chargementProfil = false);
        return;
      }

      final doc = await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      final data = doc.data() ?? <String, dynamic>{};

      final prenom = (data['prenom'] ?? '').toString().trim();
      final nom = (data['nom'] ?? '').toString().trim();

      setState(() {
        fullName = [prenom, nom]
            .where((part) => part.isNotEmpty)
            .join(' ');

        if (fullName.isEmpty) {
          fullName = user.displayName ?? 'Utilisateur';
        }

        email = (data['email'] ?? user.email ?? '').toString();
        phone = (data['telephone'] ?? '').toString();
        role = (data['role'] ?? 'Technicien de terrain').toString();
        zone = (data['zone'] ?? '').toString();

        chargementProfil = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => chargementProfil = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de charger le profil.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FC),
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Mon profil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Modifier le profil',
            onPressed: chargementProfil ||
                    enregistrement ||
                    _chargement
                ? null
                : _editProfile,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: chargementProfil
          ? const Center(
              child: CircularProgressIndicator(color: orange),
            )
          : RefreshIndicator(
              onRefresh: chargerProfil,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _headerProfil(),

                  // Statistiques dynamiques depuis Firestore.
                  _statistiquesInterventions(),

                  _sectionTitle('Informations personnelles'),

                  _infoTile(
                    icon: Icons.person_outline,
                    title: 'Nom complet',
                    subtitle: fullName,
                  ),
                  _infoTile(
                    icon: Icons.email_outlined,
                    title: 'Adresse e-mail',
                    subtitle:
                        email.isEmpty ? 'Non renseigné' : email,
                  ),
                  _infoTile(
                    icon: Icons.phone_outlined,
                    title: 'Téléphone',
                    subtitle:
                        phone.isEmpty ? 'Non renseigné' : phone,
                  ),
                  _infoTile(
                    icon: Icons.location_on_outlined,
                    title: 'Zone d’intervention',
                    subtitle:
                        zone.isEmpty ? 'Non renseignée' : zone,
                  ),

                  // Bouton de déconnexion.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        16, 20, 16, 8),
                    child: OutlinedButton.icon(
                      onPressed: _chargement
                          ? null
                          : _confirmLogout,
                      icon: _chargement
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.red,
                              ),
                            )
                          : const Icon(
                              Icons.logout,
                              color: Colors.red,
                            ),
                      label: Text(
                        _chargement
                            ? 'Déconnexion en cours...'
                            : 'Se déconnecter',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize:
                            const Size(double.infinity, 52),
                        side: const BorderSide(
                          color: Colors.redAccent,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),

                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'FieldTask Pro © 2026',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Calculer les statistiques en temps réel depuis Firestore.
  Widget _statistiquesInterventions() {
    final user = _auth.currentUser;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('interventions')
          .where('technicienId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Impossible de charger les statistiques.',
              textAlign: TextAlign.center,
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(color: orange),
            ),
          );
        }

        final interventions = snapshot.data?.docs ?? [];

        final int nombreAssignees = interventions.length;

        final int nombreTerminees = interventions.where((doc) {
          final statut = (doc.data()['statut'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

          return statut == 'terminée' || statut == 'terminee';
        }).length;

        final int nombreEnCours = interventions.where((doc) {
          final statut = (doc.data()['statut'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

          return statut == 'en cours';
        }).length;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _statCard(
                  icon: Icons.assignment_outlined,
                  label: 'Assignées',
                  value: '$nombreAssignees',
                  color: navy,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard(
                  icon: Icons.check_circle_outline,
                  label: 'Terminées',
                  value: '$nombreTerminees',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard(
                  icon: Icons.pending_actions,
                  label: 'En cours',
                  value: '$nombreEnCours',
                  color: orange,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // En-tête du profil.
  Widget _headerProfil() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 30),
      decoration: const BoxDecoration(
        color: navy,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 51,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: lightBlue,
                  child: Text(
                    _initials(fullName),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: navy,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: orange,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.verified_user,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            email,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.engineering,
                  size: 17,
                  color: Color(0xFFFFA347),
                ),
                const SizedBox(width: 7),
                Text(
                  role,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'FT';

    return parts
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: navy,
        ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: lightBlue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: navy),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 15,
        horizontal: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // Modifier et enregistrer les informations dans Firestore.
  Future<void> _editProfile() async {
    final nameController = TextEditingController(text: fullName);
    final phoneController = TextEditingController(text: phone);
    final zoneController = TextEditingController(text: zone);

    try {
      final result = await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Modifier mon profil'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nom complet',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: zoneController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Zone d’intervention',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Annuler'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: navy,
                ),
                onPressed: () {
                  final name = nameController.text.trim();

                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Le nom complet est obligatoire.',
                        ),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(dialogContext, {
                    'name': name,
                    'phone': phoneController.text.trim(),
                    'zone': zoneController.text.trim(),
                  });
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      );

      if (!mounted || result == null) return;

      final user = _auth.currentUser;

      if (user == null) {
        _showMessage(
          'Vous devez être connecté pour modifier le profil.',
        );
        return;
      }

      final nameParts = result['name']!
          .trim()
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .toList();

      final prenom = nameParts.first;
      final nom = nameParts.skip(1).join(' ');

      setState(() => enregistrement = true);

      await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .set({
        'prenom': prenom,
        'nom': nom,
        'email': user.email ?? email,
        'telephone': result['phone']!,
        'zone': result['zone']!,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() {
        fullName = result['name']!;
        phone = result['phone']!;
        zone = result['zone']!;
        email = user.email ?? email;
        enregistrement = false;
      });

      _showMessage('Profil enregistré avec succès.');
    } catch (e) {
      if (!mounted) return;

      setState(() => enregistrement = false);
      _showMessage(
        'Erreur lors de l’enregistrement du profil.',
      );
    } finally {
      nameController.dispose();
      phoneController.dispose();
      zoneController.dispose();
    }
  }

  // Réinitialisation du mot de passe par e-mail.
  Future<void> _gestionMotDePasse() async {
    final user = _auth.currentUser;

    if (user?.email == null) {
      _showMessage(
        'Aucune adresse e-mail associée au compte.',
      );
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(
        email: user!.email!,
      );

      if (!mounted) return;

      _showMessage(
        'Un lien de réinitialisation a été envoyé '
        'à ${user.email}.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Impossible d’envoyer le lien de réinitialisation.',
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Confirmer puis déconnecter l'utilisateur.
  Future<void> _confirmLogout() async {
    if (_chargement) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Déconnexion'),
          content: const Text(
            'Voulez-vous vraiment vous déconnecter ?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Déconnecter'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _chargement = true);

    try {
      await _auth.signOut();

      if (!mounted) return;

      if (widget.onLogout != null) {
        widget.onLogout!();
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => PageConexion(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Erreur lors de la déconnexion. Veuillez réessayer.',
      );
    } finally {
      if (mounted) {
        setState(() => _chargement = false);
      }
    }
  }
}
