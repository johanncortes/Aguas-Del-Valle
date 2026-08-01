import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:aguas_monte_patria/services/cached_tile_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CachedTileProvider', () {
    test('getImage returns ImageProvider without null assertion crash', () {
      final provider = CachedTileProvider();
      final coordinates = const TileCoordinates(1, 2, 3);
      final options = TileLayer(urlTemplate: 'https://example.com/{z}/{x}/{y}.png');

      expect(() => provider.getImage(coordinates, options), returnsNormally);

      final imageProvider = provider.getImage(coordinates, options);
      expect(imageProvider, isA<CachedNetworkTileImage>());
    });

    test('getImage handles null or empty urlTemplate without null assertion crash', () {
      final provider = CachedTileProvider();
      final coordinates = const TileCoordinates(0, 0, 0);
      final options = TileLayer(urlTemplate: null);

      expect(() => provider.getImage(coordinates, options), returnsNormally);

      final imageProvider = provider.getImage(coordinates, options) as CachedNetworkTileImage;
      expect(imageProvider.url, isEmpty);
    });

    test('tilePath returns null before directory is initialized without crashing', () {
      expect(() => CachedTileProvider.tilePath(1, 1, 1), returnsNormally);
    });
  });
}
