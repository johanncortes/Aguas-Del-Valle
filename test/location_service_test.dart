import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:aguas_monte_patria/services/location_service.dart';

Position _position(double lat, double lng, {DateTime? at}) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: at ?? DateTime.now(),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

class _FakeGeolocator extends GeolocatorPlatform {
  _FakeGeolocator({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.permissionAfterRequest,
    this.current,
    this.lastKnown,
  });

  final bool serviceEnabled;
  LocationPermission permission;
  final LocationPermission? permissionAfterRequest;

  /// Null makes getCurrentPosition time out.
  final Position? current;
  final Position? lastKnown;
  int permissionRequests = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return permission = permissionAfterRequest ?? permission;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    if (current == null) throw Exception('sin señal GPS (timeout)');
    return Future.value(current);
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async =>
      lastKnown;
}

Future<DevicePosition?> _positionWith(_FakeGeolocator fake) {
  GeolocatorPlatform.instance = fake;
  return const LocationService().currentPosition();
}

void main() {
  test('returns the current position when everything is available',
      () async {
    final position = await _positionWith(
        _FakeGeolocator(current: _position(-30.7296, -70.7644)));

    expect(position?.latitude, -30.7296);
    expect(position?.longitude, -70.7644);
  });

  test('asks for permission once and uses it when granted', () async {
    final fake = _FakeGeolocator(
      permission: LocationPermission.denied,
      permissionAfterRequest: LocationPermission.whileInUse,
      current: _position(-30.7, -70.7),
    );

    expect(await _positionWith(fake), isNotNull);
    expect(fake.permissionRequests, 1);
  });

  test('returns null when the permission is denied', () async {
    final fake = _FakeGeolocator(
      permission: LocationPermission.denied,
      permissionAfterRequest: LocationPermission.denied,
      current: _position(-30.7, -70.7),
    );

    expect(await _positionWith(fake), isNull);
  });

  test('returns null without asking when denied forever', () async {
    final fake = _FakeGeolocator(
      permission: LocationPermission.deniedForever,
      current: _position(-30.7, -70.7),
    );

    expect(await _positionWith(fake), isNull);
    expect(fake.permissionRequests, 0);
  });

  test('returns null when location services are off', () async {
    expect(
      await _positionWith(_FakeGeolocator(
        serviceEnabled: false,
        current: _position(-30.7, -70.7),
      )),
      isNull,
    );
  });

  test('falls back to a recent last known position without a fix',
      () async {
    final position = await _positionWith(_FakeGeolocator(
      lastKnown: _position(-30.71, -70.71,
          at: DateTime.now().subtract(const Duration(seconds: 30))),
    ));

    expect(position?.latitude, -30.71);
  });

  test('ignores a stale last known position', () async {
    final position = await _positionWith(_FakeGeolocator(
      lastKnown: _position(-30.71, -70.71,
          at: DateTime.now().subtract(const Duration(hours: 1))),
    ));

    expect(position, isNull);
  });
}
