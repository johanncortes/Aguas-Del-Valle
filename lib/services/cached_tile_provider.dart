import 'dart:io';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path_provider/path_provider.dart';

/// Custom TileProvider that caches tiles to local filesystem for offline use.
///
/// Refactored to eliminate all null-assertion (!) operators and safely fall back
/// to transparent placeholder tiles when network or filesystem failures occur.
class CachedTileProvider extends TileProvider {
  static Dio? _dio;
  static String? _cacheDir;
  static bool _isInitializing = false;

  /// Initialize the cache directory and Dio client safely
  static Future<void> initialize() => ensureInitialized();

  /// Ensure the cache directory and Dio client are initialized
  static Future<void> ensureInitialized() async {
    if (_dio != null && _cacheDir != null) return;
    if (_isInitializing) {
      while (_isInitializing && (_dio == null || _cacheDir == null)) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return;
    }
    _isInitializing = true;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = '${appDir.path}/map_tile_cache';
      final dirPath = _cacheDir;
      if (dirPath != null) {
        final dir = Directory(dirPath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      }

      _dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        responseType: ResponseType.bytes,
        headers: {
          'User-Agent': 'com.aguasdelvalle.aguas_monte_patria',
        },
      ));
    } catch (_) {
      // Gracefully handle filesystem or Dio initialization failure
    } finally {
      _isInitializing = false;
    }
  }

  /// Get the path for a cached tile safely
  static String? tilePath(int z, int x, int y) {
    final dir = _cacheDir;
    if (dir == null || dir.isEmpty) return null;
    return '$dir/$z/$x/$y.png';
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final z = coordinates.z.toInt();
    final x = coordinates.x.toInt();
    final y = coordinates.y.toInt();

    // Safely resolve URL without null assertion operator
    final urlTemplate = options.urlTemplate;
    final url = (urlTemplate != null && urlTemplate.isNotEmpty)
        ? urlTemplate
            .replaceAll('{z}', '$z')
            .replaceAll('{x}', '$x')
            .replaceAll('{y}', '$y')
        : '';

    // Trigger async initialization if not already done
    ensureInitialized();

    return CachedNetworkTileImage(
      url: url,
      coordinates: coordinates,
    );
  }

  /// Get approximate cache size in MB safely
  static Future<double> getCacheSizeMB() async {
    final dirPath = _cacheDir;
    if (dirPath == null) return 0.0;
    final dir = Directory(dirPath);
    if (!await dir.exists()) return 0.0;

    int totalBytes = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        totalBytes += await entity.length();
      }
    }
    return totalBytes / (1024 * 1024);
  }

  /// Clear the tile cache safely
  static Future<void> clearCache() async {
    final dirPath = _cacheDir;
    if (dirPath == null) return;
    final dir = Directory(dirPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      await dir.create(recursive: true);
    }
  }
}

/// ImageProvider that downloads a tile, caches it, and then provides the image.
/// Automatically returns a transparent fallback tile if loading fails.
class CachedNetworkTileImage extends ImageProvider<CachedNetworkTileImage> {
  final String url;
  final TileCoordinates coordinates;

  CachedNetworkTileImage({
    required this.url,
    required this.coordinates,
  });

  // A valid 1x1 transparent PNG fallback buffer
  static final Uint8List _transparentPng = Uint8List.fromList(<int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  @override
  ImageStreamCompleter loadImage(
    CachedNetworkTileImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<CachedNetworkTileImage>('Tile', key),
      ],
    );
  }

  Future<Codec> _loadAsync(
    CachedNetworkTileImage key,
    ImageDecoderCallback decode,
  ) async {
    try {
      await CachedTileProvider.ensureInitialized();

      final z = key.coordinates.z.toInt();
      final x = key.coordinates.x.toInt();
      final y = key.coordinates.y.toInt();
      final cachePath = CachedTileProvider.tilePath(z, x, y);

      // 1. Try serving from local disk cache first
      if (cachePath != null) {
        final cachedFile = File(cachePath);
        if (cachedFile.existsSync()) {
          final bytes = await cachedFile.readAsBytes();
          if (bytes.isNotEmpty) {
            final buffer = await ImmutableBuffer.fromUint8List(bytes);
            return await decode(buffer);
          }
        }
      }

      // 2. Try fetching from network via Dio if available
      if (key.url.isNotEmpty) {
        final dio = CachedTileProvider._dio;
        if (dio != null) {
          final response = await dio.get<List<int>>(key.url);
          final data = response.data;
          if (data != null && data.isNotEmpty) {
            final bytes = Uint8List.fromList(data);
            if (cachePath != null) {
              _saveToDisk(cachePath, bytes);
            }
            final buffer = await ImmutableBuffer.fromUint8List(bytes);
            return await decode(buffer);
          }
        }
      }

      // 3. Fallback to transparent tile
      return await _decodeTransparentImage(decode);
    } catch (e) {
      // If network fetch failed, attempt disk read once more as fallback
      try {
        final z = key.coordinates.z.toInt();
        final x = key.coordinates.x.toInt();
        final y = key.coordinates.y.toInt();
        final cachePath = CachedTileProvider.tilePath(z, x, y);
        if (cachePath != null) {
          final cachedFile = File(cachePath);
          if (cachedFile.existsSync()) {
            final bytes = await cachedFile.readAsBytes();
            if (bytes.isNotEmpty) {
              final buffer = await ImmutableBuffer.fromUint8List(bytes);
              return await decode(buffer);
            }
          }
        }
      } catch (_) {}

      // Gracefully return transparent tile instead of throwing an exception
      return await _decodeTransparentImage(decode);
    }
  }

  void _saveToDisk(String cachePath, Uint8List bytes) {
    try {
      final file = File(cachePath);
      file.parent.create(recursive: true).then((_) {
        file.writeAsBytes(bytes, flush: true);
      }).catchError((_) {});
    } catch (_) {}
  }

  Future<Codec> _decodeTransparentImage(ImageDecoderCallback decode) async {
    final buffer = await ImmutableBuffer.fromUint8List(_transparentPng);
    return await decode(buffer);
  }

  @override
  Future<CachedNetworkTileImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CachedNetworkTileImage &&
        other.url == url &&
        other.coordinates == coordinates;
  }

  @override
  int get hashCode => Object.hash(url, coordinates);

  @override
  String toString() => 'CachedNetworkTileImage(url: $url, coords: $coordinates)';
}
