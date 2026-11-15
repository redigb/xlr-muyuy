import 'dart:async';

import 'package:geolocator/geolocator.dart';

class LatLon {
  const LatLon(this.lat, this.lon);

  final double lat;
  final double lon;
}

/// Por qué no se obtuvo la ubicación (para un mensaje claro al usuario).
enum LocationIssue { serviceOff, denied, timeout }

/// Posición o el motivo por el que no la hay.
class LocationResult {
  const LocationResult.ok(LatLon this.position) : issue = null;
  const LocationResult.fail(LocationIssue this.issue) : position = null;

  final LatLon? position;
  final LocationIssue? issue;
}

/// Ubicación aproximada para "Usar mi ubicación". La celda es de ~50 km, así
/// que sirve la última posición conocida si la actual tarda en llegar.
class LocationService {
  static const _timeout = Duration(seconds: 20);

  Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.fail(LocationIssue.serviceOff);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const LocationResult.fail(LocationIssue.denied);
      }

      final last = await _lastKnown();
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: _timeout,
          ),
        );
        return LocationResult.ok(LatLon(position.latitude, position.longitude));
      } catch (_) {
        // Sin fix a tiempo (interior, proveedor de red apagado): última conocida.
        if (last != null) return LocationResult.ok(last);
        return const LocationResult.fail(LocationIssue.timeout);
      }
    } catch (_) {
      return const LocationResult.fail(LocationIssue.timeout);
    }
  }

  Future<LatLon?> _lastKnown() async {
    try {
      final p = await Geolocator.getLastKnownPosition();
      return p == null ? null : LatLon(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }
}
