import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:stendmobile/utils/check_url.dart';
import 'package:stendmobile/utils/show_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:lucide_icons/lucide_icons.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isConnected = true;

  final box = GetStorage();

  @override
  void initState() {
    super.initState();
    _isConnected = box.read('apiInstanceUrl') != null;
  }

	@override
	Widget build(BuildContext context) {
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
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black,
                  ),
                )
              ),

              // Configuration de Stend
              !_isConnected ? Card(
                child: Column(
                  children: [
                    const ListTile(
                      title: Text("Stend n'est pas encore configuré."),
                      subtitle: Text("Pour commencer à transférer vers Stend, vous aurez besoin de vous authentifier à une instance.\n\nUne instance est un serveur sur lequel vous enverrez vos fichiers. Celui-ci aura un accès aux données que vous lui envoyez."),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(12.0),

                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              showAdaptiveDialog(
                                context: context,
                                builder: (context) => AlertDialog.adaptive(
                                  title: const Text("Configuration de Stend"),
                                  content: const Text("Stend est un service vous permettant de télécharger et envoyer des fichiers via votre propre serveur.\n\nPour pouvoir utiliser cette application, vous aurez besoin de configurer votre propre instance via les explications fournis dans la documentation."),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        Navigator.of(context).pop();
                                      },
                                      child: Text(Platform.isIOS ? "OK" : "Fermer"),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
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

                          const SizedBox(width: 8),

                          FilledButton(
                            onPressed: () async {
                              HapticFeedback.lightImpact();

                              // On récupère l'URL du client web de l'instance via un dialogue
                              final webUrl = await showTextInputDialog(
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

                              // Si on a entré une URL d'un client
                              if (webUrl != null && webUrl.toString().length > 2) {
                                if (!mounted) return;

                                var url = webUrl.single.toString();
                                if (url.toString().endsWith('//')) url = url.toString().substring(0, url.toString().length - 1);
                                if (!url.toString().endsWith('/')) url += '/';

                                if (!checkURL(webUrl.single)) {
                                  showSnackBar(context, "L'URL entrée n'est pas valide");
                                  return;
                                }

                                final urlParsed = Uri.parse(url);

                                // Vérifier que l'URL soit valide
                                if (!urlParsed.isAbsolute) {
                                  showSnackBar(context, "L'URL entrée n'est pas valide");
                                  return;
                                }
                                // Vérifier que l'URL soit accessible
                                try {
                                  final response = await http.get(urlParsed);
                                  if (response.statusCode != 200) {
                                    if (!mounted) return;
                                    showSnackBar(context, "Nous n'avons pas pu accéder à l'URL entrée");
                                    return;
                                  }
                                } catch (e) {
                                  debugPrint(e.toString());
                                  if (!mounted) return;
                                  showSnackBar(context, "Nous n'avons pas pu accéder à l'URL entrée");
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
                                textFields: const [
                                  DialogTextField(
                                    hintText: "https://stend-api.example.com",
                                    autocorrect: false,
                                    keyboardType: TextInputType.url
                                  ),
                                ],
                              );

                              // On vérifie qu'on a entré une URL d'API
                              if (!mounted) return;
                              if (apiUrl == null || apiUrl.toString().length < 2) {
                                showSnackBar(context, "Une URL d'API est nécessaire pour continuer");
                                return;
                              }

                              // On rajoute un slash et "instance" à l'URL de l'API
                              var apiUrlString = apiUrl.single.toString();
                              if (apiUrl.toString().endsWith('//')) apiUrlString = apiUrlString.substring(0, apiUrlString.length - 1);
                              if (!apiUrlString.endsWith('/')) apiUrlString += '/';
                              debugPrint(apiUrlString);
                              var apiUrlStringInstance = '${apiUrlString}instance';

                              // On vérifie que l'URL de l'API soit valide
                              if (!checkURL(apiUrlStringInstance)) {
                                showSnackBar(context, "L'URL de l'API semble invalide");
                                return;
                              }

                              final url = Uri.parse(apiUrlStringInstance);

                              // Vérifier que l'URL soit valide
                              if (!mounted) return;
                              if (!url.isAbsolute) {
                                showSnackBar(context, "L'URL entrée n'est pas valide");
                                return;
                              }

                              // Une fois la requête terminé
                              try {
                                // Vérifier que l'URL soit accessible
                                final response = await http.get(url);
                                if (response.statusCode != 200) {
                                  if (!mounted) return;
                                  showSnackBar(context, "La requête n'a pas abouti. Vérifier l'URL");
                                  return;
                                }

                                // Parse la réponse
                                final Map<String, dynamic> jsonData = json.decode(utf8.decode(response.bodyBytes));

                                // Définir certaines données dans les préférences
                                box.write('requirePassword', jsonData['requirePassword']);
                                box.write('recommendedExpireTimes', jsonData['recommendedExpireTimes']);
                              } catch (e) {
                                if (!mounted) return;
                                showSnackBar(context, "Nous n'avons pas pu accéder à l'URL entrée");
                                debugPrint(e.toString());
                                return;
                              }

                              // Si on a besoin de s'autentifier
                              if (box.read('requirePassword') ?? false) {
                                if (!mounted) return;
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
                                  if (!mounted) return;
                                  try {
                                    if (jsonData['success']) {
                                      box.write('apiInstanceUrl', apiUrlString);
                                      box.write('apiInstancePassword', passwordString);
                                      setState(() {
                                        _isConnected = true;
                                      });
                                      HapticFeedback.lightImpact();
                                      showSnackBar(context, "Vous êtes maintenant connecté à votre instance");
                                    }
                                  } catch (e) {
                                    showSnackBar(context, jsonData['message']);
                                  }
                                } else {
                                  if (!mounted) return;
                                  showSnackBar(context, "La configuration de l'API a été annulée");
                                  return;
                                }
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

              // Différents réglages
              SwitchListTile(
                title: const Text("Copier l'URL après un envoi"),
                subtitle: const Text("Copie dans le presser-papier le lien d'un transfert lorsqu'il se termine"),
                value: box.read('copyUrlAfterSend') ?? false,
                onChanged: (bool? value) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    box.write('copyUrlAfterSend', value!);
                  });
                },
              ),

              Platform.isAndroid ? SwitchListTile(
                title: const Text("Télécharger dans un dossier"),
                subtitle: const Text("Les fichiers seront téléchargés dans un sous-dossier nommé \"Stend\""),
                value: box.read('downloadInSubFolder') ?? false,
                onChanged: (bool? value) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    box.write('downloadInSubFolder', value!);
                  });
                },
              ) : const SizedBox.shrink(),

              SwitchListTile(
                title: const Text("Raccourcir l'URL par défaut"),
                subtitle: const Text("Coche par défaut l'option pour raccourcir un lien avant un envoi"),
                value: box.read('shortenUrl') ?? false,
                onChanged: (bool? value) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    box.write('shortenUrl', value!);
                  });
                },
              ),

              SwitchListTile(
                title: const Text("Désactiver l'historique"),
                subtitle: const Text("Empêche Stend d'ajouter de nouveaux liens à l'historique de transferts"),
                value: box.read('disableHistory') ?? false,
                onChanged: (bool? value) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    box.write('disableHistory', value!);
                  });
                },
              ),

              ListTile(
                title: const Text("Durée avant expiration"),
                subtitle: const Text("Définissez la durée avant expiration par défaut d'un fichier"),
                trailing: DropdownButton<String>(
                  value: box.read('defaultExpirationTime') ?? '+ court',
                  onTap: () { HapticFeedback.lightImpact(); },
                  onChanged: (String? newValue) {
                    HapticFeedback.lightImpact();
                    setState(() {
                      box.write('defaultExpirationTime', newValue!);
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
              ),

              ListTile(
                title: const Text("Thème"),
                subtitle: const Text("Choisissez le thème de l'appli"),
                trailing: DropdownButton<String>(
                  value: box.read('theme') ?? 'Système',
                  onTap: () { HapticFeedback.lightImpact(); },
                  onChanged: (String? newValue) {
                    HapticFeedback.lightImpact();
                    setState(() {
                      box.write('theme', newValue!);
                      showSnackBar(context, "Le choix sera appliqué au prochain démarrage");
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
              ),

              ListTile(
                title: const Text("Icône"),
                subtitle: const Text("Choisissez le style d'icône utilisé"),
                trailing: DropdownButton<String>(
                  value: box.read('iconLib') ?? 'Material',
                  onTap: () { HapticFeedback.lightImpact(); },
                  onChanged: (String? newValue) {
                    HapticFeedback.lightImpact();
                    setState(() {
                      box.write('iconLib', newValue!);
                      showSnackBar(context, "Le choix sera appliqué au prochain démarrage");
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
              ),

              ListTile(
                title: const Text("Page par défaut"),
                subtitle: const Text("Définissez la page qui s'ouvrira au démarrage de l'appli"),
                trailing: DropdownButton<String>(
                  value: box.read('defaultPage') ?? 'Envoyer',
                  onTap: () { HapticFeedback.lightImpact(); },
                  onChanged: (String? newValue) {
                    HapticFeedback.lightImpact();
                    setState(() {
                      box.write('defaultPage', newValue!);
                      showSnackBar(context, "Le choix sera appliqué au prochain démarrage");
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
              ),

              ListTile(
                title: const Text("Caméra pour les QR Codes"),
                subtitle: const Text("Définissez la caméra qui sera utilisée pour scanner les QR Codes"),
                trailing: DropdownButton<String>(
                  value: box.read('cameraFacing') ?? 'Arrière',
                  onTap: () { HapticFeedback.lightImpact(); },
                  onChanged: (String? newValue) {
                    HapticFeedback.lightImpact();
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
              ),

              // Boutons d'actions
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton(
                    onPressed: () async {
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
                      HapticFeedback.lightImpact();
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
                                HapticFeedback.lightImpact();
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
                          if (!mounted) return;
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
                          if (!mounted) return;
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
                                HapticFeedback.lightImpact();
                                Navigator.of(context).pop();
                              },
                              child: Text(Platform.isIOS ? "OK" : "Fermer"),
                            )
                          ],
                        )
                      );
                    },
                    child: const Text("Vérifier l'instance"),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      box.remove('historic');
                      showSnackBar(context, "L'historique a été effacé");
                    },
                    child: const Text("Effacer l'historique"),
                  )
                ],
              ),

              const SizedBox(height: 8),

              Center(
                child: FilledButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    showAdaptiveDialog(
                      context: context,
                      builder: (context) => AlertDialog.adaptive(
                        title: Text(_isConnected ? "Se déconnecter" : "Effacer les réglages"),
                        content: Text("Êtes-vous sûr de vouloir vous déconnecter ? ${(box.read('apiInstancePassword') != null && box.read('apiInstancePassword').isNotEmpty) ? "Assurez-vous de connaître le mot de passe de cette instance pour vous reconnecter." : "Cette action est irréversible."}"),
                        actions: [
                          TextButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
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
                                if (!mounted) return;
                                showSnackBar(context, "Impossible d'effacer le cache");
                              }

                              // Informer l'utilisateur
                              if (!mounted) return;
                              HapticFeedback.mediumImpact();
                              Navigator.of(context).pop();
                              showSnackBar(context, _isConnected ? "Vous êtes maintenant déconnecté" : "Les réglages ont été effacées");

                              setState(() {
                                _isConnected = false;
                              });
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

              const SizedBox(height: 10),

              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      // Texte
                      Text(
                        "Stend Mobile ― Développé par Johan",
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
                              HapticFeedback.lightImpact();
                              launchUrl(Uri.parse('https://github.com/johan-perso/stend-mobile'), mode: LaunchMode.externalApplication);
                            },
                            icon: const Icon(LucideIcons.github),
                          ),
                          IconButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              launchUrl(Uri.parse('https://twitter.com/johan_stickman'), mode: LaunchMode.externalApplication);
                            },
                            icon: const Icon(LucideIcons.twitter),
                          ),
                          IconButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              launchUrl(Uri.parse('https://johanstick.fr'), mode: LaunchMode.externalApplication);
                            },
                            icon: const Icon(LucideIcons.globe),
                          ),
                          IconButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              launchUrl(Uri.parse('https://ko-fi.com/johan_stickman'), mode: LaunchMode.externalApplication);
                            },
                            icon: const Icon(LucideIcons.circleDollarSign),
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