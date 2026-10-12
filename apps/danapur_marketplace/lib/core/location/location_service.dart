import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../domain/market.dart';
import '../theme/app_theme.dart';
import '../../features/orders/domain/commerce.dart';

Future<GeoFix> currentLocation({
  BuildContext? context,
  String purpose =
      'verify if your delivery address is within the 500-metre shop delivery radius for cash on delivery',
}) async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const MarketException(
      'Turn on device location, or choose shop pickup.',
    );
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    if (context != null && context.mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.location_on_outlined, color: green),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Location Permission',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              'Danapur Bazaar accesses your device location in the foreground to $purpose.\n\n'
              '• Used only when you tap this button\n'
              '• Never tracked in the background\n'
              '• Not shared with advertisers or third parties\n\n'
              'If you prefer not to share location, you can choose shop pickup instead.',
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel / Pickup'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (proceed != true) {
        throw const MarketException(
          'Location permission was cancelled. You can choose shop pickup instead.',
        );
      }
    }
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
