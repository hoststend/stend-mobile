import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:stendmobile/utils/send_notification.dart';
import 'package:stendmobile/utils/show_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file_manager/open_file_manager.dart';
import 'package:highlight/languages/json.dart';
import 'package:flutter_highlight/themes/gruvbox-light.dart';
import 'package:flutter_highlight/themes/gruvbox-dark.dart';

class DebugPage extends StatefulWidget {
  final Function refresh;

  const DebugPage({Key? key, required this.refresh}) : super(key: key);

  @override
  State<DebugPage> createState() => _DebugPageState();
}

final box = GetStorage();

final codeController = CodeController(
  text: 'Chargement...',
  language: json,
);

class _DebugPageState extends State<DebugPage> {
  @override
  void initState() {
    super.initState();

    var jsonSettings = exportSettingsToJson();
    setState(() {
      codeController.fullText = jsonSettings;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  String exportSettingsToJson() {
    // Obtenir les clés et les valeurs
    var keys = box.getKeys();
    var values = box.getValues();

    // Convertir les itérables en listes valides
    keys = keys.toList();
    values = values.toList();

    // Créer un objet avec les clés et les valeurs
    Map<String, dynamic> settings = {};
    for (var key in keys) {
      int index = keys.indexOf(key);
      settings[key] = values[index];
    }

    // Retourner l'objet en JSON
    String json = const JsonEncoder.withIndent('  ').convert(settings);
    return json;  
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
                  "Réglages de débogage",

                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black,
                  )
                )
              ),

              // Padding principal
              Padding(
                padding: const EdgeInsets.only(left: 14.0, right: 14.0, bottom: 14.0),

                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    // Actions de test
                    Text(
                      "Actions de test",

                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onPrimaryContainer
                      )
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              askNotifPermission();
                            },
                            child: const Text("Perm. notif"),
                          )
                        ),

                        const SizedBox(width: 12.0),

                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              showSnackBar(context, "Une notif. sera affichée dans 4 secondes si l'app est en arrière plan");
                              await Future.delayed(const Duration(seconds: 4));
                              sendBackgroundNotif("Téléchargement terminé", "Ceci est un exemple, cliquer pour ouvrir l'explorateur de fichiers !", "download", "open-downloads");
                            },
                            child: const Text("Envoyer notif."),
                          )
                        )
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              // TODO: on affichera le sdk + les informations de l'appareil qu'on utilisera pour build le user agent
                            },
                            child: const Text("Infos appareil"),
                          )
                        ),

                        const SizedBox(width: 12.0),

                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              PackageInfo packageInfo = await PackageInfo.fromPlatform();
                              if(!context.mounted) return;
                              showSnackBar(context, "Version : ${packageInfo.version} (${packageInfo.buildNumber}), installée via ${packageInfo.installerStore}");
                            },
                            child: const Text("Infos package"),
                          )
                        )
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              openFileManager(androidConfig: AndroidConfig(folderType: FolderType.download));
                            },
                            child: const Text("Ouvrir Fichiers"),
                          )
                        ),

                        const SizedBox(width: 12.0),

                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              launchUrl(Uri.parse('https://stend-docs.johanstick.fr'), mode: LaunchMode.externalApplication);
                            },
                            child: const Text("Ouvrir un lien"),
                          )
                        )
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              HapticFeedback.lightImpact();
                            },
                            child: const Text("Light"),
                          )
                        ),

                        const SizedBox(width: 12.0),

                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              HapticFeedback.mediumImpact();
                            },
                            child: const Text("Medium"),
                          )
                        ),

                        const SizedBox(width: 12.0),

                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              HapticFeedback.heavyImpact();
                            },
                            child: const Text("Heavy"),
                          )
                        )
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Actions sur le long terme
                    Text(
                      "Actions sur le long terme",

                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onPrimaryContainer
                      )
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              widget.refresh();
                            },
                            child: const Text("Reload"),
                          )
                        ),

                        const SizedBox(width: 12.0),

                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              throw Exception("Plantage sur demande suite à un appui sur le bouton Crash dans les réglages de débogage");
                            },
                            child: const Text("Crash"),
                          )
                        )
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              try {
                                var tempDir = await getTemporaryDirectory();
                                if (tempDir.existsSync()) {
                                  if(!context.mounted) return;
                                  showSnackBar(context, "Dossier temporaire trouvé ! Suppression de celui-ci...");
                                  tempDir.deleteSync(recursive: true);
                                } else {
                                  if(!context.mounted) return;
                                  showSnackBar(context, "Aucun dossier temporaire n'a été trouvé");
                                }
                              } catch (e) {
                                debugPrint(e.toString());
                                if (!context.mounted) return;
                                showSnackBar(context, e.toString());
                              }
                            },
                            child: const Text("Suppr. cache"),
                          )
                        ),

                        const SizedBox(width: 12.0),

                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              box.erase();
                            },
                            child: const Text("Suppr. config"),
                          )
                        )
                      ],
                    ),
                    const SizedBox(height: 32),


                    // Réglages de l'app en JSON
                    Text(
                      "Base de données des réglages",

                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onPrimaryContainer
                      )
                    ),
                    const SizedBox(height: 16),

                    CodeTheme(
                      data: CodeThemeData(styles: Theme.of(context).colorScheme.brightness == Brightness.dark ? gruvboxDarkTheme : gruvboxLightTheme),
                      child: 
                        CodeField(
                          controller: codeController,
                          gutterStyle: GutterStyle.none,
                          readOnly: true,
                        )
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      )
    );
	}
}