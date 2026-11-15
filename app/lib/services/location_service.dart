import 'package:geolocator/geolocator.dart';

class LatLon {
  const LatLon(this.lat, this.lon);

  final double lat;
  final double lon;
}

/// Ubicación aproximada para "Usar mi ubicación". Devuelve `null` si no hay
/// permiso, el GPS está apagado o tarda demasiado (la app cae a Huánuco).
class LocationService {
  static const _timeout = Duration(seconds: 12);

  Future<LatLon?> current() async {
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
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          // La celda es de ~50 km: no hace falta precisión fina.
          accuracy: LocationAccuracy.low,
          timeLimit: _timeout,
        ),
      );
      return LatLon(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }
}
