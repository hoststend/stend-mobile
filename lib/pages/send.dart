import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:stendmobile/utils/format_bytes.dart';
import 'package:stendmobile/utils/show_snackbar.dart';
import 'package:stendmobile/utils/user_agent.dart';
import 'package:stendmobile/utils/send_notification.dart';
import 'package:stendmobile/utils/limit_string_size.dart';
import 'package:stendmobile/utils/check_connectivity.dart';
import 'package:stendmobile/utils/haptic.dart';
import 'package:stendmobile/utils/geolocator.dart';
import 'package:stendmobile/utils/global_server.dart' as globalserver;
import 'package:stendmobile/utils/globals.dart' as globals;
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:tuple/tuple.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class UploadDialog extends StatefulWidget {
  final bool useCupertino;
  final String content;
  final double? value;
  final String? details;

  const UploadDialog({Key? key, required this.useCupertino, required this.content, this.value, this.details}) : super(key: key);

  @override
  UploadDialogState createState() => UploadDialogState();
}

class UploadDialogState extends State<UploadDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog.adaptive(
      title: const Text("Envoi en cours"),
      content: Column(
        mainAxisSize: MainAxisSize.min,

        children: [
          !widget.useCupertino ? Text(widget.content, textAlign: TextAlign.center) : widget.useCupertino && widget.details != null ? Text(widget.details!, textAlign: TextAlign.center) : const SizedBox(),

          const SizedBox(height: 12.0),
          LinearProgressIndicator(value: widget.value),
          const SizedBox(height: 12.0),
          widget.useCupertino ? Text(widget.content) : !widget.useCupertino && widget.details != null ? Text(widget.details!) : const SizedBox(),
        ],
      ),
    );
  }
}

class SendPage extends StatefulWidget {
  final bool useCupertino;

  const SendPage({Key? key, required this.useCupertino}) : super(key: key);

  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> with AutomaticKeepAliveClientMixin {
  final box = GetStorage();

  final TextEditingController shareKeyController = TextEditingController();
  bool shortUrl = false;
  bool exposeTransfert = false;
  late String iconLib;

  int selectedExpireTime = 0;
  List selectedFiles = [];

  final StreamController<Tuple3<String, double?, String?>> uploadAlertStreamController = StreamController<Tuple3<String, double?, String?>>.broadcast();
  Tuple3<String, double?, String?> uploadAlertTupple = const Tuple3("Préparation...", null, null);

  @override
  void initState() {
    if (box.read('shortenUrl') == true) shortUrl = true;
    if (box.read('exposeByDefault') == true) exposeTransfert = true;
    iconLib = box.read('iconLib') ?? (Platform.isIOS ? 'Lucide' : 'Material');

    if(box.read('recommendedExpireTimes') != null && box.read('recommendedExpireTimes').isNotEmpty) {
      selectedExpireTime = box.read('defaultExpirationTime') == '+ court'
      ? 0
      : box.read('defaultExpirationTime') == '+ long'
        ? box.read('recommendedExpireTimes').length - 1
        : 0;
    }

    super.initState();
    globals.indicatePageInitialized('send');

    globals.intereventsStreamController.stream.listen((event) {
      if (event['type'] == 'open-send-picker') {
        openPicker(event['picker']);
      } else if (event['type'] == 'add-files-to-selection') {
        setState(() {
          for (var file in event['files']) {
            selectedFiles.add(file);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  void openPicker(String picker) async {
    Haptic().light();

    if (picker == 'files') {
      FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result != null) {
        setState(() {
          for (var file in result.files) {
            selectedFiles.add(File(file.path!));
          }
        });
      }
    } else if (picker == 'images') {
      try {
        List<XFile> files = await ImagePicker().pickMultiImage();
        setState(() {
          for (var xfile in files) {
            File file = File(xfile.path);
            selectedFiles.add(file);
          }
        });
      } catch (e) {
        debugPrint(e.toString());
        if (!mounted) return;
        Haptic().error();
        showSnackBar(context, "Impossible d'ouvrir la galerie d'images. Vérifier les permissions de l'app", icon: "error", useCupertino: widget.useCupertino);
      }
    } else if (picker == 'videos') {
      try {
        XFile? video = await ImagePicker().pickVideo(source: ImageSource.gallery);
        if (video == null) return;
        File file = File(video.path);
        setState(() {
          selectedFiles.add(file);
        });
      } catch (e) {
        debugPrint(e.toString());
        if (!mounted) return;
        Haptic().error();
        showSnackBar(context, "Impossible d'ouvrir la galerie de vidéos. Vérifier les permissions de l'app", icon: "error", useCupertino: widget.useCupertino);
      }
    } else if (picker == 'camera') {
      XFile? image = await ImagePicker().pickImage(source: ImageSource.camera);
      if (image == null) return;
      File file = File(image.path);
      setState(() {
        selectedFiles.add(file);
      });
    }
  }

  void sendFile() async {
    // Vérifier l'accès à internet
    bool connectivity = await checkConnectivity();
    if (!mounted) return;
    if (!connectivity) {
      Haptic().warning();
      showSnackBar(context, "Vous n'êtes pas connecté à internet, vérifiez votre connexion et réessayez", icon: "warning", useCupertino: widget.useCupertino);
      return;
    }

    // Obtenir des variables depuis les réglages
    bool disableHistory = box.read('disableHistory') ?? false;
    bool copyUrlAfterSend = box.read('copyUrlAfterSend') ?? false;
    String shortenService = box.read('shortenService') ?? 'mdrr.fr';
    String webInstanceUrl = box.read('webInstanceUrl') ?? '';
    String apiInstanceUrl = box.read('apiInstanceUrl') ?? '';
    final apiInstancePassword = box.read('apiInstancePassword');
    int fileMaxSize;
    int maxTransfersInMerge;
    bool requirePassword;
    List historic = box.read('historic') ?? [];

    // Haptic
    Haptic().light();

    // Vérifier que l'instance est configurée
    if (apiInstanceUrl.isEmpty || apiInstanceUrl.length < 8 || !apiInstanceUrl.startsWith('http')) {
      showSnackBar(context, "Vous devez vous connecter à une instance depuis les réglages", icon: "warning", useCupertino: widget.useCupertino);
      Haptic().warning();
      return;
    }

    // Méthodes d'exposition
    Map exposeMethods = {};
    String posLongitude = '';
    String posLatitude = '';
    if (exposeTransfert) {
      // Obtenir les méthodes activées
      exposeMethods = {
        'exposeMethods_ipinstance': box.read('exposeMethods_ipinstance') ?? false,
        'exposeMethods_nearby': box.read('exposeMethods_nearby') ?? false,
        'exposeMethods_account': box.read('exposeMethods_account') ?? false,
        'exposeAccountToken': box.read('exposeAccountToken') ?? '',
      };

      // Si aucune méthode n'est activée, on affiche un message d'erreur
      if (!exposeMethods.containsValue(true)) {
        showSnackBar(context, "Vous devez activer au moins une méthode d'exposition depuis les réglages", icon: "warning", useCupertino: widget.useCupertino);
        Haptic().warning();
        return;
      }

      // Si la méthode d'exposition par compte est activée, on vérifie que le token est valide
      if (exposeMethods['exposeMethods_account'] && exposeMethods['exposeAccountToken'].isEmpty) {
        globalserver.logout();
        showSnackBar(context, "Vous n'êtes pas correctement connecté, ouvrez les réglages pour vous reconnecter", icon: "warning", useCupertino: widget.useCupertino);
        Haptic().warning();
        return;
      } else if (exposeMethods['exposeMethods_account']) {
        var checkaccount = await globalserver.getAccount();
        debugPrint('getAccount response from global server: $checkaccount');
        if (!checkaccount['success']) {
          globalserver.logout();
          if (!mounted) return;
          showSnackBar(context, "Vous avez été déconnecté, ouvrez les réglages pour vous reconnecter", icon: "warning", useCupertino: widget.useCupertino);
          Haptic().warning();
          return;
        }
      }

      // Si la méthode d'exposition par proximité est activée, on récupère la position de l'utilisateur
      if (exposeMethods['exposeMethods_nearby']) {
        // Demander la permission
        var locationPermission = await checkLocationPermission();
        if (!mounted) return;
        if (locationPermission != true) {
          showSnackBar(context, locationPermission, icon: "warning", useCupertino: widget.useCupertino);
          Haptic().warning();
          return;
        }

        // Obtenir la position de l'utilisateur
        try {
          var position = await getCurrentPosition();
          if(!mounted) return;
          debugPrint(position.toString());
          posLongitude = position.longitude.toString();
          posLatitude = position.latitude.toString();
        } catch (e) {
          debugPrint(e.toString());
          showSnackBar(context, e.toString(), icon: "error", useCupertino: widget.useCupertino);
          Haptic().error();
          return;
        }

        // Si la position n'a pas pu être obtenue, on arrête
        if (posLongitude.isEmpty || posLatitude.isEmpty){
          showSnackBar(context, "Impossible d'obtenir votre position, vérifiez les permissions de l'app", icon: "warning", useCupertino: widget.useCupertino);
          Haptic().warning();
          return;
        }
      }
    }

    // Si les URLs se termine par un slash, les retirer
    if (apiInstanceUrl.endsWith('/')) apiInstanceUrl = apiInstanceUrl.substring(0, apiInstanceUrl.length - 1);
    if (webInstanceUrl.endsWith('/')) webInstanceUrl = webInstanceUrl.substring(0, webInstanceUrl.length - 1);

    // Créer une instance Dio
    final dio = Dio(BaseOptions(
      headers: {
        'User-Agent': await deviceUserAgent(),
        'Authorization': apiInstancePassword ?? ''
      },
      contentType: Headers.jsonContentType,
      connectTimeout: const Duration(milliseconds: 7000),
      sendTimeout: const Duration(milliseconds: 7000),
      receiveTimeout: const Duration(milliseconds: 7000),
      validateStatus: (status) {
        return true;
      }
    ));

    // Déterminer la valeur du temps avant expiration
    int selectedExpireTimeValue = box.read('recommendedExpireTimes')[selectedExpireTime]['inSeconds'];

    // On affiche le dialogue de chargement
    uploadAlertTupple = const Tuple3("Préparation...", null, null);
    if (!mounted) return;
    showAdaptiveDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return StreamBuilder(
          stream: uploadAlertStreamController.stream,
          initialData: uploadAlertTupple,
          builder: (BuildContext context, AsyncSnapshot snapshot) {
            String content = snapshot.data.item1;
            double? value = snapshot.data.item2;
            String? details = snapshot.data.item3;
            return PopScope(
              canPop: false,
              child: UploadDialog(useCupertino: widget.useCupertino, content: content, value: value, details: details)
            );
          }
        );
      }
    );

    // Vérifier les infos de l'instance
    Response response;
    try {
      response = await dio.get('$apiInstanceUrl/instance');
    } catch (e) {
      if (!mounted) return;
      debugPrint(e.toString());
      Haptic().warning();
      showSnackBar(context, "Impossible de se connecter à l'instance", icon: "warning", useCupertino: widget.useCupertino);
      Navigator.pop(context);
      return;
    }

    // On vérifie le code de statut
    if (!mounted) return;
    if (response.statusCode != 200) {
      showSnackBar(context, "L'instance a retourné une erreur HTTP ${response.statusCode}", icon: "error", useCupertino: widget.useCupertino);
      Navigator.pop(context);
      Haptic().error();
      return;
    }

    // Enregistrer des détails sur l'instance
    fileMaxSize = response.data['fileMaxSize'];
    maxTransfersInMerge = response.data['maxTransfersInMerge'];
    requirePassword = response.data['requirePassword'];

    // Si l'instance demande un mot de passe, vérifier qu'il est configuré
    if (requirePassword && apiInstancePassword == null) {
      showSnackBar(context, "Cette instance requiert un mot de passe, veuillez vous reauthentifier depuis les réglages", icon: "error", useCupertino: widget.useCupertino);
      box.remove('apiInstanceUrl');
      box.remove('apiInstancePassword');
      Navigator.pop(context);
      Haptic().error();
      return;
    }

    // Vérifier que l'on ne dépasse pas la limite de fichiers
    if (selectedFiles.length > maxTransfersInMerge) {
      showSnackBar(context, "Vous ne pouvez pas envoyer plus de $maxTransfersInMerge fichiers", icon: "warning", useCupertino: widget.useCupertino);
      Navigator.pop(context);
      Haptic().warning();
      return;
    }

    // Vérifier la taille des fichiers
    for (var file in selectedFiles) {
      var fileSize = file.lengthSync();

      if (fileSize > fileMaxSize) {
        showSnackBar(context, "Un des fichiers dépasse la limite de ${formatBytes(fileMaxSize)}", icon: "warning", useCupertino: widget.useCupertino);
        Navigator.pop(context);
        Haptic().warning();
        return;
      }
      if (fileSize == 0) {
        showSnackBar(context, "Impossible d'envoyer un fichier de 0 octet", icon: "warning", useCupertino: widget.useCupertino);
        Navigator.pop(context);
        Haptic().warning();
        return;
      }
    }

    // Demander la permission d'envoyer des notifications
    askNotifPermission();

    // Empêcher l'écran de s'éteindre
    WakelockPlus.enable();

    // On passe sur chaque fichiers
    String finalAccess = '';
    List uploadedFiles = [];
    for (var file in selectedFiles) {
      // Créer un transfert
      var transfertInfo = await dio.post(
        '$apiInstanceUrl/files/create',
        data: {
          'filename': file.path.split('/').last,
          'filesize': file.lengthSync(),
          'sharekey': selectedFiles.length == 1 ? shareKeyController.text : null,
          'expiretime': selectedExpireTimeValue
        }
      );

      // On vérifie le code de statut
      if (!mounted) return;
      if (transfertInfo.statusCode != 200 || (transfertInfo.data['message'] != null && transfertInfo.data['message'].isNotEmpty)) {
        showSnackBar(context, "Impossible de créer un transfert${transfertInfo.data['message'] != null && transfertInfo.data['message'].isNotEmpty ? ": ${transfertInfo.data['message']}" : ""}", icon: "error", useCupertino: widget.useCupertino);
        Navigator.pop(context);
        Haptic().error();
        WakelockPlus.disable();
        return;
      }

      // On détermine certaines variables
      int chunkCount = transfertInfo.data['chunks'].length;
      num alreadySentSize = 0;

      // On envoie chaque chunk
      for (int i = 0; i < chunkCount; i++) {
        // On obtient les infos du chunk
        var chunkInfo = transfertInfo.data['chunks'][i]; // int pos, bool uploaded, int size (of chunk), String uploadPath

        // On lit le chunk à partir du fichier
        Stream<List<int>> chunkStream = chunkCount == 1 ? await file.openRead() : await file.openRead(alreadySentSize, alreadySentSize + chunkInfo['size']);

        // Dio a pas l'air de bien fonctionner avec MultipartFile.fromBytes ; on crée un fichier temporaire
        String chunkPath;
        if (chunkCount == 1) {
          chunkPath = file.path;
        } else {
          uploadAlertTupple = Tuple3(uploadAlertTupple.item1, uploadAlertTupple.item2, "Tronquage temporaire du fichier...");
          uploadAlertStreamController.add(uploadAlertTupple);
          File tempFile = File('${(await getTemporaryDirectory()).path}/${file.path.split('/').last}.$i');
          await tempFile.writeAsBytes(await chunkStream.toList().then((chunks) => chunks.expand((chunk) => chunk).toList()));
          chunkPath = tempFile.path;
        }

        // On met le chunk dans un FormData
        FormData formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(chunkPath, filename: file.path.split('/').last)
        });

        // On envoie le chunk à l'API
        Response chunkResponse;
        try {
          chunkResponse = await dio.put(
            '$apiInstanceUrl${chunkInfo['uploadPath']}',
            options: Options(
              sendTimeout: const Duration(minutes: 5),
            ),
            data: formData,
            onSendProgress: (int sent, int total) {
              double progress = ((alreadySentSize as int) + sent) / file.lengthSync();
              uploadAlertTupple = Tuple3(limitStringSize(file.path.split('/').last, 64), progress, "${i + 1}/$chunkCount chunks ― ${formatBytes(alreadySentSize + sent)}/${formatBytes(file.lengthSync())}");
              uploadAlertStreamController.add(uploadAlertTupple);
            }
          );
        } catch (e) {
          debugPrint(e.toString());
          if (!mounted) return;
          showSnackBar(context, "Impossible de gérer le transfert : $e", icon: "error", useCupertino: widget.useCupertino);
          Navigator.pop(context);
          Haptic().error();
          WakelockPlus.disable();
          return;
        }

        // On vérifie le code de statut
        if (!mounted) return;
        if (chunkResponse.statusCode != 200 || (chunkResponse.data.isNotEmpty && chunkResponse.data['message'] != null && chunkResponse.data['message'].isNotEmpty)) {
          showSnackBar(context, "Impossible de gérer le transfert${chunkResponse.data['message'] != null && chunkResponse.data['message'].isNotEmpty ? ": ${chunkResponse.data['message']}" : ""}", icon: "error", useCupertino: widget.useCupertino);
          Navigator.pop(context); 
          Haptic().error();
          WakelockPlus.disable();
          return;
        }

        // On met à jour la taille déjà envoyée et la barre de progression
        alreadySentSize += chunkInfo['size'];
        uploadAlertTupple = Tuple3(limitStringSize(file.path.split('/').last, 64), alreadySentSize / file.lengthSync(), "${i + 1}/$chunkCount chunks ― ${formatBytes(alreadySentSize as int)}/${formatBytes(file.lengthSync())}");
        uploadAlertStreamController.add(uploadAlertTupple);

        // Si on a terminé d'envoyer les chunks (= la réponse n'est pas vide)
        if (chunkResponse.data.isNotEmpty) {
          // On met à jour la barre de progression
          uploadAlertTupple = Tuple3(limitStringSize(file.path.split('/').last, 64), 1.0, "Finalisation...");
          uploadAlertStreamController.add(uploadAlertTupple);

          // Ajouter tout en haut de l'historique
          if (!disableHistory) {
            historic.insert(0, {
              'date': DateTime.now().toIso8601String(),
              'filename': file.path.split('/').last,
              'filesize': file.lengthSync(),
              'expiretime': selectedExpireTimeValue,
              'filetype': chunkResponse.data['fileType'],
              'access': webInstanceUrl != 'null' ? '${webInstanceUrl.isNotEmpty ? '$webInstanceUrl/d.html?' : ''}${chunkResponse.data['shareKey']}' : chunkResponse.data['shareKey'],
              'deletekey': chunkResponse.data['deleteKey'],
              'sharekey': chunkResponse.data['shareKey'],
              'apiurl': apiInstanceUrl,
            });
            if (historic.length > 60) historic.removeAt(0); // On limite l'historique à 60 éléments
            box.write('historic', historic);
          }

          // Si on avait qu'un fichier à envoyer et qu'on a demandé un raccourcissement d'URL
          if (selectedFiles.length == 1 && shortUrl) {
            // On raccourcit l'URL
            var shortenResponse = await dio.post(
              'https://$shortenService/create',
              data: {
                'url': webInstanceUrl != 'null' ? '${webInstanceUrl.isNotEmpty ? '$webInstanceUrl/d.html?' : ''}${chunkResponse.data['shareKey']}' : chunkResponse.data['shareKey'],
                'shorturl': shareKeyController.text.isNotEmpty ? shareKeyController.text : ''
              }
            );

            // Si le lien a été raccourci avec succès, on définit l'URL finale
            if (shortenResponse.statusCode == 200 && shortenResponse.data['domain'] != null && shortenResponse.data['shorturl'] != null) {
              finalAccess = "https://${shortenResponse.data['domain']}/${shortenResponse.data['shorturl']}";
            } else {
              finalAccess = webInstanceUrl != 'null' ? '${webInstanceUrl.isNotEmpty ? '$webInstanceUrl/d.html?' : ''}${chunkResponse.data['shareKey']}' : chunkResponse.data['shareKey'];
            }
          } else {
            finalAccess = webInstanceUrl != 'null' ? '${webInstanceUrl.isNotEmpty ? '$webInstanceUrl/d.html?' : ''}${chunkResponse.data['shareKey']}' : chunkResponse.data['shareKey'];
          }

          // Ajouter le fichier à la liste des fichiers uploadé
          uploadedFiles.add({
            'sharekey': chunkResponse.data['shareKey'],
            'webUrl': webInstanceUrl.isNotEmpty ? '$webInstanceUrl/d.html?${chunkResponse.data['shareKey']}' : '',
            'filename': file.path.split('/').last,
          });
        }

        // On supprime le fichier temporaire
        if (chunkCount != 1) {
          File tempFile = File(chunkPath);
          await tempFile.delete();
        }
      }
    }

    // Si on a envoyé plusieurs fichiers
    if (selectedFiles.length > 1) {
      // On crée un groupe de liens
      var mergeResponse = await dio.post(
        '$apiInstanceUrl/files/merge',
        data: {
          'sharekey': shareKeyController.text.isNotEmpty ? shareKeyController.text : '',
          'sharekeys': uploadedFiles.map((file) => file['sharekey']).toList().join(','),
        }
      );

      // On vérifie le code de statut
      if (!mounted) return;
      if (mergeResponse.statusCode != 200 || (mergeResponse.data.isNotEmpty && mergeResponse.data['message'] != null && mergeResponse.data['message'].isNotEmpty)) {
        showSnackBar(context, "Impossible de créer un groupe de liens${mergeResponse.data['message'] != null && mergeResponse.data['message'].isNotEmpty ? ": ${mergeResponse.data['message']}" : ""}", icon: "error", useCupertino: widget.useCupertino);
        Navigator.pop(context);
        Haptic().error();
        WakelockPlus.disable();
        return;
      }

      // Si on a demandé un raccourcissement d'URL
      if (shortUrl) {
        // On raccourcit l'URL
        var shortenResponse = await dio.post(
          'https://$shortenService/create',
          data: {
            'url': webInstanceUrl != 'null' ? '${webInstanceUrl.isNotEmpty ? '$webInstanceUrl/d.html?' : ''}${mergeResponse.data['shareKey']}' : mergeResponse.data['shareKey'],
            'shorturl': shareKeyController.text.isNotEmpty ? shareKeyController.text : ''
          }
        );

        // On vérifie la réponse
        if (shortenResponse.statusCode == 200 && shortenResponse.data['domain'] != null && shortenResponse.data['shorturl'] != null) {
          finalAccess = "https://${shortenResponse.data['domain']}/${shortenResponse.data['shorturl']}";
        } else {
          finalAccess = webInstanceUrl != 'null' ? '${webInstanceUrl.isNotEmpty ? '$webInstanceUrl/d.html?' : ''}${mergeResponse.data['shareKey']}' : mergeResponse.data['shareKey'];
        }
      } else {
        finalAccess = webInstanceUrl != 'null' ? '${webInstanceUrl.isNotEmpty ? '$webInstanceUrl/d.html?' : ''}${mergeResponse.data['shareKey']}' : mergeResponse.data['shareKey'];
      }
    }

    // Copier le lien d'accès dans le presse-papier si on l'a défini
    if (finalAccess.isNotEmpty && copyUrlAfterSend) Clipboard.setData(ClipboardData(text: finalAccess));

    // Créer un transfert exposé pour chaque fichier
    if (exposeTransfert) {
      uploadAlertTupple = const Tuple3("Exposition des transferts", 1.0, "Finalisation...");
      uploadAlertStreamController.add(uploadAlertTupple);

      for (var file in uploadedFiles) {
        debugPrint('Exposing file $file');
        var exposeResponse = await globalserver.createTransfert(fileName: file['filename'], webUrl: file['webUrl'], apiInstanceUrl: apiInstanceUrl, latitude: posLatitude, longitude: posLongitude, exposeMethods: exposeMethods);
        debugPrint('Exposing response: $exposeResponse');

        if (!exposeResponse['success']) {
          uploadAlertTupple = Tuple3(limitStringSize(file['filename'], 64), 1.0, exposeResponse['value']);
          uploadAlertStreamController.add(uploadAlertTupple);
          await Future.delayed(const Duration(seconds: 3)); // laisse le temps à l'user de voir le message
        }
      }
    }

    // On ferme le dialogue de chargement
    if (!mounted) return;
    Navigator.pop(context);

    // Envoyer une notification si l'app est en arrière plan
    Haptic().success();
    sendBackgroundNotif("Transfert terminé", "${uploadedFiles.length} ${uploadedFiles.length > 1 ? "fichiers ont été envoyés" : "fichier a été envoyé"} vers Stend", "upload", null);
    WakelockPlus.disable();

    // On affiche un nouveau dialogue avec les infos d'accès (on propose d'ouvrir ou de partager)
    showAdaptiveDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog.adaptive(
          title: const Text("Transfert terminé"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Le transfert est terminé, vous pouvez accéder à vos fichiers à l'adresse suivante :"),
              const SizedBox(height: 12.0),
              Text(finalAccess, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Haptic().light();
                Navigator.pop(context);
              },
              child: Text(widget.useCupertino ? "OK" : "Fermer")
            ),
            TextButton(
              onPressed: () async {
                Haptic().light();
                Navigator.pop(context);

                final screenSize = MediaQuery.of(context).size;
                final rect = Rect.fromCenter(
                  center: Offset(screenSize.width / 2, screenSize.height / 2),
                  width: 100,
                  height: 100,
                );
                Share.share(finalAccess, sharePositionOrigin: rect);
              },
              child: const Text("Partager")
            ),
          ],
        );
      }
    );
  }

	@override
	Widget build(BuildContext context) {
    super.build(context);

		return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // Titre de la section
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Vous cherchez quelque chose ?",

                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black,
                  )
                )
              ),

              const SizedBox(height: 18.0),

              // Liste défilante de boutons "chips" pour ajouter des éléments à la sélection
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Bouton "Fichiers"
                    Padding(
                      padding: const EdgeInsets.only(right: 10.0),
                      child: OutlinedButton.icon(
                        onPressed: () => openPicker('files'),
                        icon: Icon(iconLib == 'Lucide' ? LucideIcons.file : iconLib == 'Lucide (alt)' ? LucideIcons.file : Icons.insert_drive_file),
                        label: const Text("Fichiers")
                      ),
                    ),

                    // Bouton "Images"
                    Padding(
                      padding: const EdgeInsets.only(right: 10.0),
                      child: OutlinedButton.icon(
                        onPressed: () => openPicker('images'),
                        icon: Icon(iconLib == 'Lucide' ? LucideIcons.fileImage : iconLib == 'Lucide (alt)' ? LucideIcons.image : Icons.image),
                        label: const Text("Images")
                      ),
                    ),

                    // Bouton "Vidéos"
                    Padding(
                      padding: const EdgeInsets.only(right: 10.0),
                      child: OutlinedButton.icon(
                        onPressed: () => openPicker('videos'),
                        icon: Icon(iconLib == 'Lucide' ? LucideIcons.fileVideo : iconLib == 'Lucide (alt)' ? LucideIcons.film : Icons.movie),
                        label: const Text("Vidéos")
                      ),
                    ),

                    // Bouton "Caméra" (photo)
                    Padding(
                      padding: const EdgeInsets.only(right: 10.0),
                      child: OutlinedButton.icon(
                        onPressed: () => openPicker('camera'),
                        icon: Icon(iconLib == 'Lucide' ? LucideIcons.fileVideo2 : iconLib == 'Lucide (alt)' ? LucideIcons.camera : Icons.video_camera_back),
                        label: const Text("Caméra")
                      ),
                    ),
                  ]
                )
              ),

              const SizedBox(height: 22.0),

              // Titre de la section
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Besoin de paramétrer ?",

                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black,
                  )
                )
              ),

              const SizedBox(height: 20.0),

              // Sélection de la durée de partage
              DropdownButtonFormField<int>(
                borderRadius: BorderRadius.circular(10.0),
                dropdownColor: widget.useCupertino ? Theme.of(context).colorScheme.brightness == Brightness.dark ? Colors.grey[900] : Colors.grey[200] : Theme.of(context).colorScheme.onSecondary,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "Temps avant expiration",
                ),
                value: selectedExpireTime,
                items: (box.read('recommendedExpireTimes') ?? []).asMap().entries.map<DropdownMenuItem<int>>((entry) {
                  int index = entry.key;
                  var expireTime = entry.value;
                  return DropdownMenuItem(
                    value: index,
                    key: Key(expireTime['inSeconds'].toString()),
                    child: Text(expireTime['label']),
                  );
                }).toList(),
                onTap: () { Haptic().light(); },
                onChanged: (int? value) {
                  Haptic().light();
                  setState(() {
                    selectedExpireTime = value!;
                  });
                },
              ),

              const SizedBox(height: 18.0),

              // Champ de texte pour saisir la clé de partage
              TextField(
                controller: shareKeyController,
                autocorrect: false,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "Clé de partage",
                  hintText: "Facultatif, 1 à 30 caractères"
                ),
              ),

              const SizedBox(height: 12.0),

              // Checkboxs
              Align(
                alignment: Alignment.centerLeft,
                child: SwitchListTile.adaptive(
                  title: const Text("Raccourcir l'URL finale"),
                  value: shortUrl, // valeur par défaut
                  contentPadding: const EdgeInsets.all(0.0),
                  onChanged: (bool value) {
                    Haptic().light();
                    setState(() {
                      shortUrl = value;
                    });
                  },
                )
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: SwitchListTile.adaptive(
                  title: const Text("Exposer ce transfert"),
                  value: exposeTransfert, // valeur par défaut
                  contentPadding: const EdgeInsets.all(0.0),
                  onChanged: (bool value) {
                    Haptic().light();
                    setState(() {
                      exposeTransfert = value;
                    });
                  },
                )
              ),

              const SizedBox(height: 22.0),

              // Titre de la section
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Prêt à envoyer ?",

                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black,
                  )
                )
              ),

              const SizedBox(height: 18.0),

              // Bouton pour confirmer l'envoi
              FilledButton.icon(
                onPressed: selectedFiles.isEmpty ? null : () async {
                  
                },

                icon: const Icon(Icons.navigate_next_sharp),
                label: Text("Envoyer ${selectedFiles.length} fichier")
              ),

              const SizedBox(height: 22.0),

              // Titre de la section
              selectedFiles.isNotEmpty ? Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Récapitulatif du transfert",

                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black,
                  )
                )
              ) : const SizedBox(),

              const SizedBox(height: 18.0),

              // Cartes avec les fichiers à envoyer
              ListView.builder(
                shrinkWrap: true,
                // physics: const NeverScrollableScrollPhysics(),
                primary: false,
                itemCount: selectedFiles.length,
                itemBuilder: (BuildContext context, int index) {
                  return Card(
                    child: ListTile(
                      title: Text(selectedFiles[index].path.split('/').last, overflow: TextOverflow.ellipsis, maxLines: 3),
                      subtitle: Text(formatBytes(selectedFiles[index].lengthSync())),
                      trailing: IconButton(
                        icon: Icon(iconLib == 'Lucide' ? LucideIcons.trash2 : iconLib == 'Lucide (alt)' ? LucideIcons.trash : Icons.delete),
                        onPressed: () {
                          Haptic().light();
                          setState(() {
                            selectedFiles.removeAt(index);
                          });
                        },
                      ),
                    ),
                  );
                }
              )
            ],
          ),
        ),
      )
    );
	}
}