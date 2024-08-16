import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stendmobile/utils/haptic.dart';
import 'package:stendmobile/utils/device_nickname.dart';
import 'package:stendmobile/utils/globals.dart' as globals;
import 'package:get_storage/get_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

final box = GetStorage();
String baseUrl = box.read('globalserverInstanceUrl') ?? 'https://globalstend.johanstick.fr/';
String deviceNickname = '';

void openAuthGoogle({String responseType = 'redirect'}) {
  launchUrl(Uri.parse('${baseUrl}auth/google/login?responseType=$responseType'), mode: LaunchMode.inAppBrowserView);
}

void logout({ bool refreshSettings = true }) {
  box.remove('exposeMethods_account');
  box.remove('exposeAccountToken');
  box.remove('exposeAccountId');
  if(refreshSettings) globals.intereventsStreamController.add({'type': 'settings', 'action': 'refreshSettings' });
}

Future checkcodeAuth(String code) async {
  http.Response checkcode = await http.get(Uri.parse("${baseUrl}auth/checkcode?code=$code"));
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

  http.Response checktransferts = await http.get(Uri.parse("${baseUrl}account/transferts"), headers: {'Authorization': token});
  final Map<String, dynamic> checktransfertsJson = json.decode(utf8.decode(checktransferts.bodyBytes));

  if (checktransfertsJson['success'] != true) {
    return checktransfertsJson['message'] ?? checktransferts;
  }

  box.write('exposeAccountId', checktransfertsJson['userId']);
  globals.intereventsStreamController.add({'type': 'settings', 'action': 'refreshSettings' });

  return true;
}

Future getAccount() async {
  String token = box.read('exposeAccountToken') ?? '';
  if (token.isEmpty) {
    return { 'success': false, 'value': "Vous n'êtes pas connecté" };
  }

  http.Response checkaccount = await http.get(Uri.parse("${baseUrl}account/details"), headers: {'Authorization': token});
  final Map<String, dynamic> checkaccountJson = json.decode(utf8.decode(checkaccount.bodyBytes));

  if (checkaccountJson['success'] != true) {
    return { 'success': false, 'value': checkaccountJson['message'] ?? checkaccount };
  }

  return checkaccountJson;
}

Future getTransferts() async {
  String token = box.read('exposeAccountToken') ?? '';
  if (token.isEmpty) {
    return { 'success': false, 'value': "Vous n'êtes pas connecté" };
  }

  http.Response checktransferts = await http.get(Uri.parse("${baseUrl}account/transferts"), headers: {'Authorization': token});
  final Map<String, dynamic> checktransfertsJson = json.decode(utf8.decode(checktransferts.bodyBytes));

  if (checktransfertsJson['success'] != true) {
    return { 'success': false, 'value': checktransfertsJson['message'] ?? checktransferts };
  }

  return checktransfertsJson;
}

Future createTransfert({ String fileName = 'Sans nom', String webUrl = '', String apiInstanceUrl = '', String latitude = '', String longitude = '', Map exposeMethods = const {} }) async {
  // Ignorer l'URL de l'API si on a désactivé cette méthode d'exposition
  if (exposeMethods['exposeMethods_ipinstance'] != true) apiInstanceUrl = '';

  // Récupérer le surnom de l'appareil si on ne l'a pas déjà
  if (deviceNickname.isEmpty) deviceNickname = await getDeviceNickname();

  // Créer le transfert exposé
  http.Response createTransfert = await http.post(Uri.parse("${baseUrl}transferts/create"), headers: {'Authorization': exposeMethods['exposeAccountToken']}, body: {
    'fileName': fileName,
    'webUrl': webUrl,
    'nickname': deviceNickname,
    'latitude': latitude,
    'longitude': longitude,
    'apiUrl': apiInstanceUrl
  });

  final Map<String, dynamic> createTransfertJson = json.decode(utf8.decode(createTransfert.bodyBytes));

  if (createTransfertJson['success'] != true) {
    return { 'success': false, 'value': createTransfertJson['message'] ?? createTransfert };
  } else {
    return createTransfertJson;
  }
}

Future resetToken({ bool hapticFeedback = false }) async {
  if (hapticFeedback) Haptic().light();

  http.Response resetToken = await http.post(Uri.parse("${baseUrl}account/reset"), headers: {'Authorization': box.read('exposeAccountToken')});
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

  http.Response checkaccount = await http.get(Uri.parse("${baseUrl}account/details"), headers: {'Authorization': token});
  final Map<String, dynamic> checkaccountJson = json.decode(utf8.decode(checkaccount.bodyBytes));

  if (checkaccountJson['success'] != true) {
    if (hapticFeedback) Haptic().error();
    return { 'icon': 'error', 'value': checkaccountJson['message'] ?? checkaccount };
  }

  box.write('exposeAccountId', checkaccountJson['userId']);
  globals.intereventsStreamController.add({'type': 'settings', 'action': 'refreshSettings' });

  if (hapticFeedback) Haptic().success();
  return { 'icon': 'success', 'value': "Cette session a été renouvelée, vos autres appareils ont été déconnectés" };
}

Future deleteAccount({ bool hapticFeedback = false }) async {
  if (hapticFeedback) Haptic().light();

  http.Response deleteAccount = await http.post(Uri.parse("${baseUrl}account/delete"), headers: {'Authorization': box.read('exposeAccountToken')});
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