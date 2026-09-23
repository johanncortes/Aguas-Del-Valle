import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:aguas_monte_patria/services/photo_service.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class _FakeImagePicker extends ImagePickerPlatform {
  _FakeImagePicker(this.result);

  /// File the "camera" returns; null = the reader cancelled.
  final XFile? result;
  ImageSource? source;
  ImagePickerOptions? options;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    this.source = source;
    this.options = options;
    return result;
  }
}

void main() {
  late Directory temp;
  late Directory documents;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('photo_test');
    documents = await Directory('${temp.path}/documents').create();
    PathProviderPlatform.instance = _FakePathProvider(documents.path);
  });

  tearDown(() => temp.delete(recursive: true));

  test('stores the camera photo in the documents folder', () async {
    final cameraFile = File('${temp.path}/cache/IMG_0001.jpg');
    await cameraFile.create(recursive: true);
    await cameraFile.writeAsBytes([1, 2, 3]);
    final picker = _FakeImagePicker(XFile(cameraFile.path));
    ImagePickerPlatform.instance = picker;

    final path = await PhotoService().takePhoto('sp-001');

    expect(picker.source, ImageSource.camera);
    expect(picker.options?.imageQuality, 70);
    expect(picker.options?.maxWidth, 1600);
    expect(path, startsWith('${documents.path}/evidence_photos/sp-001_'));
    expect(path, endsWith('.jpg'));
    expect(await File(path!).readAsBytes(), [1, 2, 3]);
  });

  test('returns null when the reader cancels the camera', () async {
    ImagePickerPlatform.instance = _FakeImagePicker(null);
    expect(await PhotoService().takePhoto('sp-001'), isNull);
  });

  test('deletePhoto removes the file and ignores missing ones', () async {
    final file = File('${temp.path}/photo.jpg');
    await file.writeAsBytes([1]);

    await PhotoService().deletePhoto(file.path);
    expect(await file.exists(), isFalse);

    await PhotoService().deletePhoto(file.path); // no throw
  });
}
