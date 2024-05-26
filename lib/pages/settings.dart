import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:stendmobile/utils/check_url.dart';
import 'package:stendmobile/utils/show_snackbar.dart';
import 'package:stendmobile/utils/haptic.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:get_storage/get_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:lucide_icons/lucide_icons.dart';

// Fonction pour convertir une chaîne de caractères HEX en couleur
Color hexToColor(String code) {
  return Color(int.parse(code.substring(1, 7), radix: 16) + 0xFF000000);
}

class SettingsPage extends StatefulWidget {
  final Function refresh;
  final Function showRefreshButton;

  const SettingsPage({Key? key, required this.refresh, required this.showRefreshButton}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

bool checkedUpdate = false;

final box = GetStorage();
String? appVersion;
String latestVersion = '';
bool isUpdateAvailable = false;

class _SettingsPageState extends State<SettingsPage> with AutomaticKeepAliveClientMixin {
  bool _isConnected = true;
  late bool storeRelease;

  @override
  void initState() {
    _isConnected = box.read('apiInstanceUrl') != null;
    storeRelease = box.read('forceStore') != true && const String.fromEnvironment("storeRelease").isNotEmpty;
    if(!checkedUpdate) checkUpdate();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void checkUpdate() async {
    // Obtenir la version actuellement installée
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    debugPrint(packageInfo.toString());
    appVersion = packageInfo.version;

    // Variables locales
    int latestVersionExpire;

    // Vérifier si on a déjà en cache la version la plus récente
    latestVersion = box.read('latestVersion') ?? '';
    latestVersionExpire = box.read('latestVersionExpire') ?? 0;
    if (latestVersionExpire < DateTime.now().millisecondsSinceEpoch) {
      box.remove('latestVersion');
      box.remove('latestVersionExpire');
      latestVersion = '';
    }

    // Obtenir la version la plus récente depuis GitHub si on l'a pas déjà
    if (latestVersion.isEmpty) {
      debugPrint('Fetching GitHub to check update');
      http.Response response = await http.get(Uri.parse('https://api.github.com/repos/johan-perso/stend-mobile/releases/latest'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(utf8.decode(response.bodyBytes));
        latestVersion = jsonData['tag_name'];
        box.write('latestVersion', latestVersion);
        box.write('latestVersionExpire', DateTime.now().add(const Duration(hours: 6)).millisecondsSinceEpoch);
      }
    }

    // Si on a une version plus récente, on enregistre une variable
    if (latestVersion.isNotEmpty && latestVersion != appVersion){
      setState(() {
        isUpdateAvailable = true;
      });
    }
    checkedUpdate = true;
  }

  void checkInstance() async {
    // Obtenir certaines variables depuis les préférences
    final webInstanceUrl = box.read('webInstanceUrl');
    final apiInstanceUrl = box.read('apiInstanceUrl');
    final apiInstancePassword = box.read('apiInstancePassword');
    final requirePassword = box.read('requirePassword');
    final recommendedExpireTimes = box.read('recommendedExpireTimes');

    // Parse et mettre en forme les durées d'expiration
    List<String> expireTimes = [];
    if (recommendedExpireTimes != null) {
      for (var i = 0; i < recommendedExpireTimes.length; i++) {
        expireTimes.add("${recommendedExpireTimes[i]['label']} (value: ${recommendedExpireTimes[i]['value']})");
      }
    }

    // Afficher les variables
    Haptic().micro();
    await showAdaptiveDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Variables enregistrées"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("URL du client WEB :\n▶️ ${webInstanceUrl ?? "Non disponible"}"),
              Text("\nURL de l'API :\n▶️ ${apiInstanceUrl ?? "Non configuré"}"),
              Text("\nMot de passe requis par l'API :\n▶️ ${requirePassword == null ? "Non disponible" : requirePassword ? "Oui" : "Non"}"),
              Text("\nMot de passe de l'API :\n▶️ ${apiInstancePassword != null ? "Présent" : "Non disponible"}"),
              Text("\nDurées d'expiration recommandées :\n▶️ ${expireTimes.isEmpty ? 'Non disponible' : expireTimes.join("\n▶️ ")}"),
            ],
          )
        ),
        actions: [
          TextButton(
            onPressed: () {
              Haptic().micro();
              Navigator.of(context).pop();
            },
            child: Text(Platform.isIOS ? "OK" : "Fermer"),
          )
        ],
      ),
    );

    // Afficher une snackbar pour informer l'utilisateur
    if (!mounted) return;
    showSnackBar(context, "Début de la vérification de l'instance...");

    // Vérifier si l'API retourne HTTP 200
    var apiResponseCode = 0;
    if (apiInstanceUrl != null) {
      http.Response response;
      try {
        final url = Uri.parse('${apiInstanceUrl}instance');
        // Faire un timeout de 5sec
        response = await http.get(url).timeout(const Duration(seconds: 4));
        apiResponseCode = response.statusCode;
      } catch (e) {
        debugPrint(e.toString());
        if (!context.mounted) return;
        apiResponseCode = 0;
      }
    }

    // Vérifier le client WEB si on l'a
    var webResponseCode = 0;
    if (webInstanceUrl != null) {
      http.Response webResponse;
      try {
        final webUrl = Uri.parse(webInstanceUrl);
        webResponse = await http.get(webUrl).timeout(const Duration(seconds: 4));
        webResponseCode = webResponse.statusCode;
      } catch (e) {
        debugPrint(e.toString());
        if (!context.mounted) return;
        webResponseCode = 0;
      }
    }

    // Afficher les résultats
    if (!mounted) return;
    await showAdaptiveDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("État de l'instance"), 
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Client WEB :\n▶️ ${webInstanceUrl != null ? "${webResponseCode == 200 ? 'Accessible' : 'Non disponible'} (HTTP ${webResponseCode == 0 ? 'impossible à déterminer' : webResponseCode})" : "Non configuré"}"),
            Text("\nAPI :\n▶️ ${apiInstanceUrl != null ? "${apiResponseCode == 200 ? 'Accessible' : 'Non disponible'} (HTTP ${apiResponseCode == 0 ? 'impossible à déterminer' : apiResponseCode})" : "Non configuré"}"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Haptic().micro();
              Navigator.of(context).pop();
            },
            child: Text(Platform.isIOS ? "OK" : "Fermer"),
          )
        ],
      )
    );
  }

  void clearHistory() {
    Haptic().micro();
    box.remove('historic');
    showSnackBar(context, "L'historique a été effacé");
  }

  @override
  bool get wantKeepAlive => true;

  /* Note:
  - Entre chaque élément, espace de 12 pixels
  - En bas de la page, espace de 10 pixels
  - À la fin d'un section, 32 pixels pour des boutons, 25 pixels pour une SwitchListTile
  - Après un titre : 16 pixels pour des boutons, 12 pixels pour une SwitchListTile
  */

	@override
	Widget build(BuildContext context) {
    super.build(context);

		return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // Titre de la section
              Padding(
                padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 12.0),

                child: Text(
                  "Réglages généraux",

                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black,
                  )
                )
              ),

              // Si une màj est disponible
              isUpdateAvailable ? Card(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),

                      child: ListTile(
                        title: const Text("Mise à jour disponible"),
                        subtitle: Text("Vous pouvez mettre à jour l'application à la version v$latestVersion pour bénéficier de nouvelles fonctionnalités et corrections de bugs."),
                      )
                    ),

                    Padding(
                      padding: const EdgeInsets.all(12.0),

                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FilledButton(
                            onPressed: () async {
                              Haptic().micro();
                              final url = Uri.parse('https://github.com/johan-perso/stend-mobile/releases/latest');
                              launchUrl(url, mode: Platform.isIOS ? LaunchMode.inAppBrowserView : LaunchMode.externalApplication);
                            },
                            child: const Text("Lire le changelog"),
                          ),
                        ],
                      )
                    ),

                    const SizedBox(height: 8),
                  ]
                )
              ) : const SizedBox.shrink(),

              // Configuration de Stend
              !_isConnected ? Card(
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0, bottom: 4.0),

                      child: ListTile(
                        title: Text("Stend n'est pas encore configuré"),
                        subtitle: Text("Pour commencer à transférer vers Stend, vous aurez besoin de vous authentifier à une instance.\n\nUne instance est un serveur sur lequel vous enverrez vos fichiers. Celui-ci aura un accès aux données que vous lui envoyez."),
                      )
                    ),

                    Padding(
                      padding: const EdgeInsets.all(12.0),

                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              Haptic().micro();
                              showAdaptiveDialog(
                                context: context,
                                builder: (context) => AlertDialog.adaptive(
                                  title: const Text("Configuration de Stend"),
                                  content: Text("Stend est un service vous permettant de télécharger et envoyer des fichiers via votre propre serveur.\n\n${Platform.isIOS ? '' : 'Pour pouvoir utiliser cette application, vous aurez besoin de configurer votre propre instance via les explications fournis dans la documentation. '}Une instance de démonstration est disponible ${Platform.isIOS ? 'sur la documentation' : 'sur celle-ci'}."),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Haptic().micro();
                                        Navigator.of(context).pop();
                                      },
                                      child: Text(Platform.isIOS ? "OK" : "Fermer"),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Haptic().micro();
                                        Navigator.of(context).pop();

                                        final Uri url = Uri.parse('https://stend-docs.johanstick.fr');
                                        launchUrl(url);
                                      },
                                      child: const Text("Documentation"),
                                    )
                                  ],
                                ),
                              );
                            },
                            child: const Text("En savoir plus"),
                          ),

                          const SizedBox(width: 12),

                          FilledButton(
                            onPressed: () async {
                              Haptic().micro();
                              String apiUrlFromWeb = '';

                              // On récupère l'URL du client web de l'instance via un dialogue
                              var webUrl = await showTextInputDialog(
                                context: context,
                                title: 'Client WEB',
                                message: "Entrer l'URL du site de votre serveur si vous en avez un, sinon, laissez vide.",
                                okLabel: 'Valider',
                                cancelLabel: 'Annuler',
                                textFields: const [
                                  DialogTextField(
                                    hintText: "https://stend.example.com",
                                    autocorrect: false,
                                    keyboardType: TextInputType.url
                                  ),
                                ],
                              );

                              // Si l'URL entré est "demo", on met l'URL de démo
                              if (webUrl != null && webUrl.single.toString().toLowerCase() == 'demo') {
                                webUrl = List<String>.filled(1, 'https://stend-demo.johanstick.fr');
                              }

                              // Si on a entré une URL d'un client
                              if (webUrl != null && webUrl.toString().length > 2) {
                                if (!context.mounted) return;

                                var url = webUrl.single.toString();
                                if (url.toString().endsWith('//')) url = url.toString().substring(0, url.toString().length - 1);
                                if (!url.toString().endsWith('/')) url += '/';

                                // Vérifier que l'URL commence par http ou https
                                if (!url.startsWith('http://') && !url.startsWith('https://')) {
                                  url = 'https://$url';
                                }

                                if (!checkURL(webUrl.single)) {
                                  showSnackBar(context, "L'URL entrée n'est pas valide");
                                  Haptic().warning();
                                  return;
                                }

                                final urlParsed = Uri.parse(url);

                                // Vérifier que l'URL soit valide
                                if (!urlParsed.isAbsolute) {
                                  showSnackBar(context, "L'URL entrée n'est pas valide");
                                  Haptic().warning();
                                  return;
                                }

                                // Vérifier que l'URL soit accessible
                                try {
                                  final response = await http.get(urlParsed);
                                  if (response.statusCode != 200) { // Si on a pas accès à l'URL, on dit que ça marche pas
                                    if (!context.mounted) return;
                                    showSnackBar(context, "Nous n'avons pas pu accéder à l'URL entrée");
                                    Haptic().error();
                                    return;
                                  } else { // Si on y a accès, on essaye de parser l'URL de l'API
                                    try {
                                      apiUrlFromWeb = response.body.split('apibaseurl="')[1].split('"')[0];
                                    } catch (e) {
                                      debugPrint("Aucune API trouvé dans le client web, on continue : $e");
                                    }
                                  }
                                } catch (e) {
                                  debugPrint(e.toString());
                                  if (!context.mounted) return;
                                  showSnackBar(context, "Nous n'avons pas pu accéder à l'URL entrée");
                                  Haptic().error();
                                  return;
                                }

                                // Enregistrer l'URL
                                box.write('webInstanceUrl', urlParsed.toString());
                              }

                              // On récupère l'URL de l'API
                              if (!context.mounted) return;
                              final apiUrl = await showTextInputDialog(
                                context: context,
                                title: "API de l'instance",
                                message: "Entrer l'URL de l'API de votre serveur, celle-ci est nécessaire. Un mot de passe pourra être demandé.",
                                okLabel: 'Valider',
                                cancelLabel: 'Annuler',
                                textFields: [
                                  DialogTextField(
                                    hintText: "https://stend-api.example.com",
                                    autocorrect: false,
                                    initialText: apiUrlFromWeb != '' ? apiUrlFromWeb : null,
                                    keyboardType: TextInputType.url
                                  ),
                                ],
                              );

                              // On vérifie qu'on a entré une URL d'API
                              if (!context.mounted) return;
                              if (apiUrl == null || apiUrl.toString().length < 2) {
                                showSnackBar(context, "Une URL d'API est nécessaire pour continuer");
                                Haptic().warning();
                                return;
                              }

                              // On rajoute un slash et "instance" à l'URL de l'API
                              var apiUrlString = apiUrl.single.toString();
                              if (apiUrl.toString().endsWith('//')) apiUrlString = apiUrlString.substring(0, apiUrlString.length - 1);
                              if (!apiUrlString.endsWith('/')) apiUrlString += '/';
                              debugPrint(apiUrlString);
                              var apiUrlStringInstance = '${apiUrlString}instance';

                              // Vérifier que l'URL commence par http ou https
                              if (!apiUrlString.startsWith('http://') && !apiUrlString.startsWith('https://')) {
                                apiUrlString = 'https://$apiUrlString';
                              }

                              // On vérifie que l'URL de l'API soit valide
                              if (!checkURL(apiUrlStringInstance)) {
                                showSnackBar(context, "L'URL de l'API semble invalide");
                                Haptic().warning();
                                return;
                              }

                              final url = Uri.parse(apiUrlStringInstance);

                              // Vérifier que l'URL soit valide
                              if (!context.mounted) return;
                              if (!url.isAbsolute) {
                                showSnackBar(context, "L'URL entrée n'est pas valide");
                                Haptic().warning();
                                return;
                              }

                              // Une fois la requête terminé
                              try {
                                // Vérifier que l'URL soit accessible
                                final response = await http.get(url);
                                if (response.statusCode != 200) {
                                  if (!context.mounted) return;
                                  showSnackBar(context, "La requête n'a pas abouti. Vérifier l'URL");
                                  Haptic().error();
                                  return;
                                }

                                // Parse la réponse
                                final Map<String, dynamic> jsonData = json.decode(utf8.decode(response.bodyBytes));

                                // Définir certaines données dans les préférences
                                box.write('requirePassword', jsonData['requirePassword']);
                                box.write('recommendedExpireTimes', jsonData['recommendedExpireTimes']);
                                box.write('apiInstanceUrl', apiUrlString);
                              } catch (e) {
                                if (!context.mounted) return;
                                showSnackBar(context, "Nous n'avons pas pu accéder à l'URL entrée");
                                debugPrint(e.toString());
                                Haptic().error();
                                return;
                              }

                              // Si on a besoin de s'autentifier
                              if (box.read('requirePassword') ?? false) {
                                if (!context.mounted) return;
                                final password = await showTextInputDialog(
                                  context: context,
                                  title: "Mot de passe",
                                  message: "Un mot de passe est nécessaire pour se connecter à cette API.",
                                  okLabel: 'Valider',
                                  cancelLabel: 'Annuler',
                                  textFields: const [
                                    DialogTextField(
                                      hintText: "Mot de passe",
                                      obscureText: true,
                                      keyboardType: TextInputType.visiblePassword
                                    ),
                                  ],
                                );

                                // Si on a entré un mot de passe
                                if (password != null && password.toString().length > 2) {
                                  // On vérifie qu'il est valide avec une requête POST checkPassword et un header Authorization
                                  final passwordString = password.single.toString();
                                  final url = Uri.parse('${apiUrlString}checkPassword');
                                  final response = await http.post(
                                    url,
                                    headers: <String, String>{
                                      "Authorization": passwordString
                                    }
                                  );

                                  // Parse la réponse
                                  final Map<String, dynamic> jsonData = json.decode(utf8.decode(response.bodyBytes));
                                  if (!context.mounted) return;
                                  try {
                                    if (jsonData['success']) {
                                      box.write('apiInstancePassword', passwordString);
                                    } else {
                                      box.remove('apiInstanceUrl');
                                      showSnackBar(context, jsonData['message']);
                                    }
                                  } catch (e) {
                                    box.remove('apiInstanceUrl');
                                    showSnackBar(context, jsonData['message']);
                                  }
                                } else {
                                  if (!context.mounted) return;
                                  showSnackBar(context, "La configuration de l'API a été annulée");
                                  return;
                                }
                              }

                              // Informer l'utilisateur (si on a réussi)
                              debugPrint('API Instance URL : ${box.read('apiInstanceUrl')}');
                              if (box.read('apiInstanceUrl') != null) {
                                if (!context.mounted) return;
                                Haptic().success();
                                showSnackBar(context, "Vous êtes maintenant connecté à votre instance");
                                setState(() {
                                  _isConnected = true;
                                });
                              }
                            },
                            child: const Text("Configurer"),
                          ),
                        ],
                      )
                    ),

                    const SizedBox(height: 8),
                  ]
                )
              ) : const SizedBox.shrink(),

              // Espace entre les cartes et les autres éléments
              isUpdateAvailable || !_isConnected ? const SizedBox(height: 12) : const SizedBox.shrink(),

              // Padding principal
              Padding(
                padding: const EdgeInsets.only(top: 10.0, left: 14.0, right: 14.0, bottom: 14.0),

                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    // Comportement
                    Text(
                      "Comportement",

                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onPrimaryContainer
                      )
                    ),
                    const SizedBox(height: 6),

                    Theme(
                      data: Theme.of(context).copyWith(
                        splashFactory: NoSplash.splashFactory,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text("Enregistrer dans la galerie"),
                            subtitle: const Text("Les médias téléchargés seront enregistrés dans la galerie"),
                            value: box.read('saveMediasInGallery') ?? false,
                            contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0, top: 2.0, bottom: 0.0),
                            onChanged: (bool? value) {
                              Haptic().micro();
                              setState(() {
                                box.write('saveMediasInGallery', value!);
                              });
                            },
                          ),

                          SwitchListTile(
                            title: const Text("Copier l'URL après un envoi"),
                            subtitle: const Text("Copie dans le presser-papier le lien d'un transfert lorsqu'il se termine"),
                            value: box.read('copyUrlAfterSend') ?? false,
                            contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0, top: 2.0, bottom: 0.0),
                            onChanged: (bool? value) {
                              Haptic().micro();
                              setState(() {
                                box.write('copyUrlAfterSend', value!);
                              });
                            },
                          ),

                          Platform.isAndroid ? SwitchListTile(
                            title: const Text("Télécharger dans un dossier"),
                            subtitle: const Text("Les fichiers seront téléchargés dans un sous-dossier nommé \"Stend\""),
                            value: box.read('downloadInSubFolder') ?? false,
                            contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0, top: 2.0, bottom: 0.0),
                            onChanged: (bool? value) {
                              Haptic().micro();
                              setState(() {
                                box.write('downloadInSubFolder', value!);
                              });
                            },
                          ) : const SizedBox.shrink(),
                        ]
                      )
                    ),
                    const SizedBox(height: 25),

                    // Par défaut
                    Text(
                      "Par défaut",

                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onPrimaryContainer
                      )
                    ),
                    const SizedBox(height: 6),

                    Theme(
                      data: Theme.of(context).copyWith(
                        splashFactory: NoSplash.splashFactory,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text("Raccourcir l'URL par défaut"),
                            subtitle: const Text("L'option pour raccourcir le lien d'un transfert sera coché au lancement"),
                            value: box.read('shortenUrl') ?? false,
                            contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0, top: 2.0, bottom: 0.0),
                            onChanged: (bool? value) {
                              Haptic().micro();
                              setState(() {
                                box.write('shortenUrl', value!);
                                widget.showRefreshButton(true);
                              });
                            },
                          ),

                          ListTile(
                            title: const Text("Durée avant expiration"),
                            subtitle: const Text("Définissez la durée avant expiration par défaut d'un fichier"),
                            trailing: DropdownButton<String>(
                              value: box.read('defaultExpirationTime') ?? '+ court',
                              onTap: () { Haptic().micro(); },
                              onChanged: (String? newValue) {
                                Haptic().micro();
                                setState(() {
                                  box.write('defaultExpirationTime', newValue!);
                                  widget.showRefreshButton(true);
                                });
                              },
                              items: <String>['+ court', '+ long']
                              .map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                                );
                              }).toList(),
                            ),
                            contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0, top: 2.0, bottom: 0.0),
                          ),

                          ListTile(
                            title: const Text("Page à l'ouverture"),
                            subtitle: const Text("Définissez la page qui s'ouvrira au démarrage de l'appli"),
                            trailing: DropdownButton<String>(
                              value: box.read('defaultPage') ?? 'Envoyer',
                              onTap: () { Haptic().micro(); },
                              onChanged: (String? newValue) {
                                Haptic().micro();
                                setState(() {
                                  box.write('defaultPage', newValue!);
                                });
                              },
                              items: <String>['Envoyer', 'Télécharger', 'Réglages']
                              .map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                                );
                              }).toList(),
                            ),
                            contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0, top: 2.0, bottom: 0.0),
                          ),
                        ]
                      )
                    ),
                    const SizedBox(height: 25),

                    // Apparence
                    Text(
                      "Apparence",

                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onPrimaryContainer
                      )
                    ),
                    const SizedBox(height: 6),

                    Theme(
                      data: Theme.of(context).copyWith(
                        splashFactory: NoSplash.splashFactory,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            title: const Text("Thème"),
                            subtitle: const Text("Choisissez le thème de l'appli"),
                            trailing: DropdownButton<String>(
                              value: box.read('theme') ?? 'Système',
                              onTap: () { Haptic().micro(); },
                              onChanged: (String? newValue) {
                                Haptic().micro();
                                setState(() {
                                  box.write('theme', newValue!);
                                  widget.showRefreshButton(true);
                                });
                              },
                              items: <String>['Système', 'Clair', 'Sombre']
                              .map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                                );
                              }).toList(),
                            ),
                            contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0, top: 2.0, bottom: 0.0),
                          ),

                          ListTile(
                            title: const Text("Icônes"),
                            subtitle: const Text("Choisissez le style d'icône utilisé"),
                            trailing: DropdownButton<String>(
                              value: box.read('iconLib') ?? 'Material',
                              onTap: () { Haptic().micro(); },
                              onChanged: (String? newValue) {
                                Haptic().micro();
                                setState(() {
                                  box.write('iconLib', newValue!);
                                  widget.showRefreshButton(true);
                                });
                              },
                              items: <String>['Material', 'iOS', 'Lucide', 'Lucide (alt)']
                              .map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                                );
                              }).toList(),
                            ),
                            contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0, top: 2.0, bottom: 0.0),
                          ),

                          Platform.isIOS ? ListTile(
                            title: const Text("Choix des couleurs"),
                            subtitle: const Text("Choisissez une couleur clé qui sera utilisée dans l'appli"),
                            trailing: IconButton(
                              onPressed: () async {
                                debugPrint(box.read('appColor').toString());
                                Haptic().micro();
                                await showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text('Choix des couleurs'),
                                      content: SingleChildScrollView(
                                        child: ColorPicker(
                                          pickerColor: box.read('appColor') != null ? hexToColor(box.read('appColor')) : Colors.blueAccent,
                                          enableAlpha: false,
                                          hexInputBar: true,
                                          labelTypes: const [],
                                          onColorChanged: (Color color) {
                                            box.write('appColor', '#${color.value.toRadixString(16).substring(2)}');
                                          },
                                        ),
                                      ),
                                      actions: [
                                        ElevatedButton(
                                          child: const Text('Enregistrer'),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            widget.showRefreshButton(true);
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              icon: const Icon(Icons.color_lens),
                            ),
                            contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0, top: 2.0, bottom: 0.0),
                          ) : const SizedBox.shrink(),
                        ]
                      )
                    ),
                    const SizedBox(height: 25),

                    // Options supplémentaires
                    Text(
                      "Options supplémentaires",

                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onPrimaryContainer
                      )
                    ),
                    const SizedBox(height: 6),

                    Theme(
                      data: Theme.of(context).copyWith(
                        splashFactory: NoSplash.splashFactory,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text("Désactiver l'historique"),
                            subtitle: const Text("Empêche Stend d'ajouter de nouveaux liens à l'historique de transferts"),
                            value: box.read('disableHistory') ?? false,
                            contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0, top: 2.0, bottom: 0.0),
                            onChanged: (bool? value) {
                              Haptic().micro();
                              setState(() {
                                box.write('disableHistory', value!);
                                widget.showRefreshButton(true);
                              });
                            },
                          ),

                          ListTile(
                            title: const Text("Service d'URLs courts"),
                            subtitle: const Text("Définissez le service utilisé pour racourcir les URLs"),
                            trailing: DropdownButton<String>(
                              value: box.read('shortenService') ?? 'mdrr.fr',
                              onTap: () { Haptic().micro(); },
                              onChanged: (String? newValue) {
                                Haptic().micro();
                                setState(() {
                                  box.write('shortenService', newValue!);
                                });
                              },
                              items: <String>['mdrr.fr', 'ptdrr.com', 's.3vm.cl', 's.erc.hr']
                              .map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                                );
                              }).toList(),
                            ),
                            contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0, top: 2.0, bottom: 0.0),
                          ),

                          ListTile(
                            title: const Text("Caméra pour les QR Codes"),
                            subtitle: const Text("Définissez la caméra qui sera utilisée pour scanner les QR Codes"),
                            trailing: DropdownButton<String>(
                              value: box.read('cameraFacing') ?? 'Arrière',
                              onTap: () { Haptic().micro(); },
                              onChanged: (String? newValue) {
                                Haptic().micro();
                                setState(() {
                                  box.write('cameraFacing', newValue!);
                                });
                              },
                              items: <String>['Arrière', 'Avant']
                              .map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                                );
                              }).toList(),
                            ),
                            contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0, top: 2.0, bottom: 0.0),
                          ),
                        ]
                      )
                    ),
                  ],
                )
              ),

              const SizedBox(height: 10),

              // Boutons d'actions
              Padding(
                padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width > 400 ? 12 : 24.0),

                child: Column(
                  children: [
                    MediaQuery.of(context).size.width > 400 ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        OutlinedButton(
                          onPressed: () { checkInstance(); },
                          child: const Text("Vérifier l'instance"),
                        ),
                        OutlinedButton(
                          onPressed: () { clearHistory(); },
                          child: const Text("Effacer l'historique"),
                        )
                      ],
                    ) : Center(
                      child: Column(
                        children: [
                          OutlinedButton(
                            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                            onPressed: () { checkInstance(); },
                            child: const Text("Vérifier l'instance"),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton(
                            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                            onPressed: () { clearHistory(); },
                            child: const Text("Effacer l'historique"),
                          )
                        ],
                      )
                    ),

                    const SizedBox(height: 8),

                    Center(
                      child: FilledButton(
                        style: MediaQuery.of(context).size.width > 400 ? null : FilledButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                        onPressed: () {
                          Haptic().warning();
                          showAdaptiveDialog(
                            context: context,
                            builder: (context) => AlertDialog.adaptive(
                              title: Text(_isConnected ? "Se déconnecter" : "Effacer les réglages"),
                              content: Text("Êtes-vous sûr de vouloir vous déconnecter ? ${(box.read('apiInstancePassword') != null && box.read('apiInstancePassword').isNotEmpty) ? "Assurez-vous de connaître le mot de passe de cette instance pour vous reconnecter." : "Cette action est irréversible."}"),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Haptic().micro();
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text("Annuler"),
                                ),

                                TextButton(
                                  onPressed: () async {
                                    // Supprimer les réglages
                                    box.erase();

                                    // Supprimer les fichiers caches
                                    try {
                                      var tempDir = await getTemporaryDirectory();
                                      if (tempDir.existsSync()) {
                                        tempDir.deleteSync(recursive: true);
                                      }
                                    } catch (e) {
                                      debugPrint(e.toString());
                                      if (!context.mounted) return;
                                      showSnackBar(context, "Impossible d'effacer le cache");
                                      Haptic().error();
                                    }

                                    // Informer l'utilisateur
                                    if (!context.mounted) return;
                                    Haptic().success();
                                    showSnackBar(context, _isConnected ? "Vous êtes maintenant déconnecté" : "Les réglages ont été effacées");

                                    // Recharger la page
                                    widget.refresh();
                                  },
                                  child: Text(_isConnected ? "Se déconnecter" : "Confirmer"),
                                )
                              ],
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 30.0),
                          child: Text(_isConnected ? "Se déconnecter" : "Effacer les réglages")
                        ),
                      )
                    ),
                  ]
                )
              ),
              const SizedBox(height: 10),

              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      // Texte
                      Text(
                        "Stend Mobile${appVersion != null ? ' v$appVersion' : ''} (${storeRelease ? 'Release Store' : 'Release Libre'})\nDéveloppé par Johan",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black,
                        ),
                      ),

                      const SizedBox(height: 2),

                      // Liens
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () {
                              Haptic().micro();
                              launchUrl(Uri.parse('https://stend-docs.johanstick.fr'), mode: LaunchMode.externalApplication);
                            },
                            icon: const Icon(LucideIcons.globe),
                            color: Theme.of(context).colorScheme.secondary
                          ),
                          IconButton(
                            onPressed: () {
                              Haptic().micro();
                              launchUrl(Uri.parse('https://github.com/johan-perso/stend-mobile'), mode: LaunchMode.externalApplication);
                            },
                            icon: const Icon(LucideIcons.github),
                            color: Theme.of(context).colorScheme.secondary
                          ),
                          IconButton(
                            onPressed: () {
                              Haptic().micro();
                              launchUrl(Uri.parse('https://twitter.com/johan_stickman'), mode: LaunchMode.externalApplication);
                            },
                            icon: const Icon(LucideIcons.twitter),
                            color: Theme.of(context).colorScheme.secondary
                          ),
                          IconButton(
                            onPressed: () {
                              Haptic().micro();
                              launchUrl(Uri.parse('https://johanstick.fr/#donate'), mode: LaunchMode.externalApplication);
                            },
                            icon: const Icon(LucideIcons.circleDollarSign),
                            color: Theme.of(context).colorScheme.secondary
                          ),
                        ]
                      ),

                      const SizedBox(height: 4),
                    ]
                  )
                )
              )
            ],
          ),
        ),
      )
    );
	}
}