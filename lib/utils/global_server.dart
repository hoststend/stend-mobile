import 'dart:convert';

import 'package:stendmobile/utils/globals.dart' as globals;
import 'package:get_storage/get_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

final box = GetStorage();

void openAuthGoogle({String responseType = 'redirect'}) {
  launchUrl(Uri.parse('https://globalstend.johanstick.fr/auth/google/login?responseType=$responseType'), mode: LaunchMode.inAppBrowserView);
}

void logout({ bool refreshSettings = true }) {
  box.remove('exposeMethods_account');
  box.remove('exposeAccountToken');
  box.remove('exposeAccountId');
  if(refreshSettings) globals.intereventsStreamController.add({'type': 'settings', 'action': 'refreshSettings' });
}

Future checkcodeAuth(String code) async {
  http.Response checkcode = await http.get(Uri.parse("https://globalstend.johanstick.fr/auth/checkcode?code=$code"));
  final Map<String, dynamic> checkcodeJson = json.decode(utf8.decode(checkcode.bodyBytes));

  if (checkcodeJson['success'] != true) {
    return checkcodeJson['message'] ?? checkcode;
  }

  var token = checkcodeJson['token'];
  if (token is! String) {
    return "Le token retourné par l'API est invalide";
  }

  box.write('exposeMethods_account', true);
  box.write('exposeAccountToken', token);

  http.Response checktransferts = await http.get(Uri.parse("https://globalstend.johanstick.fr/account/transferts"), headers: {'Authorization': token});
  final Map<String, dynamic> checktransfertsJson = json.decode(utf8.decode(checktransferts.bodyBytes));

  if (checktransfertsJson['success'] != true) {
    return checktransfertsJson['message'] ?? checktransferts;
  }

  box.write('exposeAccountId', checktransfertsJson['userId']);
  globals.intereventsStreamController.add({'type': 'settings', 'action': 'refreshSettings' });

  return true;
}

Future resetToken() async {}
Future deleteAccount() async {}