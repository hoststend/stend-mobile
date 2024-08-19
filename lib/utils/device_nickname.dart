import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

Future getDeviceNickname() async {
  var deviceInfo = DeviceInfoPlugin();
  String nickname = 'Appareil anonyme';

  if(Platform.isAndroid) {
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    nickname = androidInfo.model;
    if (nickname.length < 6) { // rajouter la marque si le nom est trop court
      String brand = androidInfo.brand;
      brand = brand[0].toUpperCase() + brand.substring(1);
      nickname = "$brand $nickname";
    }
  } else if(Platform.isIOS) {
    IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
    nickname = iosInfo.name.length > 2 ? iosInfo.name : iosInfo.utsname.machine;

    if (nickname.startsWith('iPad ')) {
      String unpreciseModel = nickname.split(' (')[0]; // retirer les infos complète (ex: iPad Pro (12.9-inch) (3rd generation))
      if (unpreciseModel.length > 5) nickname = unpreciseModel;
    }
  } else if(Platform.isMacOS) {
    MacOsDeviceInfo macInfo = await deviceInfo.macOsInfo;
    nickname = macInfo.computerName.length > 2 ? macInfo.computerName : macInfo.model;
  } else {
    nickname = Platform.operatingSystem;
  }

  return nickname;
}