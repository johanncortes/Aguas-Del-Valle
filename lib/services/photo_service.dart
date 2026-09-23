import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Takes evidence photos with the camera and keeps them in app storage.
class PhotoService {
  PhotoService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Folder (inside the app documents directory) holding evidence photos.
  static const folderName = 'evidence_photos';

  /// Opens the camera and returns the path of the stored photo, or null
  /// if the reader cancels. The picker's file lives in a temporary folder
  /// the OS may clear, so it is copied to the documents directory.
  /// Photos are downscaled and compressed to keep storage low on a full
  /// month of visits.
  Future<String?> takePhoto(String clientId) async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 70,
    );
    if (picked == null) return null;

    final documents = await getApplicationDocumentsDirectory();
    final folder = Directory('${documents.path}/$folderName');
    await folder.create(recursive: true);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final dot = picked.path.lastIndexOf('.');
    final extension = dot >= 0 ? picked.path.substring(dot) : '.jpg';
    final target = '${folder.path}/${clientId}_$timestamp$extension';
    await picked.saveTo(target);
    return target;
  }

  /// Deletes a stored photo; missing files are ignored.
  Future<void> deletePhoto(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // A leftover file is harmless; never fail the caller over it.
    }
  }
}
