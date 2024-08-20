import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:stendmobile/widgets/custom_switch_tile.dart';
import 'package:stendmobile/widgets/settings_dropdown_button.dart';
import 'package:stendmobile/utils/check_url.dart';
import 'package:stendmobile/utils/show_snackbar.dart';
import 'package:stendmobile/utils/haptic.dart';
import 'package:stendmobile/utils/geolocator.dart';
import 'package:stendmobile/utils/actions_dialog.dart';
import 'package:stendmobile/utils/check_connectivity.dart';
import 'package:stendmobile/utils/global_server.dart' as globalserver;
import 'package:stendmobile/utils/globals.dart' as globals;
import 'package:url_launcher/url_launcher.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:get_storage/get_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:in_app_update/in_app_update.dart' as android_updater;
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
  final Function updateState;
  final bool useCupertino;

  const SettingsPage({Key? key, required this.refresh, required this.showRefreshButton, required this.updateState, required this.useCupertino}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

bool checkedUpdate = false;

final box = GetStorage();
String? appVersion;
String installSource = '';
String latestVersion = '';
bool isUpdateAvailable = false;

class _SettingsPageState extends State<SettingsPage> with AutomaticKeepAliveClientMixin {
  bool _isConnected = true;
  bool _isGlobalAccountConnected = false;
  late bool storeRelease;

  @override
  void initState() {
    _isConnected = box.read('apiInstanceUrl') != null;
    _isGlobalAccountConnected = box.read('exposeMethods_account') != null;
    storeRelease = box.read('forceStore') != true && const String.fromEnvironment("storeRelease").isNotEmpty;
    if(!checkedUpdate) checkUpdate();

    super.initState();
    globals.indicatePageInitialized('settings');

    globals.intereventsStreamController.stream.listen((event) {
      if (event['type'] != 'settings') return;

      if (event['action'] == 'reset') {
        askResetSettings();
      } else if (event['action'] == 'checkInstance') {
        checkInstance();
      } else if (event['action'] == 'configInstance') {
        configureInstance(
          initialWebUrl: event['initialWebUrl'],
          initialApiUrl: event['initialApiUrl'],
          initialPassword: event['initialPassword']
        );
      } else if (event['action'] == 'refreshSettings') {
        setState(() {
          _isConnected = box.read('apiInstanceUrl') != null;
          _isGlobalAccountConnected = box.read('exposeMethods_account') != null;
        });
      }
    });
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

    // Définir la source d'installation
    if(packageInfo.installerStore == 'com.android.vending') installSource = 'playStore';

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
      http.Response response = await http.get(Uri.parse('https://api.github.com/repos/hoststend/stend-mobile/releases/latest'));
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
    // Vérifier l'accès à internet
    bool connectivity = await checkConnectivity();
    if (!mounted) return;
    if (!connectivity) {
      Haptic().warning();
      showSnackBar(context, "Vous n'êtes pas connecté à internet, vérifiez votre connexion et réessayez", icon: "warning", useCupertino: widget.useCupertino);
      return;
    }

    // Obtenir certaines variables depuis les préférences
    final webInstanceUrl = box.read('webInstanceUrl');
    final apiInstanceUrl = box.read('apiInstanceUrl');
    final globalserverInstanceUrl = box.read('globalserverInstanceUrl') ?? 'https://globalstend.johanstick.fr/';

    // Afficher une snackbar pour informer l'utilisateur
    Haptic().light();
    showSnackBar(context, "Début de la vérification des services...", icon: "info", useCupertino: widget.useCupertino);

    // Objet qui contient les statuts
    bool atLeastOneIssue = false; // Si on a au moins un problème avec les éléments self-hosté
    Map status = {
      'api': { 'statusBool': false, 'statusFriendly': 'impossible à déterminer', 'httpCode': 0, 'ping': -1, 'startCheck': 0, 'version': 'impossible à déterminer' },
      'web': { 'statusBool': false, 'statusFriendly': 'impossible à déterminer', 'httpCode': 0, 'ping': -1, 'startCheck': 0, 'version': 'impossible à déterminer' },
      'globalserver': { 'statusBool': false, 'statusFriendly': 'impossible à déterminer', 'httpCode': 0, 'ping': -1, 'startCheck': 0, 'version': 'impossible à déterminer' },
      'cobalt': { 'statusBool': false, 'statusFriendly': 'impossible à déterminer', 'httpCode': 0, 'ping': -1, 'startCheck': 0, 'version': 'impossible à déterminer' },
    };

    // Vérifier l'API
    if (apiInstanceUrl != null) {
      http.Response response;
      try {
        final url = Uri.parse('${apiInstanceUrl}instance');
        status['api']['startCheck'] = DateTime.now().millisecondsSinceEpoch;
        response = await http.get(url).timeout(const Duration(seconds: 10));
        status['api']['ping'] = DateTime.now().millisecondsSinceEpoch - status['api']['startCheck'];
        status['api']['httpCode'] = response.statusCode;
        status['api']['statusFriendly'] = response.statusCode == 200 ? 'accessible' : 'accessible avec erreur';
        status['api']['statusBool'] = response.statusCode == 200 ? true : false;

        if(response.statusCode == 200) {
          try {
            final Map<String, dynamic> jsonData = json.decode(utf8.decode(response.bodyBytes));
            box.write('requirePassword', jsonData['requirePassword']);
            box.write('recommendedExpireTimes', jsonData['recommendedExpireTimes']);
            status['api']['version'] = jsonData['apiVersion'];
          } catch (e) {
            debugPrint("Impossible d'extraire les informations de l'instance (API) : $e");
            atLeastOneIssue = true;
          }
        } else {
          atLeastOneIssue = true;
        }
      } catch (e) {
        debugPrint('API instance check failed');
        debugPrint(e.toString());
        if (!context.mounted) return;
        status['api']['statusFriendly'] = 'non disponible';
      }
    }

    // Vérifier le client WEB
    if (webInstanceUrl != null) {
      http.Response response;
      try {
        final url = Uri.parse('$webInstanceUrl/version');
        status['web']['startCheck'] = DateTime.now().millisecondsSinceEpoch;
        response = await http.get(url).timeout(const Duration(seconds: 10));
        status['web']['ping'] = DateTime.now().millisecondsSinceEpoch - status['web']['startCheck'];
        status['web']['httpCode'] = response.statusCode;
        status['web']['statusFriendly'] = response.statusCode == 200 ? 'accessible' : 'accessible avec erreur';
        status['web']['statusBool'] = response.statusCode == 200 ? true : false;

        if(response.statusCode == 200) {
          try {
            final String version = utf8.decode(response.bodyBytes);
            if (version.isNotEmpty && version.length > 100) {
              status['web']['version'] = '${version.substring(0, 100)}...';
            } else if(version.isNotEmpty) {
              status['web']['version'] = version;
            }
          } catch (e) {
            debugPrint("Impossible d'extraire les informations de l'instance (WEB) : $e");
            atLeastOneIssue = true;
          }
        } else {
          atLeastOneIssue = true;
        }
      } catch (e) {
        debugPrint('web instance check failed');
        debugPrint(e.toString());
        if (!context.mounted) return;
        status['web']['statusFriendly'] = 'non disponible';
      }
    }

    // Vérifier le serveur global
    if (globalserverInstanceUrl != null) {
      http.Response response;
      try {
        final url = Uri.parse('${globalserverInstanceUrl}instance');
        status['globalserver']['startCheck'] = DateTime.now().millisecondsSinceEpoch;
        response = await http.get(url).timeout(const Duration(seconds: 10));
        status['globalserver']['ping'] = DateTime.now().millisecondsSinceEpoch - status['globalserver']['startCheck'];
        status['globalserver']['httpCode'] = response.statusCode;
        status['globalserver']['statusFriendly'] = response.statusCode == 200 ? 'accessible' : 'accessible avec erreur';
        status['globalserver']['statusBool'] = response.statusCode == 200 ? true : false;

        if(response.statusCode == 200) {
          try {
            final Map<String, dynamic> jsonData = json.decode(utf8.decode(response.bodyBytes));
            status['globalserver']['version'] = jsonData['apiVersion'];
          } catch (e) {
            debugPrint("Impossible d'extraire les informations du serveur global : $e");
          }
        }
      } catch (e) {
        debugPrint('global server instance check failed');
        debugPrint(e.toString());
        if (!context.mounted) return;
        status['globalserver']['statusFriendly'] = 'non disponible';
      }
    }

    // Vérifier l'instance Cobalt
    String cobaltApiUrl = 'https://api.cobalt.tools/';
    if (true) { // pr éviter que la variable response puisse sortir du scope
      http.Response response;
      try {
        final url = Uri.parse('${cobaltApiUrl}api/serverInfo');
        status['cobalt']['startCheck'] = DateTime.now().millisecondsSinceEpoch;
        response = await http.get(url).timeout(const Duration(seconds: 10));
        status['cobalt']['ping'] = DateTime.now().millisecondsSinceEpoch - status['cobalt']['startCheck'];
        status['cobalt']['httpCode'] = response.statusCode;
        status['cobalt']['statusFriendly'] = response.statusCode == 200 ? 'accessible' : 'accessible avec erreur';
        status['cobalt']['statusBool'] = response.statusCode == 200 ? true : false;

        if(response.statusCode == 200) {
          try {
            final Map<String, dynamic> jsonData = json.decode(utf8.decode(response.bodyBytes));
            status['cobalt']['version'] = jsonData['version'];
          } catch (e) {
            debugPrint("Impossible d'extraire les informations de cobalt : $e");
          }
        }
      } catch (e) {
        debugPrint('cobalt instance check failed');
        debugPrint(e.toString());
        if (!context.mounted) return;
        status['cobalt']['statusFriendly'] = 'non disponible';
      }
    }

    // Générer un message friendly qui décrit l'état de tous les services
    String summary = "${apiInstanceUrl == null && webInstanceUrl == null ? "Vous n'êtes pas encore connecté à une instance Stend, appuyez sur \"Configurer\" et entrez \"demo\" pour tester les capacités de l'app." : "L'infrastructure auto-hébergée que vous utilisez semble être ${status['api']['statusBool'] || status['web']['statusBool'] ? "opérationnelle${atLeastOneIssue ? ', sauf pour ${status['api']['statusBool'] == false ? "l'API" : "le client WEB"}' : ''}" : 'complètement indisponible'}."}${atLeastOneIssue ? " Vous pouvez essayer de vous déconnecter et de vous reconnecter, sinon, contactez l'administrateur de l'instance avec une capture d'écran des informations ci-dessous." : ''} Le serveur global est ${status['globalserver']['statusBool'] ? '${atLeastOneIssue == false ? 'également ' : ''}opérationnel.' : 'indisponible, vous pouvez vous rendre sur johanstick.fr/contact pour signaler ce problème ou réessayer plus tard.'}";

    // Haptic en fonction des résultats
    if(atLeastOneIssue || status['globalserver']['statusBool'] == false) {
      Haptic().warning();
    } else {
      Haptic().success();
    }

    // Afficher les résultats
    if (!mounted) return;
    await showModalBottomSheet(
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      context: context,
      builder: (context) => SafeArea(
        bottom: true,
        top: true,

        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(), // sinon on peut pas swipe pour fermer la sheet
          scrollDirection: Axis.vertical,
          child: Padding(
            padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 2.0),

            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: widget.useCupertino ? CrossAxisAlignment.center : CrossAxisAlignment.start,

              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
                  child: Text(summary),
                ),

                if (webInstanceUrl != null) ListTile(
                  title: Text("Client WEB : ${status['web']['statusFriendly']}"),
                  subtitle: Text("Temps de réponse : ${status['web']['ping']} ms\nRéponse : HTTP ${status['web']['httpCode']}\nVersion : ${status['web']['version']}"),
                ),

                if (apiInstanceUrl != null) ListTile(
                  title: Text("API : ${status['api']['statusFriendly']}"),
                  subtitle: Text("Temps de réponse : ${status['api']['ping']} ms\nRéponse : HTTP ${status['api']['httpCode']}\nVersion : ${status['api']['version']}"),
                ),

                ListTile(
                  title: Text("Serveur global : ${status['globalserver']['statusFriendly']}"),
                  subtitle: Text("Temps de réponse : ${status['globalserver']['ping']} ms\nRéponse : HTTP ${status['globalserver']['httpCode']}\nVersion : ${status['globalserver']['version']}"),
                ),

                ListTile(
                  title: Text("Cobalt/Kityune : ${status['cobalt']['statusFriendly']}"),
                  subtitle: Text("Temps de réponse : ${status['cobalt']['ping']} ms\nRéponse : HTTP ${status['cobalt']['httpCode']}\nVersion : ${status['cobalt']['version']}"),
                ),
              ]
            )
          )
        )
      )
    );
  }

  void clearHistory() {
    Haptic().light();
    box.remove('historic');
    showSnackBar(context, "L'historique a été effacé", icon: "success", useCupertino: widget.useCupertino);
  }

  void askResetSettings() {
    actionsDialog(
      context,
      title: _isConnected ? "Se déconnecter" : "Effacer les réglages",
      content: "Êtes-vous sûr de vouloir vous déconnecter ? ${(box.read('apiInstancePassword') != null && box.read('apiInstancePassword').isNotEmpty) ? "Assurez-vous de connaître le mot de passe de cette instance pour vous reconnecter." : "Tous les réglages seront effacés."}",
      actions: [
        TextButton(
          onPressed: () {
            Haptic().light();
            Navigator.of(context).pop();
          },
          child: const Text("Annuler"),
        ),

        TextButton(
          onPressed: () => resetSettings(),
          child: Text(_isConnected ? "Se déconnecter" : "Confirmer"),
        )
      ]
    );
  }

  void resetSettings() async {
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
      if (!mounted) return;
      showSnackBar(context, "Impossible d'effacer le cache", icon: "error", useCupertino: widget.useCupertino);
      Haptic().error();
    }

    // Informer l'utilisateur
    if (!mounted) return;
    Haptic().success();
    showSnackBar(context, _isConnected ? "Vous êtes maintenant déconnecté" : "Les réglages ont été effacées", icon: "success", useCupertino: widget.useCupertino);

    // Recharger la page
    widget.refresh();
  }

  void configureInstance({ String? initialWebUrl, String? initialApiUrl, String? initialPassword }) async {
    Haptic().light();
    String apiUrlFromWeb = '';

    // On récupère l'URL du client web de l'instance via un dialogue
    var webUrl = await showTextInputDialog(
      context: context,
      title: 'Client WEB',
      message: "Entrer l'URL du site de votre serveur si vous en avez un, sinon, laissez vide.",
      okLabel: 'Valider',
      cancelLabel: 'Annuler',
      textFields: [
        DialogTextField(
          hintText: "https://stend.example.com",
          autocorrect: false,
          initialText: initialWebUrl,
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
      if (!mounted) return;

      var url = webUrl.single.toString();
      if (url.toString().endsWith('//')) url = url.toString().substring(0, url.toString().length - 1);
      if (!url.toString().endsWith('/')) url += '/';

      // Vérifier que l'URL commence par http ou https
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }

      if (!checkURL(webUrl.single)) {
        showSnackBar(context, "L'URL entrée n'est pas valide", icon: "warning", useCupertino: widget.useCupertino);
        Haptic().warning();
        return;
      }

      final urlParsed = Uri.parse(url);

      // Vérifier que l'URL soit valide
      if (!urlParsed.isAbsolute) {
        showSnackBar(context, "L'URL entrée n'est pas valide", icon: "warning", useCupertino: widget.useCupertino);
        Haptic().warning();
        return;
      }

      // Vérifier que l'URL soit accessible
      try {
        final response = await http.get(urlParsed);
        if (response.statusCode != 200) { // Si on a pas accès à l'URL, on dit que ça marche pas
          if (!mounted) return;
          showSnackBar(context, "Nous n'avons pas pu accéder à l'URL entrée", icon: "error", useCupertino: widget.useCupertino);
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
        if (!mounted) return;
        showSnackBar(context, "Nous n'avons pas pu accéder à l'URL entrée", icon: "error", useCupertino: widget.useCupertino);
        Haptic().error();
        return;
      }

      // Enregistrer l'URL
      box.write('webInstanceUrl', urlParsed.toString());
    }

    // On récupère l'URL de l'API
    if (!mounted) return;
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
          initialText: initialApiUrl ?? (apiUrlFromWeb != '' ? apiUrlFromWeb : null),
          keyboardType: TextInputType.url
        ),
      ],
    );

    // On vérifie qu'on a entré une URL d'API
    if (!mounted) return;
    if (apiUrl == null || apiUrl.toString().length < 2) {
      showSnackBar(context, "Une URL d'API est nécessaire pour continuer", icon: "warning", useCupertino: widget.useCupertino);
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
      showSnackBar(context, "L'URL de l'API semble invalide", icon: "warning", useCupertino: widget.useCupertino);
      Haptic().warning();
      return;
    }

    final url = Uri.parse(apiUrlStringInstance);

    // Vérifier que l'URL soit valide
    if (!context.mounted) return;
    if (!url.isAbsolute) {
      showSnackBar(context, "L'URL entrée n'est pas valide", icon: "warning", useCupertino: widget.useCupertino);
      Haptic().warning();
      return;
    }

    // Une fois la requête terminé
    try {
      // Vérifier que l'URL soit accessible
      final response = await http.get(url);
      if (response.statusCode != 200) {
        if (!mounted) return;
        showSnackBar(context, "La requête n'a pas abouti. Vérifier l'URL", icon: "error", useCupertino: widget.useCupertino);
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
      if (!mounted) return;
      showSnackBar(context, "Nous n'avons pas pu accéder à l'URL entrée", icon: "error", useCupertino: widget.useCupertino);
      debugPrint(e.toString());
      Haptic().error();
      return;
    }

    // Si on a besoin de s'autentifier
    if (box.read('requirePassword') ?? false) {
      if (!mounted) return;
      final password = await showTextInputDialog(
        context: context,
        title: "Mot de passe",
        message: "Un mot de passe est nécessaire pour se authentifier à cette API.",
        okLabel: 'Valider',
        cancelLabel: 'Annuler',
        textFields: [
          DialogTextField(
            hintText: "Mot de passe",
            obscureText: initialPassword == null,
            initialText: initialPassword,
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
        if (!mounted) return;
        try {
          if (jsonData['success']) {
            box.write('apiInstancePassword', passwordString);
          } else {
            box.remove('apiInstanceUrl');
            Haptic().error();
            showSnackBar(context, jsonData['message'], icon: "error", useCupertino: widget.useCupertino);
          }
        } catch (e) {
          box.remove('apiInstanceUrl');
          Haptic().error();
          showSnackBar(context, jsonData['message'], icon: "error", useCupertino: widget.useCupertino);
        }
      } else {
        if (!mounted) return;
        Haptic().warning();
        showSnackBar(context, "La configuration de l'API a été annulée", icon: "warning", useCupertino: widget.useCupertino);
        return;
      }
    }

    // Informer l'utilisateur (si on a réussi)
    debugPrint('API Instance URL : ${box.read('apiInstanceUrl')}');
    if (box.read('apiInstanceUrl') != null) {
      if (!mounted) return;
      Haptic().success();
      showSnackBar(context, "Vous êtes maintenant connecté à votre instance", icon: "success", useCupertino: widget.useCupertino);
      setState(() {
        _isConnected = true;
      });
    }
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
                padding: EdgeInsets.only(left: 12.0, right: 12.0, bottom: 12.0, top: globals.isDesktop ? 12.0 : 0.0),

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
                              Haptic().light();

                              if(installSource.isEmpty){
                                final url = Uri.parse('https://github.com/hoststend/stend-mobile/releases/latest');
                                launchUrl(url, mode: Platform.isIOS ? LaunchMode.inAppBrowserView : LaunchMode.externalApplication);
                              } else if(installSource == 'playStore') {
                                debugPrint('Vérif. màj disponible auprès du play store');
                                android_updater.AppUpdateInfo updateAvailable;
                                try {
                                  updateAvailable = await android_updater.InAppUpdate.checkForUpdate();
                                  debugPrint('Vérif. màj : ${updateAvailable.toString()}');
                                } catch (e) {
                                  debugPrint('Impossible de vérifier la mise à jour : $e');
                                  Haptic().error();
                                  if(!context.mounted) return;
                                  showSnackBar(context, e.toString(), icon: "error", useCupertino: widget.useCupertino);
                                  return;
                                }

                                if(updateAvailable.immediateUpdateAllowed) {
                                  await android_updater.InAppUpdate.performImmediateUpdate();
                                } else if(updateAvailable.flexibleUpdateAllowed) {
                                  await android_updater.InAppUpdate.startFlexibleUpdate();
                                  await android_updater.InAppUpdate.completeFlexibleUpdate();
                                } else {
                                  debugPrint('Impossible de mettre à jour l\'application');
                                  Haptic().error();
                                  if(!context.mounted) return;
                                  showSnackBar(context, "Impossible de mettre à jour l'application", icon: "error", useCupertino: widget.useCupertino);
                                }
                              }
                            },
                            child: Text(installSource.isEmpty ? "Lire le changelog" : 'Mettre à jour'),
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
                        subtitle: Text("Pour commencer à transférer vers Stend, vous aurez besoin de vous connecter à une instance.\n\nUne instance est un serveur sur lequel vous enverrez vos fichiers. Celui-ci aura un accès aux données que vous lui envoyez."),
                      )
                    ),

                    Padding(
                      padding: const EdgeInsets.all(12.0),

                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              actionsDialog(
                                context,
                                title: "Configuration de Stend",
                                content: "Stend est un service vous permettant de télécharger et envoyer des fichiers via votre propre serveur.\n\n${widget.useCupertino ? '' : 'Pour pouvoir utiliser cette application, vous aurez besoin de configurer votre propre instance via les explications fournis dans la documentation. '}Une instance de démonstration est disponible ${widget.useCupertino ? 'sur la documentation' : 'sur celle-ci'}.",
                                haptic: 'light',
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Haptic().light();
                                      Navigator.of(context).pop();
                                    },
                                    child: Text(widget.useCupertino ? "OK" : "Fermer"),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Haptic().light();
                                      Navigator.of(context).pop();

                                      final Uri url = Uri.parse('https://stend.johanstick.fr');
                                      launchUrl(url);
                                    },
                                    child: const Text("Documentation"),
                                  )
                                ],
                              );
                            },
                            child: const Text("En savoir plus"),
                          ),

                          const SizedBox(width: 12),

                          FilledButton(
                            onPressed: () => configureInstance(),
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
                          CustomSwitchTile(
                            title: "Enregistrer dans la galerie",
                            subtitle: "Les médias téléchargés seront enregistrés dans la galerie",
                            value: box.read('saveMediasInGallery') ?? false,
                            onChanged: (bool? value) {
                              Haptic().light();
                              setState(() {
                                box.write('saveMediasInGallery', value!);
                              });
                            },
                          ),

                          CustomSwitchTile(
                            title: "Copier l'URL après un envoi",
                            subtitle: "Copie dans le presser-papier le lien d'un transfert lorsqu'il se termine",
                            value: box.read('copyUrlAfterSend') ?? false,
                            onChanged: (bool? value) {
                              Haptic().light();
                              setState(() {
                                box.write('copyUrlAfterSend', value!);
                              });
                            },
                          ),

                          Platform.isAndroid ? CustomSwitchTile(
                            title: "Télécharger dans un dossier",
                            subtitle: "Les fichiers seront téléchargés dans un sous-dossier nommé \"Stend\"",
                            value: box.read('downloadInSubFolder') ?? false,
                            onChanged: (bool? value) {
                              Haptic().light();
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
                          CustomSwitchTile(
                            title: "Raccourcir l'URL par défaut",
                            subtitle: "L'option pour raccourcir le lien d'un transfert sera coché au lancement",
                            value: box.read('shortenUrl') ?? false,
                            onChanged: (bool? value) {
                              Haptic().light();
                              setState(() {
                                box.write('shortenUrl', value!);
                                widget.showRefreshButton(true);
                              });
                            },
                          ),

                          CustomSwitchTile(
                            title: "Exposer un transfert par défaut",
                            subtitle: "L'option pour exposer les transferts envoyés sera coché au lancement",
                            value: box.read('exposeByDefault') ?? false,
                            onChanged: (bool? value) {
                              Haptic().light();
                              setState(() {
                                box.write('exposeByDefault', value!);
                                widget.showRefreshButton(true);
                              });
                            },
                          ),

                          ListTile(
                            title: const Text("Durée avant expiration"),
                            subtitle: const Text("Définissez la durée avant expiration par défaut d'un fichier"),
                            trailing: SettingsDropdownButton(
                              value: box.read('defaultExpirationTime') ?? '+ court',
                              hapticOnOpen: true,
                              useCupertino: widget.useCupertino,
                              items: const ['+ court', '+ long'],
                              onChanged: (String? newValue) {
                                Haptic().light();
                                setState(() {
                                  box.write('defaultExpirationTime', newValue!);
                                  widget.showRefreshButton(true);
                                });
                              },
                            ),
                            contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0, top: 2.0, bottom: 0.0),
                          ),

                          ListTile(
                            title: const Text("Page à l'ouverture"),
                            subtitle: const Text("Définissez la page qui s'ouvrira au démarrage de l'appli"),
                            trailing: SettingsDropdownButton(
                              value: box.read('defaultPage') ?? 'Envoyer',
                              hapticOnOpen: true,
                              useCupertino: widget.useCupertino,
                              items: const ['Envoyer', 'Télécharger', 'Réglages'],
                              onChanged: (String? newValue) {
                                Haptic().light();
                                setState(() {
                                  box.write('defaultPage', newValue!);
                                });
                              },
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
                            trailing: SettingsDropdownButton(
                              value: box.read('theme') ?? 'Système',
                              hapticOnOpen: true,
                              useCupertino: widget.useCupertino,
                              items: const ['Système', 'Clair', 'Sombre'],
                              onChanged: (String? newValue) {
                                Haptic().light();
                                setState(() {
                                  box.write('theme', newValue!);
                                  widget.updateState();
                                });
                              },
                            ),
                            contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0, top: 2.0, bottom: 0.0),
                          ),

                          ListTile(
                            title: const Text("Icônes"),
                            subtitle: const Text("Choisissez le style d'icône utilisé"),
                            trailing: SettingsDropdownButton(
                              value: box.read('iconLib') ?? 'Material',
                              hapticOnOpen: true,
                              useCupertino: widget.useCupertino,
                              items: const ['Material', 'iOS', 'Lucide', 'Lucide (alt)'],
                              onChanged: (String? newValue) {
                                Haptic().light();
                                setState(() {
                                  box.write('iconLib', newValue!);
                                  widget.showRefreshButton(true);
                                });
                              },
                            ),
                            contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0, top: 2.0, bottom: 0.0),
                          ),

                          Platform.isIOS ? ListTile(
                            title: const Text("Choix des couleurs"),
                            subtitle: const Text("Choisissez une couleur clé qui sera utilisée dans l'appli"),
                            trailing: IconButton(
                              onPressed: () async {
                                debugPrint(box.read('appColor').toString());
                                Haptic().light();
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
                                            widget.updateState();
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

                          Platform.isIOS ? CustomSwitchTile(
                            title: "Utiliser Material You",
                            subtitle: "L'interface changera pour utiliser des composants de design Material",
                            value: box.read('useMaterialYou') ?? false,
                            onChanged: (bool? value) {
                              Haptic().light();
                              setState(() {
                                box.write('useMaterialYou', value!);
                                widget.showRefreshButton(true);
                              });
                            },
                          ) : const SizedBox.shrink(),
                        ]
                      )
                    ),
                    const SizedBox(height: 25),

                    // Méthodes d'exposition
                    Text(
                      "Méthodes d'exposition",

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
                          CustomSwitchTile(
                            title: "Votre réseau sur cette instance",
                            subtitle: "Les utilisateurs de votre instance sur la même adresse IP que vous pouerront voir vos transfert exposés",
                            value: box.read('exposeMethods_ipinstance') ?? false,
                            onChanged: (bool? value) {
                              Haptic().light();
                              setState(() {
                                box.write('exposeMethods_ipinstance', value!);
                                widget.showRefreshButton(true);
                              });
                            },
                          ),

                          CustomSwitchTile(
                            title: "À proximité de vous",
                            subtitle: "Les utilisateurs ayant activé cette option verront vos transferts exposés s'ils sont proches de là où vous l'avez créé",
                            value: box.read('exposeMethods_nearby') ?? false,
                            onChanged: (bool? value) async {
                              Haptic().light();

                              if(value!) { // si on active l'option
                                var locationPermission = await checkLocationPermission();
                                if(!context.mounted) return;

                                if (locationPermission != true) {
                                  Haptic().warning();
                                  showSnackBar(context, locationPermission, useCupertino: widget.useCupertino);
                                } else {
                                  Haptic().light();
                                  setState(() {
                                    box.write('exposeMethods_nearby', true);
                                  });
                                  widget.showRefreshButton(true);
                                }

                              } else { // si on l'a désactive
                                setState(() {
                                  box.write('exposeMethods_nearby', false);
                                });
                                widget.showRefreshButton(true);
                              }
                            },
                          ),

                          CustomSwitchTile(
                            title: "S'authentifier avec Google",
                            subtitle: "Vous retrouverez vos transferts exposés sur tous vos appareils connectés à ce compte",
                            value: box.read('exposeMethods_account') ?? false,
                            onChanged: (bool? value) {
                              Haptic().light();
                              setState(() {
                                if(value!) {
                                  globalserver.openAuthGoogle();
                                } else {
                                  globalserver.logout();
                                }
                              });
                            },
                          ),
                        ]
                      )
                    ),
                    const SizedBox(height: 25),

                    // Votre compte Stend
                    _isGlobalAccountConnected ? Text(
                      "Votre compte Stend",

                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onPrimaryContainer
                      )
                    ) : const SizedBox.shrink(),
                    SizedBox(height: _isGlobalAccountConnected ? 6 : 0),

                    _isGlobalAccountConnected ? Theme(
                      data: Theme.of(context).copyWith(
                        splashFactory: NoSplash.splashFactory,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            title: const Text("Identifiant de votre compte"),
                            subtitle: Text("L'identifiant unique de votre compte est : ${box.read('exposeAccountId') ?? '<introuvable>'}"),
                            contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0, top: 2.0, bottom: 0.0),
                          ),

                          ListTile(
                            title: const Text("Effacer les sessions"),
                            subtitle: const Text("Déconnecte tous les appareils connectés à ce compte"),
                            trailing: IconButton(
                              onPressed: () async {
                                actionsDialog(
                                  context,
                                  title: 'Effacer les sessions ?',
                                  content: 'Vous serez déconnecté de ce compte sur tous vos appareils connectés, à l\'exception de celui-ci.',
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Haptic().light();
                                        Navigator.of(context).pop();
                                      },
                                      child: const Text("Annuler"),
                                    ),

                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        globalserver.resetToken(hapticFeedback: true).then((res) => showSnackBar(context, res['value'], icon: res['icon'], useCupertino: widget.useCupertino));
                                      },
                                      child: const Text("Confirmer"),
                                    )
                                  ],
                                );
                              },
                              icon: const Icon(Icons.delete_forever),
                            ),
                            contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0, top: 2.0, bottom: 0.0),
                          ),

                          ListTile(
                            title: const Text("Supprimer ce compte"),
                            subtitle: const Text("Supprime définitivement ce compte et toutes les données associées à celui-ci"),
                            trailing: IconButton(
                              onPressed: () async {
                                actionsDialog(
                                  context,
                                  title: 'Supprimer ce compte ?',
                                  content: "Vous serez déconnecté sur tous vos appareils connectés et vos transferts exposés seront supprimés dans moins d'une heure. Vous pourrez vous réinscrire.",
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Haptic().light();
                                        Navigator.of(context).pop();
                                      },
                                      child: const Text("Annuler"),
                                    ),

                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        globalserver.deleteAccount(hapticFeedback: true).then((res) => showSnackBar(context, res['value'], icon: res['icon'], useCupertino: widget.useCupertino));
                                      },
                                      child: const Text("Confirmer"),
                                    )
                                  ],
                                );
                              },
                              icon: const Icon(Icons.delete_forever),
                            ),
                            contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0, top: 2.0, bottom: 0.0),
                          )
                        ]
                      )
                    ) : const SizedBox.shrink(),
                    SizedBox(height: _isGlobalAccountConnected ? 25 : 0),

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
                          CustomSwitchTile(
                            title: "Désactiver l'historique",
                            subtitle: "Empêche Stend d'ajouter de nouveaux liens à l'historique de transferts",
                            value: box.read('disableHistory') ?? false,
                            onChanged: (bool? value) {
                              Haptic().light();
                              setState(() {
                                box.write('disableHistory', value!);
                                widget.showRefreshButton(true);
                              });
                            },
                          ),

                          ListTile(
                            title: const Text("Service d'URLs courts"),
                            subtitle: const Text("Définissez le service utilisé pour racourcir les URLs"),
                            trailing: SettingsDropdownButton(
                              value: box.read('shortenService') ?? 'mdrr.fr',
                              hapticOnOpen: true,
                              useCupertino: widget.useCupertino,
                              items: const ['mdrr.fr', 'ptdrr.com', 's.3vm.cl', 's.erc.hr'],
                              onChanged: (String? newValue) {
                                Haptic().light();
                                setState(() {
                                  box.write('shortenService', newValue!);
                                });
                              },
                            ),
                            contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0, top: 2.0, bottom: 0.0),
                          ),

                          ListTile(
                            title: const Text("Caméra pour les QR Codes"),
                            subtitle: const Text("Définissez la caméra qui sera utilisée pour scanner les QR Codes"),
                            trailing: SettingsDropdownButton(
                              value: box.read('cameraFacing') ?? 'Arrière',
                              hapticOnOpen: true,
                              useCupertino: widget.useCupertino,
                              items: const ['Arrière', 'Avant'],
                              onChanged: (String? newValue) {
                                Haptic().light();
                                setState(() {
                                  box.write('cameraFacing', newValue!);
                                });
                              },
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
                          child: const Text("État des services"),
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
                            child: const Text("État des services"),
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
                        onPressed: () => askResetSettings(),
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
                      // Textes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,

                        children: [
                          Text("Stend Mobile${appVersion != null ? ' v$appVersion' : ''} ", textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black)),
                          GestureDetector(
                            onTap: () {
                              Haptic().light();
                              launchUrl(Uri.parse('https://stend.johanstick.fr/mobile-docs/release-type#release-${storeRelease ? 'store' : 'libre'}'), mode: LaunchMode.inAppBrowserView);
                            },
                            child: Text(" (${storeRelease ? 'Release Store' : 'Release Libre'})", textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black))
                          )
                        ],
                      ),
                      Text("Développé par Johan", textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black)),

                      const SizedBox(height: 2),

                      // Liens
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () {
                              Haptic().light();
                              launchUrl(Uri.parse('https://stend.johanstick.fr'), mode: LaunchMode.externalApplication);
                            },
                            icon: const Icon(LucideIcons.globe),
                            color: Theme.of(context).colorScheme.secondary
                          ),
                          IconButton(
                            onPressed: () {
                              Haptic().light();
                              launchUrl(Uri.parse('https://github.com/hoststend/stend-mobile'), mode: LaunchMode.externalApplication);
                            },
                            icon: const Icon(LucideIcons.github),
                            color: Theme.of(context).colorScheme.secondary
                          ),
                          IconButton(
                            onPressed: () {
                              Haptic().light();
                              launchUrl(Uri.parse('https://twitter.com/johan_stickman'), mode: LaunchMode.externalApplication);
                            },
                            icon: const Icon(LucideIcons.twitter),
                            color: Theme.of(context).colorScheme.secondary
                          ),
                          IconButton(
                            onPressed: () {
                              Haptic().light();
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