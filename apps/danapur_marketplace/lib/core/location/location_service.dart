import 'package:geolocator/geolocator.dart';
import '../domain/market.dart';
import '../../features/orders/domain/commerce.dart';

Future<GeoFix> currentLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const MarketException(
      'Turn on device location, or choose shop pickup.',
    );
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw const MarketException(
      'Location access is unavailable. Allow precise location in device/browser settings, or choose pickup.',
    );
  }
  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 20),
    ),
  );
  if (position.isMocked) {
    throw const MarketException(
      'Mock location cannot be used for live delivery. Choose pickup.',
    );
  }
  final fix = GeoFix(
    position.latitude,
    position.longitude,
    accuracy: position.accuracy,
    measuredAt: position.timestamp,
  );
  if (!fix.valid) {
    throw const MarketException(
      'Location is too imprecise or old. Retry outdoors, or choose shop pickup.',
    );
  }
  return fix;
}
