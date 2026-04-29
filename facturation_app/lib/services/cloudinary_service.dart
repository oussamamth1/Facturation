import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const _cloudName = 'dwgfvs9jp';
  static const _apiKey = 'ZEsJvGOR70iDIzvayPOjNotY8KY';
  // Create an unsigned upload preset in:
  // Cloudinary Dashboard → Settings → Upload → Upload presets → Add preset
  // Set signing mode to "Unsigned" and copy the preset name here.
  static const _uploadPreset = 'facturation_unsigned';

  static const _baseUrl =
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  /// Uploads [bytes] to Cloudinary and returns the secure URL.
  /// [folder] organises images inside your Cloudinary media library.
  Future<String> uploadImage(
    Uint8List bytes, {
    String folder = 'app',
    String filename = 'image.jpg',
  }) async {
    final uri = Uri.parse(_baseUrl);
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['api_key'] = _apiKey
      ..fields['folder'] = folder
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: '${DateTime.now().millisecondsSinceEpoch}_$filename',
        ),
      );

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode == 200) {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['secure_url'] as String;
    }
    final err = jsonDecode(body) as Map<String, dynamic>;
    throw Exception(
      err['error']?['message'] ?? 'Upload failed (${streamed.statusCode})',
    );
  }

  /// Deletes an image by its public_id (extracted from the URL).
  static String publicIdFromUrl(String url) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;
    // Remove version segment (v12345) and file extension
    final upload = segments.indexOf('upload');
    if (upload == -1) return '';
    final parts = segments.sublist(upload + 1);
    if (parts.isNotEmpty && parts.first.startsWith('v')) parts.removeAt(0);
    final last = parts.last;
    final dot = last.lastIndexOf('.');
    parts[parts.length - 1] = dot != -1 ? last.substring(0, dot) : last;
    return parts.join('/');
  }
}

final cloudinaryService = CloudinaryService();
