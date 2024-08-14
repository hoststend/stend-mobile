import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stendmobile/utils/haptic.dart';
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

Future resetToken({ bool hapticFeedback = false }) async {
  if (hapticFeedback) Haptic().light();

  http.Response resetToken = await http.post(Uri.parse("https://globalstend.johanstick.fr/account/reset"), headers: {'Authorization': box.read('exposeAccountToken')});
  final Map<String, dynamic> resetTokenJson = json.decode(utf8.decode(resetToken.bodyBytes));

  if (resetTokenJson['success'] != true) {
    if (hapticFeedback) Haptic().error();
    return { 'icon': 'error', 'value': resetTokenJson['message'] ?? resetToken };
  }

  if (resetTokenJson['token'] is! String) {
    debugPrint(resetToken.body.toString());
    if (hapticFeedback) Haptic().error();
    return { 'icon': 'error', 'value': "Le token retourné par l'API est invalide" };
  }

  String token = resetTokenJson['token'];
  box.write('exposeMethods_account', true);
  box.write('exposeAccountToken', token);

  http.Response checktransferts = await http.get(Uri.parse("https://globalstend.johanstick.fr/account/transferts"), headers: {'Authorization': token});
  final Map<String, dynamic> checktransfertsJson = json.decode(utf8.decode(checktransferts.bodyBytes));

  if (checktransfertsJson['success'] != true) {
    if (hapticFeedback) Haptic().error();
    return { 'icon': 'error', 'value': checktransfertsJson['message'] ?? checktransferts };
  }

  box.write('exposeAccountId', checktransfertsJson['userId']);
  globals.intereventsStreamController.add({'type': 'settings', 'action': 'refreshSettings' });

  if (hapticFeedback) Haptic().success();
  return { 'icon': 'success', 'value': "Cette session a été renouvelée, vos autres appareils ont été déconnectés" };
}

Future deleteAccount({ bool hapticFeedback = false }) async {
  if (hapticFeedback) Haptic().light();

  http.Response deleteAccount = await http.post(Uri.parse("https://globalstend.johanstick.fr/account/delete"), headers: {'Authorization': box.read('exposeAccountToken')});
  final Map<String, dynamic> deleteAccountJson = json.decode(utf8.decode(deleteAccount.bodyBytes));

  debugPrint(deleteAccount.body.toString());
  if (deleteAccountJson['success'] != true) {
    if (hapticFeedback) Haptic().error();
    return { 'icon': 'error', 'value': deleteAccountJson['message'] ?? deleteAccount };
  }

  logout(refreshSettings: true);
  if (hapticFeedback) Haptic().success();
  return { 'icon': 'success', 'value': "Votre compte a été supprimé, les données associées seront supprimées dans l'heure" };
}