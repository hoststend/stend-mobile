

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';

final box = GetStorage();
bool spoofInternetAccess = box.read('spoofInternetAccess') ?? false;

Future<bool> checkConnectivity() async {
  final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());
  debugPrint(connectivityResult.toString());

  if (spoofInternetAccess) return true;

  if (connectivityResult.contains(ConnectivityResult.mobile) || connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.ethernet)) {
    return true;
  }

  return false;
}