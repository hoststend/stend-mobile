import 'dart:convert';

import 'package:stendmobile/utils/globals.dart' as globals;
import 'package:get_storage/get_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

final box = GetStorage();

void openAuthGoogle({String responseType = 'redirect'}) {
  launchUrl(Uri.parse('https://globalstend.johanstick.fr/auth/google/login?responseType=$responseType'), mode: LaunchMode.inAppBrowserView);
}

Future checkcodeAuth(String code) async {
  http.Response response = await http.get(Uri.parse("https://globalstend.johanstick.fr/auth/checkcode?code=$code"));
  final Map<String, dynamic> responseJson = json.decode(utf8.decode(response.bodyBytes));

  if (responseJson['success'] != true) {
    return responseJson['message'] ?? response;
  }

  box.write('exposeMethods_account', true);
  box.write('exposeAccountToken', responseJson['token']);

  globals.intereventsStreamController.add({'type': 'settings', 'action': 'enableExposeAccountToggle' });
  return true;
}