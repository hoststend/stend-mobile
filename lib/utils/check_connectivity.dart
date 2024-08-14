

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

Future<bool> checkConnectivity() async {
  final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());
  debugPrint(connectivityResult.toString());

  if (connectivityResult.contains(ConnectivityResult.mobile) || connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.ethernet)) {
    return true;
  }

  return false;
}