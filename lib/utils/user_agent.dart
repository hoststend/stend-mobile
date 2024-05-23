import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

var _deviceUserAgent = '';

Future deviceUserAgent() async {
  if (_deviceUserAgent.isNotEmpty) return _deviceUserAgent;
  var deviceInfo = DeviceInfoPlugin();
  PackageInfo packageInfo = await PackageInfo.fromPlatform();

  var appVersion = packageInfo.version;
  var osVersion = Platform.isAndroid ? (await deviceInfo.androidInfo).version.release : Platform.isIOS ? (await deviceInfo.iosInfo).systemVersion : 'Unsupported';
  var osName = Platform.operatingSystem;

  switch (osName) {
    case 'android':
      osName = 'Android';
    case 'ios':
      osName = 'iOS';
    default:
      osName = osName;
  }

  _deviceUserAgent = 'StendMobile/$appVersion (Flutter ; $osName $osVersion)';
  return _deviceUserAgent;
}