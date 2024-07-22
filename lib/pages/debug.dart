import 'dart:convert';

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:stendmobile/utils/send_notification.dart';
import 'package:stendmobile/utils/show_snackbar.dart';
import 'package:stendmobile/utils/user_agent.dart';
import 'package:stendmobile/utils/haptic.dart';
import 'package:stendmobile/utils/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file_manager/open_file_manager.dart';
import 'package:highlight/languages/json.dart';
import 'package:flutter_highlight/themes/gruvbox-light.dart';
import 'package:flutter_highlight/themes/gruvbox-dark.dart';

class DebugPage extends StatefulWidget {
  final Function refresh;
  final bool useCupertino;

  const DebugPage({Key? key, required this.refresh, required this.useCupertino}) : super(key: key);

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

  void showCustomSnackbar(bool useCupertino) async {
    var text = await showTextInputDialog(
      context: context,
      title: 'Snackbar personnalisé',
      message: "Entrer un texte à afficher dans une snackbar personnalisé",
      okLabel: 'Valider',
      cancelLabel: 'Annuler',
      textFields: const [
        DialogTextField(
          autocorrect: true,
          keyboardType: TextInputType.text
        ),
      ],
    );

    if(!mounted) return;
    if (text != null) showSnackBar(context, text.single, icon: 'info', useCupertino: useCupertino);
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

  /* Note:
  - Entre chaque élément, espace de 12 pixels
  - En bas de la page, espace de 10 pixels
  - À la fin d'un section, 32 pixels pour des boutons, 25 pixels pour une SwitchListTile
  - Après un titre : 16 pixels pour des boutons, 12 pixels pour une SwitchListTile
  */

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
                padding: const EdgeInsets.only(top: 10.0, left: 14.0, right: 14.0, bottom: 14.0),

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
                              var userAgent = await deviceUserAgent();
                              if(!context.mounted) return;
                              showSnackBar(context, userAgent);
                            },
                            child: const Text("Agent utilisateur"),
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
                              launchUrl(Uri.parse('https://stend.johanstick.fr'), mode: LaunchMode.externalApplication);
                            },
                            child: const Text("Ouvrir un lien"),
                          )
                        )
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Snackbars
                    Text(
                      "Snackbars",

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
                              showCustomSnackbar(false);
                            },
                            child: const Text("Custom Material"),
                          )
                        ),

                        const SizedBox(width: 12.0),

                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              showCustomSnackbar(true);
                            },
                            child: const Text("Custom Cupertino"),
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
                              showSnackBar(context, "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed vestibulum venenatis...", icon: 'info', useCupertino: widget.useCupertino);
                            },
                            child: const Text("Ex. info"),
                          )
                        ),

                        const SizedBox(width: 12.0),

                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              showSnackBar(context, "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed vestibulum venenatis...", icon: 'success', useCupertino: widget.useCupertino);
                            },
                            child: const Text("Ex. succès"),
                          )
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [

                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              showSnackBar(context, "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed vestibulum venenatis...", icon: 'warning', useCupertino: widget.useCupertino);
                            },
                            child: const Text("Ex. warning"),
                          )
                        ),

                        const SizedBox(width: 12.0),

                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              showSnackBar(context, "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed vestibulum venenatis...", icon: 'error', useCupertino: widget.useCupertino);
                            },
                            child: const Text("Ex. erreur"),
                          )
                        )
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Exposition des transferts
                    Text(
                      "Exposition des transferts",

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
                              var locationPermission = await checkLocationPermission();
                              if(!context.mounted) return;
                              if (locationPermission != true) {
                                showSnackBar(context, locationPermission, useCupertino: widget.useCupertino);
                              } else {
                                showSnackBar(context, "Tout est prêt !", icon: "success", useCupertino: widget.useCupertino);
                              }
                            },
                            child: const Text("Perm. pos."),
                          )
                        ),

                        const SizedBox(width: 12.0),

                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              try {
                                var position = await getCurrentPosition();
                                if(!context.mounted) return;
                                debugPrint(position.toString());
                                showSnackBar(context, "Position actuelle : ${position.latitude}, ${position.longitude}", icon: "success", useCupertino: widget.useCupertino);
                              } catch (e) {
                                debugPrint(e.toString());
                                showSnackBar(context, e.toString(), icon: "error", useCupertino: widget.useCupertino);
                              }
                            },
                            child: const Text("Position"),
                          )
                        )
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Retours haptiques
                    Text(
                      "Retours haptiques",

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
                              Haptic().light();
                            },
                            child: const Text("Micro"),
                          )
                        ),

                        const SizedBox(width: 12.0),

                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              Haptic().success();
                            },
                            child: const Text("Succès"),
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
                              Haptic().warning();
                            },
                            child: const Text("Warning"),
                          )
                        ),

                        const SizedBox(width: 12.0),

                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              Haptic().error();
                            },
                            child: const Text("Erreur"),
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
                              box.remove('tips');
                            },
                            child: const Text("Reset tips"),
                          )
                        ),

                        const SizedBox(width: 12.0),

                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              widget.refresh();
                            },
                            child: const Text("Reload"),
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

                    // Type de release
                    Text(
                      "Type de release",

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
                          SwitchListTile.adaptive(
                            title: const Text("Forcer la version libre"),
                            subtitle: const Text("Réactive les fonctionnalités désactivées dans la version publiée sur les stores"),
                            value: box.read('forceStore') ?? false,
                            contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0, top: 2.0, bottom: 0.0),
                            onChanged: (bool? value) {
                              Haptic().light();
                              setState(() {
                                box.write('forceStore', value!);
                              });
                            },
                          ),
                        ]
                      )
                    ),
                    const SizedBox(height: 25),

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