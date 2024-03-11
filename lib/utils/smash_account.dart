import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';

final box = GetStorage();

createSmashAccount() async {
  // Créer un nouveau compte
  http.Response accountInfo = await http.post(Uri.parse("https://iam.eu-west-3.fromsmash.co/account"),
    body: '{}',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    }
  );
  final Map<String, dynamic> accountInfoJson = json.decode(utf8.decode(accountInfo.bodyBytes));

  // Vérifier si y'a une erreur
  if (accountInfoJson.containsKey('message') || accountInfoJson.containsKey('error')) return 'err_${accountInfoJson['message'] ?? accountInfoJson['error']}';

  // Récupérer le token et sa date d'expiration
  String token = accountInfoJson['account']['token']['type'] + ' ' + accountInfoJson['account']['token']['token'];
  String tokenExpiration = accountInfoJson['account']['token']['expiration'];

  // Enregistrer les deux infos
  box.write('smashToken', token);
  box.write('smashTokenExpiration', tokenExpiration);

  // Retourner le token
  return token;
}

getSmashAccount() async {
  // Obtenir les infos sur le compte Smash
  String token = box.read('smashToken') ?? '';
  String tokenExpiration = box.read('smashTokenExpiration') ?? '1971-01-01T00:00:00.00';

  // Si le token est expiré ou qu'il va expirer, créer un nouveau compte
  if (DateTime.parse(tokenExpiration).isBefore(DateTime.now().add(const Duration(minutes: 5)))) return await createSmashAccount();

  // Vérifier que le token fonctionne toujours
  http.Response accountInfo = await http.get(Uri.parse("https://iam.eu-west-3.fromsmash.co/account"),
    headers: {
      'Authorization': token,
      'Accept': 'application/json',
    }
  );

  // Si le token ne fonctionne plus, créer un nouveau compte
  if (accountInfo.statusCode != 200) return await createSmashAccount();

  // S'il fonctionne toujours, retourner le token
  return token;
}