import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = 'jfilpioq';
  static const String uploadPreset = 'monimage';

  Future<String> envoyerPhoto(File photo) async {
    // Vérifier que le fichier existe.
    if (!await photo.exists()) {
      throw Exception('Le fichier photo est introuvable.');
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    try {
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(
          await http.MultipartFile.fromPath('file', photo.path),
        );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );

      final response = await http.Response.fromStream(streamedResponse);

      Map<String, dynamic> data;

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Réponse JSON invalide.');
        }

        data = decoded;
      } on FormatException {
        throw Exception(
          'Cloudinary a retourné une réponse invalide.',
        );
      }

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        final error = data['error'];
        final message = error is Map
            ? error['message']?.toString()
            : null;

        throw Exception(
          message ?? 'Échec du téléversement de la photo.',
        );
      }

      final photoUrl = data['secure_url'];

      if (photoUrl is! String || photoUrl.isEmpty) {
        throw Exception(
          'Cloudinary n’a retourné aucune URL sécurisée.',
        );
      }

      return photoUrl;
    } on SocketException {
      throw Exception(
        'Aucune connexion Internet. Vérifie ton réseau.',
      );
    } on HttpException {
      throw Exception(
        'Erreur réseau lors de l’envoi de la photo.',
      );
    } on FormatException {
      throw Exception(
        'Impossible de lire la réponse de Cloudinary.',
      );
    } on Exception {
      rethrow;
    }
  }
}
