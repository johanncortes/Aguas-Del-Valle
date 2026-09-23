import 'package:geolocator/geolocator.dart';

/// Device position at a point in time.
typedef DevicePosition = ({double latitude, double longitude});

/// Gets the device position for the GPS audit of each visit.
///
/// Never throws and never blocks the reader for long: when permission is
/// denied, location services are off or no fix arrives in time, it
/// returns null and the visit is saved without coordinates.
class LocationService {
  const LocationService();

  /// Maximum wait for a fresh fix before falling back.
  static const _fixTimeout = Duration(seconds: 8);

  /// A last known position older than this is not used: it could place
  /// the reader somewhere they no longer are.
  static const _maxLastKnownAge = Duration(minutes: 2);

  Future<DevicePosition?> currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: _fixTimeout,
          ),
        );
        return (latitude: position.latitude, longitude: position.longitude);
      } catch (_) {
        // No fresh fix in time (e.g. inside a building): use a recent
        // last known position if there is one.
        final last = await Geolocator.getLastKnownPosition();
        if (last != null &&
            DateTime.now().difference(last.timestamp) <= _maxLastKnownAge) {
          return (latitude: last.latitude, longitude: last.longitude);
        }
        return null;
      }
    } catch (_) {
      return null;
    }
  }
}
