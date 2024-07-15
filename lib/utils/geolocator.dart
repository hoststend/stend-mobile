import 'package:geolocator/geolocator.dart';

Future checkLocationPermission() async {
  // Test if location services are enabled.
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return "Les services de localisations ne sont pas activés";

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return "Nous n'avons pas la permission d'accéder à votre position, vérifier vos réglages"; // permission refusé, mais on peut redemander
  }

  if (permission == LocationPermission.deniedForever) return "Nous n'avons pas la permission d'accéder à votre position, vérifier vos réglages"; // permission refusé définitevement

  return true;
}

Future<Position> getCurrentPosition() async {
  try {
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 10));
  } catch (e) {
    rethrow;
  }
}