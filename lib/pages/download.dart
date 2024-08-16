import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stendmobile/utils/format_bytes.dart';
import 'package:stendmobile/utils/format_date.dart';
import 'package:stendmobile/utils/send_notification.dart';
import 'package:stendmobile/utils/user_agent.dart';
import 'package:stendmobile/utils/show_snackbar.dart';
import 'package:stendmobile/utils/smash_account.dart';
import 'package:stendmobile/utils/check_connectivity.dart';
import 'package:stendmobile/utils/haptic.dart';
import 'package:stendmobile/utils/globals.dart' as globals;
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:get_storage/get_storage.dart';
import 'package:html/parser.dart';
import 'package:tuple/tuple.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

late Dio dio;

class DownloadDialog extends StatefulWidget {
  final bool useCupertino;
  final String content;
  final String? fileType;
  final double? value;

  const DownloadDialog({Key? key, required this.useCupertino, required this.content, this.value, this.fileType}) : super(key: key);

  @override
  DownloadDialogState createState() => DownloadDialogState();
}

class DownloadDialogState extends State<DownloadDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog.adaptive(
      title: const Text("Téléchargement"),
      content: Column(
        mainAxisSize: MainAxisSize.min,

        children: [
          widget.useCupertino ? const SizedBox() : Text(widget.content, textAlign: TextAlign.center),

          const SizedBox(height: 12.0),
          LinearProgressIndicator(value: widget.value),
          const SizedBox(height: 12.0),
          !widget.useCupertino && widget.fileType != null ? Text("Fichier : ${widget.fileType!}") : widget.useCupertino ? Text(widget.content) : const SizedBox(),
        ],
      ),
    );
  }
}

class DownloadPage extends StatefulWidget {
  final bool useCupertino;

  const DownloadPage({Key? key, required this.useCupertino}) : super(key: key);

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> with AutomaticKeepAliveClientMixin {
  final box = GetStorage();

  Function? historicBoxListener;
  late TextEditingController urlController;

  QRViewController? qrController;
  String? lastScannedCode;

  final StreamController<Tuple3<String, double?, String?>> downloadAlertStreamController = StreamController<Tuple3<String, double?, String?>>.broadcast();
  Tuple3<String, double?, String?> downloadAlertTupple = const Tuple3("Préparation...", null, null);

  List historic = [];
  List tips = [];

  late bool storeRelease;
  late String iconLib;
  late bool disableHistory;

  @override
  void initState() {
    urlController = TextEditingController();
    storeRelease = box.read('forceStore') != true && const String.fromEnvironment("storeRelease").isNotEmpty;
    iconLib = box.read('iconLib') ?? (Platform.isIOS ? 'Lucide' : 'Material');
    disableHistory = box.read('disableHistory') ?? false;

    deviceUserAgent().then((value) {
      dio = Dio(BaseOptions(
        headers: {
          'User-Agent': value,
        },
        contentType: Headers.jsonContentType,
        connectTimeout: const Duration(milliseconds: 7000),
        sendTimeout: const Duration(milliseconds: 7000),
        receiveTimeout: const Duration(milliseconds: 7000),
        validateStatus: (status) {
          return true;
        }
      ));
    });

    historic = box.read('historic') ?? [];
    historicBoxListener = box.listenKey('historic', (value) {
      debugPrint("Historic updated!");
      if (value != null) {
        historic = value;
      } else {
        historic = [];
      }
    });

    if (box.read('tips') != null) {
      tips = box.read('tips');
    } else {
      tips = [
        storeRelease ? null : "Télécharger des fichiers depuis des services tiers comme WeTransfer, Smash, TikTok ou YouTube.",
        "Appuyer longuement sur un transfert dans l'historique pour le partager, ou appuyer simplement pour le retélécharger.",
        "Personnaliser la page d'accueil et l'apparence de l'application depuis les réglages.",
        "Partager des fichiers plus rapidement avec l'exposition des transferts depuis les réglages."
      ];
      tips.removeWhere((element) => element == null);
      box.write('tips', tips);
    }

    super.initState();
    globals.indicatePageInitialized('download');

    globals.intereventsStreamController.stream.listen((event) {
      if (event['type'] == 'download') {
        urlController.text = event['url'];
        startDownload();
      } else if (event['type'] == 'open-qrcode-scanner') {
        showQrScanner();
      }
    });
  }

  @override
  void dispose() {
    urlController.dispose();
    downloadAlertStreamController.close();
    historicBoxListener?.call();

    super.dispose();
  }

  void showQrScanner() {
    Haptic().light();

    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min, // Ajouté pour prendre le moins d'espace possible

            children: [
              Expanded(
                flex: 5,
                child: QRView(
                  key: GlobalKey(debugLabel: 'QR'),
                  formatsAllowed: const [BarcodeFormat.qrcode],
                  overlay: QrScannerOverlayShape(
                    borderRadius: 10,
                    borderColor: Colors.white,
                    borderLength: 30,
                    borderWidth: 10,
                    cutOutSize: 300,
                  ),
                  cameraFacing: box.read('cameraFacing') == 'Avant' ? CameraFacing.front : CameraFacing.back,
                  onQRViewCreated: _onQRViewCreated,
                )
              )
            ]
          )
        );
      }
    );
  }

  void startDownload() async {
    // Définir des variables importantes
    String service = 'stend';
    String apiUrl = '';
    String downloadKey = urlController.text;
    String secondKey = '';
    String token = '';

    // Si l'utilisateur n'a rien entré, on arrête là
    if (downloadKey.isEmpty) {
      Haptic().warning();
      showSnackBar(context, "Veuillez entrer un lien ou une clé de partage", icon: "warning", useCupertino: widget.useCupertino);
      return;
    }

    // Vérifier l'accès à internet
    bool connectivity = await checkConnectivity();
    if (!mounted) return;
    if (!connectivity) {
      Haptic().warning();
      showSnackBar(context, "Vous n'êtes pas connecté à internet, vérifiez votre connexion et réessayez", icon: "warning", useCupertino: widget.useCupertino);
      return;
    }

    // Créer un client HTTP
    final http.Client client = http.Client();

    // Si l'input de l'utilisateur contient un espace, on cherche un lien dans le texte
    if (downloadKey.contains(' ')) {
      RegExp regExp = RegExp(r'(https?://\S+)');
      var matches = regExp.allMatches(downloadKey);
      if (matches.isNotEmpty) {
        downloadKey = matches.first.group(0)!;
      }
    }

    // Si le lien semble raccourci par Google (résultat du moteur de recherche)
    if (downloadKey.startsWith('https://www.google.com/url?') || downloadKey.startsWith('https://google.com/url?') || downloadKey.startsWith('https://google.fr/url?') || downloadKey.startsWith('http://google.fr/url?')) {
      // Parser comme une URL pour récupérer les paramètres
      Uri googleUri = Uri.parse(downloadKey);
      debugPrint("URL provenant de Google parsé");
      if (googleUri.queryParameters.containsKey('url')) {
        downloadKey = googleUri.queryParameters['url']!;
        debugPrint("URL trouvée: $downloadKey");
        debugPrint(downloadKey);
      }
    }

    // On détermine le service utilisé si c'est pas Stend
    if (downloadKey.startsWith('https://transfert.free.fr/') || downloadKey.startsWith('http://transfert.free.fr/')) {
      service = 'free';
    }
    else if (downloadKey.startsWith('https://we.tl/') || downloadKey.startsWith('http://we.tl/') || downloadKey.startsWith('https://wetransfer.com/downloads/') || downloadKey.startsWith('http://wetransfer.com/downloads/')) {
      service = 'wetransfer';
    }
    else if (downloadKey.startsWith("https://fromsmash.com/") || downloadKey.startsWith('http://fromsmash.com/')) {
      service = 'smash';
    }
    else if (downloadKey.startsWith('https://www.swisstransfer.com/d/') || downloadKey.startsWith('http://www.swisstransfer.com/d/') || downloadKey.startsWith('https://swisstransfer.com/d/') || downloadKey.startsWith('http://swisstransfer.com/d/')) {
      service = 'swisstransfer';
    }
    else if (downloadKey.startsWith('https://twitter.com/') || downloadKey.startsWith('https://mobile.twitter.com/') || downloadKey.startsWith('https://x.com/') || downloadKey.startsWith('https://vxtwitter.com/') || downloadKey.startsWith('https://fixvx.com/') || downloadKey.startsWith('https://tumblr.com/') || downloadKey.startsWith('https://www.tumblr.com/') || downloadKey.startsWith('https://tiktok.com/') || downloadKey.startsWith('https://www.tiktok.com/') || downloadKey.startsWith('https://vm.tiktok.com/') || downloadKey.startsWith('https://vt.tiktok.com/') || downloadKey.startsWith('https://instagram.com/') || downloadKey.startsWith('https://www.instagram.com/') || downloadKey.startsWith('https://www.vine.co/v/') || downloadKey.startsWith('https://vine.co/v/') || downloadKey.startsWith('https://pinterest.com/') || downloadKey.startsWith('https://www.pinterest.com/') || downloadKey.startsWith('https://pinterest.fr/') || downloadKey.startsWith('https://www.pinterest.fr/') || downloadKey.startsWith('https://pin.it/') || downloadKey.startsWith('https://streamable.com/') || downloadKey.startsWith('https://www.streamable.com/')) {
      service = 'cobalt';
    }
    else if (downloadKey.startsWith('https://bilibili.com/') || downloadKey.startsWith('https://bilibili.tv/') || downloadKey.startsWith('https://youtube.com/watch?v=') || downloadKey.startsWith('https://music.youtube.com/watch?v=') || downloadKey.startsWith('https://www.youtube.com/watch?v=') || downloadKey.startsWith('https://m.youtube.com/watch?v=') || downloadKey.startsWith('https://youtu.be/') || downloadKey.startsWith('https://youtube.com/embed/') || downloadKey.startsWith('https://youtube.com/shorts/') || downloadKey.startsWith('https://youtube.com/watch/') || downloadKey.startsWith('https://vimeo.com/') || downloadKey.startsWith('https://soundcloud.com/') || downloadKey.startsWith('https://on.soundcloud.com/') || downloadKey.startsWith('https://m.soundcloud.com/') || downloadKey.startsWith('https://twitch.tv/') || downloadKey.startsWith('https://clips.twitch.tv/') || downloadKey.startsWith('https://www.twitch.tv/') || downloadKey.startsWith('https://dailymotion.com/video/') || downloadKey.startsWith('https://www.dailymotion.com/video/') || downloadKey.startsWith('https://dai.ly/')) {
      if(storeRelease) { // sur les stores, on permet pas de télécharger depuis ces services
        Haptic().warning();
        showSnackBar(context, "Le store de votre appareil n'autorise pas le téléchargement depuis ce service", icon: "warning", useCupertino: widget.useCupertino);
        return;
      }
      service = 'cobalt';
    }
    else if (downloadKey.startsWith('https://mediafire.com/file/') || downloadKey.startsWith('https://www.mediafire.com/file/')) {
      service = 'mediafire';
    }

    // Afficher un avertissement sur un service tiers
    if (service != 'stend') {
      var alreadyWarned = box.read('warnedAboutThirdPartyService') ?? false;
      if (!alreadyWarned) {
        box.write('warnedAboutThirdPartyService', true);
        await showAdaptiveDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog.adaptive(
              title: const Text("Service tiers"),
              content: const Text("Vous êtes sur le point de télécharger un fichier depuis un service tiers. Certaines fonctionnalités peuvent ne pas être implémentées ou ne pas fonctionner correctement."),
              actions: [
                TextButton(
                  onPressed: () {
                    Haptic().light();
                    Navigator.pop(context);
                  },
                  child: const Text("Continuer"),
                ),
              ],
            );
          }
        );
      }
    }

    // Afficher une alerte
    if (!mounted) return;
    downloadAlertTupple = const Tuple3("Préparation...", null, null);
    showAdaptiveDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return StreamBuilder(
          stream: downloadAlertStreamController.stream,
          initialData: downloadAlertTupple,
          builder: (BuildContext context, AsyncSnapshot snapshot) {
            String content = snapshot.data.item1;
            double? value = snapshot.data.item2;
            String? fileType = snapshot.data.item3;
            return PopScope(
              canPop: false,
              child: DownloadDialog(useCupertino: widget.useCupertino, content: content, value: value, fileType: fileType)
            );
          }
        );
      }
    );

    // Client Stend - on obtient le lien de l'API
    if (service == 'stend') {
      if (downloadKey.startsWith("http://") || downloadKey.startsWith("https://")) {
        Response response;

        try {
          var cancelToken = CancelToken();

          // Faire une requête pour obtenir l'URL de l'API avec une limite de 8 Mo
          response = await dio.get(downloadKey,
            cancelToken: cancelToken,
            onReceiveProgress: (received, total) {
              if (total > 8000000 || received > 8000000) {
                cancelToken.cancel();
              }
            },
            options: Options(
              followRedirects: false,
              validateStatus: (status) {
                return status! < 500;
              }
            )
          );
          while (response.isRedirect) {
            String location = response.headers.value('location')!;
            downloadKey = response.requestOptions.uri.toString();
            if (location.startsWith("/")) location = '${downloadKey.split("/")[0]}//${downloadKey.split("/")[2]}$location';
            if (location.endsWith('=')) location = location.substring(0, location.length - 1);
            var cancelToken = CancelToken();
            response = await dio.get(location,
              cancelToken: cancelToken,
              onReceiveProgress: (received, total) {
                if (total > 8000000 || received > 8000000) {
                  cancelToken.cancel();
                }
              },
              options: Options(
                followRedirects: false,
                validateStatus: (status) {
                  return status! < 500;
                }
              )
            );
          }
        } catch (e) {
          debugPrint(e.toString());
          if (!mounted) return;
          Navigator.pop(context);
          Haptic().error();
          showSnackBar(context, e.toString().contains("was manually cancelled by the user") ? "La requête n'a pas pu être validé" : "Le lien entré n'est pas accessible, vérifier votre connexion", icon: "error", useCupertino: widget.useCupertino);
          return;
        }

        // Obtenir ce qu'on a besoin d'obtenir
        if (!mounted) return;
        if (response.statusCode == 200 && response.data.isNotEmpty) {
          try {
            apiUrl = response.data.split('apibaseurl="')[1].split('"')[0];
            downloadKey = response.requestOptions.uri.toString().split('?')[1].split('&')[0];
          } catch (e) {
            debugPrint(e.toString());
            Navigator.pop(context);
            Haptic().error();
            showSnackBar(context, "Nous n'avons pas pu obtenir les infos sur le serveur", icon: "error", useCupertino: widget.useCupertino);
            return;
          }
        }
        else {
          Navigator.pop(context);
          Haptic().error();
          showSnackBar(context, "La page ne contient pas les infos sur le serveur", icon: "error", useCupertino: widget.useCupertino);
          return;
        }
      }

      // Sinon, on utilise l'URL de l'API par défaut
      if (apiUrl.length < 3) {
        apiUrl = box.read("apiInstanceUrl") ?? '';
        if (apiUrl.isEmpty) {
          if (!mounted) return;
          Navigator.pop(context);
          Haptic().warning();
          showSnackBar(context, "L'API n'a pas été configurée depuis les réglages", icon: "warning", useCupertino: widget.useCupertino);
          return;
        }
      }
    }

    // Free transfert - obtenir la clé de téléchargement
    else if (service == 'free') {
      if (downloadKey.endsWith("/")) downloadKey = downloadKey.substring(0, downloadKey.length - 1);
      downloadKey = downloadKey.split("/").last;
    }

    // Raccourci WeTransfer - obtenir les clés importantes
    else if (service == 'wetransfer' && (downloadKey.startsWith("https://we.tl/") || downloadKey.startsWith("http://we.tl/"))) {
      // Faire une requpete pour obtenir le lien non raccourci
      Response response = await dio.get(downloadKey, 
        options: Options(
          followRedirects: false,
          validateStatus: (status) {
            return status! < 500;
          }
        )
      );
      while (response.isRedirect) {
        String location = response.headers.value('location')!;
        if (location.startsWith("/")) location = '${downloadKey.split("/")[0]}//${downloadKey.split("/")[2]}$location';
        response = await dio.get(location, 
          options: Options(
            followRedirects: false,
            validateStatus: (status) {
              return status! < 500;
            }
          )
        );
      }

      // Obtenir ce qu'on a besoin d'obtenir
      if (!mounted) return;
      if (response.statusCode == 200 && response.data.isNotEmpty) {
        downloadKey = response.requestOptions.uri.toString();
        secondKey = downloadKey.split("/").last;
        downloadKey = downloadKey.split("/").reversed.skip(1).first;
      }
      else {
        Navigator.pop(context);
        Haptic().error();
        showSnackBar(context, "Nous n'avons pas pu obtenir l'URL après redirection", icon: "error", useCupertino: widget.useCupertino);
        return;
      }
    }

    // WeTransfer - obtenir les clés importantes
    else if (service == 'wetransfer') {
      if (downloadKey.endsWith("/")) downloadKey = downloadKey.substring(0, downloadKey.length - 1);
      secondKey = downloadKey.split("/").last;
      downloadKey = downloadKey.split("/").reversed.skip(1).first;
      if (downloadKey.isEmpty || secondKey.isEmpty) {
        if (!mounted) return;
        Navigator.pop(context);
        Haptic().error();
        showSnackBar(context, "Impossible de récupérer les clés de téléchargement", icon: "error", useCupertino: widget.useCupertino);
        return;
      }
    }

    // Smash - obtenir des infos importantes
    else if (service == 'smash') {
      if (downloadKey.endsWith("/")) downloadKey = downloadKey.substring(0, downloadKey.length - 1);
      downloadKey = downloadKey.split("/").last;

      token = await getSmashAccount();
      if (token.startsWith('err_')) {
        if (!mounted) return;
        Navigator.pop(context);
        Haptic().error();
        showSnackBar(context, token.substring(4), icon: "error", useCupertino: widget.useCupertino);
        return;
      }
    }

    // Swisstransfer - obtenir la clé de téléchargement
    else if (service == 'swisstransfer') {
      if (downloadKey.endsWith("/")) downloadKey = downloadKey.substring(0, downloadKey.length - 1);
      downloadKey = downloadKey.split("/").last;
      if (downloadKey.isEmpty) {
        if (!mounted) return;
        Navigator.pop(context);
        Haptic().error();
        showSnackBar(context, "Impossible de récupérer la clé de téléchargement", icon: "error", useCupertino: widget.useCupertino);
        return;
      }
    }

    // Cobalt, Mediafire - on a rien à faire

    // Si on a pas de clé de téléchargement, on arrête là
    if (downloadKey.isEmpty) {
      if (!mounted) return;
      Navigator.pop(context);
      Haptic().error();
      showSnackBar(context, "Aucune clé de téléchargement n'est spécifiée", icon: "error", useCupertino: widget.useCupertino);
      return;
    }

    // Enlever le slash à la fin de l'URL de l'API s'il y en a un
    if (apiUrl.endsWith("/")) {
      apiUrl = apiUrl.substring(0, apiUrl.length - 1);
    }

    // Changer l'alerte
    downloadAlertTupple = const Tuple3("Obtention des infos...", null, null);

    // On récupère les informations du transfert
    http.Response transfertInfo;
    try {
      if (service == 'stend') { // Support manquant : rien
        transfertInfo = await http.get(Uri.parse("$apiUrl/files/info?sharekey=$downloadKey"));
      } else if (service == 'free') { // Support manquant : transferts protégés par mot de passe
        transfertInfo = await http.get(Uri.parse("https://api.scw.iliad.fr/freetransfert/v2/transfers/$downloadKey"));
      } else if (service == 'wetransfer') { // Support manquant : transferts protégés par mot de passe ; les fichiers uploadé à partir d'un dossier peuvent être corrompus (problème avec l'API)
        transfertInfo = await http.post(Uri.parse("https://wetransfer.com/api/v4/transfers/$downloadKey/prepare-download"), body: json.encode({ "security_hash": secondKey }), headers: { "Content-Type": "application/json" });
      } else if (service == 'smash') { // Support manquant : transferts protégés par mot de passe
        var transfertRegion = await http.get(Uri.parse("https://link.fromsmash.co/target/fromsmash.com%2F$downloadKey?version=10-2019"), headers: { "Authorization": token });

        final Map<String, dynamic> transfertRegionJson;
        try {
          transfertRegionJson = json.decode(utf8.decode(transfertRegion.bodyBytes));
        } catch (e) {
        if (!mounted) return;
          Navigator.pop(context);
          debugPrint(e.toString());
          Haptic().error();
          showSnackBar(context, "Impossible de récupérer la région du transfert", icon: "error", useCupertino: widget.useCupertino);
          return;
        }

        if (transfertRegionJson['target']['region'] == null) {
          if (!mounted) return;
          Navigator.pop(context);
          Haptic().error();
          showSnackBar(context, "L'API n'a pas retourné la région du transfert", icon: "error", useCupertino: widget.useCupertino);
          return;
        }

        transfertInfo = await http.get(Uri.parse("https://transfer.${transfertRegionJson['target']['region']}.fromsmash.co/transfer/$downloadKey/files/preview?version=07-2020"), headers: { "Authorization": token });
      } else if (service == 'swisstransfer') { // Support manquant : transferts protégés par mot de passe
        transfertInfo = await http.get(Uri.parse("https://www.swisstransfer.com/api/links/$downloadKey"), headers: { "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36" });
      } else if (service == 'cobalt') { // Support manquant : quelques tests à faire ; certains services sont manquants ; picker (plusieurs médias)
        // On utilise dio au lieu d'http puisqu'il n'ajoute pas un header que l'API ne supporte pas
        Response dioTransfertInfo = await dio.post("https://api.cobalt.tools/api/json",
          data: {
            "url": downloadKey,
            "vQuality": "max",
            "aFormat": "best",
            "filenamePattern": "pretty",
            "isNoTTWatermark": true,
            "isTTFullAudio": true
          },
          options: Options(
            contentType: Headers.jsonContentType,
            headers: {
              "Accept": "application/json"
            }
          )
        );
        transfertInfo = http.Response(jsonEncode(dioTransfertInfo.data), dioTransfertInfo.statusCode!);
      } else if (service == 'mediafire') { // Support manquant : dossiers
        var transfertInfoPage = await http.get(Uri.parse(downloadKey));
        var transfertInfoHtml = parse(transfertInfoPage.body);
        var fileName = transfertInfoHtml.querySelector('div.filename')?.text;
        var downloadLink = transfertInfoHtml.querySelector('a#downloadButton')?.attributes['href'];
        transfertInfo = http.Response(json.encode({ "fileName": fileName, "downloadLink": downloadLink }), 200);
      } else {
        if (!mounted) return;
        Navigator.pop(context);
        Haptic().error();
        showSnackBar(context, "Ce service n'est pas supporté. Cela ne devrait pas arrivé. Signalez ce problème", icon: "error", useCupertino: widget.useCupertino);
        return;
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      debugPrint(e.toString());
      Haptic().error();
      showSnackBar(context, "Impossible de récupérer les infos via l'API", icon: "error", useCupertino: widget.useCupertino);
      return;
    }

    // On parse en JSON
    if (!mounted) return;
    final Map<String, dynamic> transfertInfoJson;
    try {
      transfertInfoJson = json.decode(utf8.decode(transfertInfo.bodyBytes));
    } catch (e) {
      Navigator.pop(context);
      debugPrint(e.toString());
      Haptic().error();
      showSnackBar(context, "L'API n'a pas retourné des informations valides", icon: "error", useCupertino: widget.useCupertino);
      return;
    }

    // On vérifie si on a une erreur dans le JSON
    if (transfertInfoJson.containsKey("message") || transfertInfoJson.containsKey("text") || transfertInfoJson.containsKey("error") || (transfertInfoJson.containsKey("status") && transfertInfoJson["status"] == "error")) {
      Navigator.pop(context);
      debugPrint(transfertInfoJson.toString());
      Haptic().warning();
      showSnackBar(context, (transfertInfoJson["message"] == 'Forbidden' ? "Ce transfert n'a pas pu être obtenu en raison d'une autorisation manquante (transfert protégé ?)" : transfertInfoJson["message"] == "Object not found" || transfertInfoJson["message"] == "Transfer not found" || transfertInfoJson["message"] == "Not Found" ? "Le transfert est introuvable, vérifier l'URL" : transfertInfoJson["message"]) ?? transfertInfoJson["text"] ?? transfertInfoJson["error"] ?? "Impossible de récupérer les infos du transfert", icon: "warning", useCupertino: widget.useCupertino);
      return;
    }

    // On vérifie si on a une erreur dans le statut de la requête
    if (transfertInfo.statusCode != 200) {
      if (!mounted) return;
      Navigator.pop(context);
      Haptic().error();
      showSnackBar(context, "L'API n'a pas retourné d'infos avec succès", icon: "error", useCupertino: widget.useCupertino);
      return;
    }

    // Vérification additionnelle pour les WeTransfer (protégé par mdp)
    if (service == 'wetransfer' && transfertInfoJson["password_protected"] == true) {
      Navigator.pop(context);
      Haptic().error();
      showSnackBar(context, "Stend ne supporte pas les liens protégés", icon: "error", useCupertino: widget.useCupertino);
      return;
    }

    // Vérification additionnelle pour les SwissTransfer (protégé par mdp et autres avertissements)
    if (service == 'swisstransfer' && transfertInfoJson["data"] != null && transfertInfoJson["data"]["message"] != null) {
      Navigator.pop(context);
      Haptic().error();
      showSnackBar(context, transfertInfoJson["data"]["message"], icon: "error", useCupertino: widget.useCupertino);
      return;
    }

    // On fait une variable initiale d'un array avec les transferts à télécharger
    List<Map<String, dynamic>> transfertsDownloads = [];

    // On passe sur chaque fichier pour obtenir leurs sous-informations
    if ((service == 'stend' && transfertInfoJson["isGroup"] == true && transfertInfoJson["groups"].isNotEmpty) || service == 'free' || service == 'wetransfer' || service == 'smash' || service == 'swisstransfer') {
      // Modifier le dialogue
      downloadAlertTupple = const Tuple3("Récupération des transferts...", null, null);
      downloadAlertStreamController.add(downloadAlertTupple);

      for (var transfert in (service == 'stend' ? transfertInfoJson["groups"] : transfertInfoJson["files"] ?? transfertInfoJson["items"] ?? transfertInfoJson["data"]["container"]["files"])) {
        // On fait une requête pour obtenir les informations du transfert
        http.Response subTransfertInfo;
        if (service == 'stend') {
          subTransfertInfo = await http.get(Uri.parse("$apiUrl/files/info?sharekey=$transfert"));
        } else if (service == 'wetransfer') {
          subTransfertInfo = await http.post(Uri.parse("https://wetransfer.com/api/v4/transfers/$downloadKey/download"), body: json.encode({ "security_hash": secondKey, "intent": "single_file", "file_ids": [transfert["id"]] }), headers: { "Content-Type": "application/json" });
        } else if (service == 'free') {
          subTransfertInfo = await http.get(Uri.parse("https://api.scw.iliad.fr/freetransfert/v2/files?transferKey=$downloadKey&path=${transfert["path"].toString().replaceAll(" ", "%20")}"));
        } else {
          subTransfertInfo = http.Response('', 200);
        }

        // On parse en JSON
        final Map<String, dynamic> subTransfertInfoJson;
        if(subTransfertInfo.body.isNotEmpty) {
          subTransfertInfoJson = json.decode(utf8.decode(subTransfertInfo.bodyBytes));
        }
        else {
          subTransfertInfoJson = transfert;
        }

        // Si on a une erreur, on ignore le transfert
        if (subTransfertInfoJson.containsKey("message") || subTransfertInfoJson.containsKey("error")) continue;

        // Vérification additionnelle pour les transferts Free
        if (service == 'free' && subTransfertInfoJson["url"] != null && subTransfertInfoJson["url"].toString().contains("/free-transfert.zip?X-Amz-Algorithm=")) {
          if (!mounted) return;
          Haptic().error();
          showSnackBar(context, "Un des fichiers du transfert n'a pas pu être obtenu en raison d'un nom incorrect. Signalez le problème", icon: "error", useCupertino: widget.useCupertino);
          continue;
        }

        // Normaliser le nom du fichier
        String fileName = subTransfertInfoJson["name"] ?? subTransfertInfoJson["path"] ?? subTransfertInfoJson["fileName"] ?? subTransfertInfoJson["filename"] ?? 'Aucun nom trouvé';
        if (fileName.contains("/")) fileName = fileName.split("/").last;

        // On ajoute le transfert à la liste
        if (service == 'stend') {
          transfertsDownloads.add(subTransfertInfoJson);
        } else if (service == 'free') {
          transfertsDownloads.add({
            "fileName": fileName,
            "fileSize": transfert["size"] != null ? int.parse(transfert["size"]) : 0,
            "downloadLink": subTransfertInfoJson["url"]
          });
        } else if (service == 'wetransfer') {
          transfertsDownloads.add({
            "fileName": fileName,
            "fileSize": transfert["size"],
            "downloadLink": subTransfertInfoJson["direct_link"]
          });
        } else if (service == 'smash') {
          transfertsDownloads.add({
            "fileName": fileName,
            "fileSize": transfert["size"],
            "downloadLink": transfert["download"]
          });
        } else if (service == 'swisstransfer') {
          transfertsDownloads.add({
            "fileName": fileName,
            "fileSize": transfert["fileSizeInBytes"],
            "downloadLink": "https://${transfertInfoJson["data"]["downloadHost"]}/api/download/${transfertInfoJson["data"]["linkUUID"]}/${transfert["UUID"]}"
          });
        }
      }
    }

    // Si on utilise Cobalt, on ajoute à la liste en fonction de la réponse
    else if (service == 'cobalt') {
      if (transfertInfoJson["status"] == "picker") {
        if (!mounted) return;
        Haptic().error();
        showSnackBar(context, "Stend ne supporte pas les liens avec plusieurs médias", icon: "error", useCupertino: widget.useCupertino);
        Navigator.pop(context);
        return;
      }

      if ((transfertInfoJson["status"] == "stream" || transfertInfoJson["status"] == "redirect") && transfertInfoJson.containsKey("url")) {
        // Modifier le dialogue
        downloadAlertTupple = const Tuple3("Récupération des détails...", null, null);
        downloadAlertStreamController.add(downloadAlertTupple);

        // Faire une requête HEAD pour obtenir les infos détaillées sur le fichier
        http.Response headResponse = await http.head(Uri.parse(transfertInfoJson["url"]));
        debugPrint(headResponse.headers.toString());
        int fileSize = headResponse.headers["content-length"] != null ? int.parse(headResponse.headers["content-length"]!) : 0;
        var fileName = transfertInfoJson["filename"];
        if (fileName == null){
          String contentDisposition = headResponse.headers["content-disposition"] ?? "";
          contentDisposition.split(";").forEach((element) {
            if (element.trim().startsWith("filename=")) {
              fileName = element.trim().split("=")[1];
              fileName = fileName.replaceAll("\"", "");
            }
          });
        }

        // Si le nom est manquant, on le génère en fonction de l'URL
        if (fileName == null) {
          fileName = Uri.parse(transfertInfoJson["url"]).pathSegments.last.toString();
          if (fileName.contains("?")) {
            fileName = fileName.split("?")[0];
          }
        }

        // On remplace l'extension .opus par .mp3
        if (fileName.endsWith(".opus")) {
          fileName = fileName.replaceAll(".opus", ".mp3");
        }

        // Ajouter à la liste des transferts
        transfertsDownloads.add({
          "fileName": fileName ?? "cobalt_unnamed_media",
          "fileSize": fileSize,
          "downloadLink": transfertInfoJson["url"]
        });
      }
    }

    // Sinon, on ajoute le transfert à la liste
    else {
      transfertsDownloads.add(transfertInfoJson);
    }

    // Si on a pas de transferts à télécharger, on annule tout
    if (transfertsDownloads.isEmpty) {
      if (!mounted) return;
      Haptic().warning();
      showSnackBar(context, "Le groupe de transfert est vide ou a expiré", icon: "warning", useCupertino: widget.useCupertino);
      Navigator.pop(context);
      return;
    }

    // Si on est sur Android, on demande la permission de stockage
    if (Platform.isAndroid) {
      // Si on est sur une version inférieure à Android 13, on demande la permission
      var deviceInfo = DeviceInfoPlugin();
      var androidInfo = await deviceInfo.androidInfo;
      debugPrint("sdkInt: ${androidInfo.version.sdkInt}");
      if(androidInfo.version.sdkInt < 33) {
        debugPrint("SDK inférieur à 33, on demande la permission de stockage");
        var storagePermission = await Permission.storage.request();
        if (storagePermission != PermissionStatus.granted) {
          if (!mounted) return;
          Haptic().error();
          showSnackBar(context, "Vous devez autoriser l'accès au stockage pour télécharger les fichiers", icon: "error", useCupertino: widget.useCupertino);
          Navigator.pop(context);
          return;
        }
      } else {
        debugPrint("SDK supérieur ou égal à 33, on ne demande pas la permission de stockage");
      }
    }

    // On détermine le chemin du fichier où télécharger
    String downloadDirectory = Platform.isAndroid ? '/storage/emulated/0/Download' : (await getApplicationDocumentsDirectory()).path;
    if (Platform.isIOS != true && box.read('downloadInSubFolder') == true) {
      // Créer le dossier s'il n'existe pas
      Directory('$downloadDirectory/Stend').createSync(recursive: true);

      // Changer le chemin du dossier
      downloadDirectory = '$downloadDirectory/Stend';
    }

    // Demander la permission d'envoyer des notifications
    askNotifPermission();

    // Empêcher l'écran de s'éteindre
    WakelockPlus.enable();

    // On télécharge chaque transfert
    bool savedInGallery = false;
    for (var transfert in transfertsDownloads) {
      debugPrint(transfert.toString());
      // Vérifier les propriétés
      if (!transfert.containsKey("fileName") || !transfert.containsKey("downloadLink")) {
        if (!mounted) return;
        Haptic().error();
        showSnackBar(context, "Un des transferts est mal formé (problème avec l'API ?)", icon: "error", useCupertino: widget.useCupertino);
        Navigator.pop(context);
        WakelockPlus.disable();
        return;
      }

      // Empêcher le nom du chemin d'aller en avant ou en arrière, et les caractères interdits
      String fileName = transfert["fileName"];
      String fileNamePath = fileName.replaceAll(RegExp(r'(\.\.)|(/)'), '').replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      // On récupère certaines infos
      int fileSize = transfert["fileSize"] ?? 0;
      String downloadLink = transfert["downloadLink"];
      String finalPath = path.join(downloadDirectory, fileNamePath);
      var fileType = transfert["fileType"]; // c'est ptet null donc on le met pas comme un String directement

      // Si le fichier existe déjà, on renomme celui qu'on télécharge
      if (File(finalPath).existsSync()) {
        int i = 1;
        while (File(finalPath).existsSync()) {
          finalPath = path.join(downloadDirectory, "${i}_$fileNamePath");
          i++;
        }
      }

      // On modifie l'alerte pour indiquer le nom du fichier
      downloadAlertTupple = Tuple3('$fileName${fileSize != 0 ? ' ― ${formatBytes(fileSize)}' : ''}', fileSize != 0 ? 0.0 : null, fileType);
      downloadAlertStreamController.add(downloadAlertTupple);

      // On télécharge le fichier
      final http.Request request = http.Request('GET', Uri.parse(downloadLink.startsWith("http") ? downloadLink : "$apiUrl$downloadLink"));
      final http.StreamedResponse response = await client.send(request);

      // On vérifie que le téléchargement a bien démarré
      await Future.delayed(const Duration(milliseconds: 200)); // jsp ça fix un bug quand on fait trop de requêtes trop vite
      if (response.statusCode != 200) {
        if (!mounted) return;
        Haptic().error();
        showSnackBar(context, "Impossible de télécharger le fichier $fileName", icon: "error", useCupertino: widget.useCupertino);
        Navigator.pop(context);
        WakelockPlus.disable();
        return;
      }

      // On récupère le contenu de la réponse
      int? totalBytes = response.contentLength;
      int bytesDownloaded = 0;

      // On crée le fichier avec un nom de chemin qui ne permet pas de faire du path traversal
      final File file = File(finalPath);
      final IOSink sink = file.openWrite();

      await for (List<int> chunk in response.stream) {
        // On écrit le chunk dans le fichier
        sink.add(chunk);

        // On met à jour l'alerte
        bytesDownloaded += chunk.length;
        dynamic downloadProgress = totalBytes != null || fileSize != 0 ? bytesDownloaded / (totalBytes ?? fileSize) : null;
        downloadAlertTupple = Tuple3('$fileName ― ${downloadProgress == null ? formatBytes(bytesDownloaded) : formatBytes(fileSize != 0 ? fileSize : totalBytes!)}', downloadProgress, fileType);
        downloadAlertStreamController.add(downloadAlertTupple);
      }

      // On ferme différents éléments
      await sink.flush();
      await sink.close();

      // Si on souhaite enregistrer dans la galerie et que c'est une image ou une vidéo
      if (box.read('saveMediasInGallery') == true) {
        // Déterminer le type de fichier
        var determinedFileType = fileName.split('.').last.toLowerCase();
        if (determinedFileType == 'jpeg' || determinedFileType == 'jpg' || determinedFileType == 'png' || determinedFileType == 'gif' || determinedFileType == 'webp') {
          determinedFileType = 'image';
        } else if (determinedFileType == 'mp4' || determinedFileType == 'mov' || determinedFileType == 'avi' || determinedFileType == 'mkv' || determinedFileType == 'webm') {
          determinedFileType = 'video';
        }

        // Si on a un type de fichier, on continue
        if (determinedFileType == 'image' || determinedFileType == 'video') {
          bool shouldContinue = false;

          // On vérifie les permissions
          final hasAccess = await Gal.hasAccess();
          if (!hasAccess) {
            await Gal.requestAccess();

            final hasAccess = await Gal.hasAccess();
            if (!hasAccess) {
              if (!mounted) return;
              Haptic().warning();
              showSnackBar(context, "La permission pour enregistrer dans la galerie a été refusée, le fichier se trouve dans le dossier téléchargement", icon: "warning", useCupertino: widget.useCupertino);
            } else {
              shouldContinue = true;
            }
          } else {
            shouldContinue = true;
          }

          // Si on a la permission, on continue
          if (shouldContinue) {
            try {
              // On enregistre le fichier dans la galerie
              if (determinedFileType == 'image') {
                await Gal.putImage(finalPath);
                savedInGallery = true;
              } else if (determinedFileType == 'video') {
                await Gal.putVideo(finalPath);
                savedInGallery = true;
              }

              // On supprime le fichier téléchargé
              await file.delete();
            } catch (e) {
              debugPrint(e.toString());
              Haptic().error();
              if (!mounted) return;
              showSnackBar(context, "Impossible d'enregistrer le fichier dans la galerie", icon: "error", useCupertino: widget.useCupertino);
              WakelockPlus.disable();
            }
          }
        }
      }
    }

    // On ferme l'alerte
    lastScannedCode = null;
    if (!mounted) return;
    Navigator.pop(context);

    // Indiquer à l'user que le téléchargement est terminé
    Haptic().success();
    showSnackBar(context, "${transfertsDownloads.length > 1 ? "${transfertsDownloads.length} fichiers ont été placés" : "Le fichier a été placé"}${savedInGallery ? " dans la galerie" : " dans vos téléchargements"}", icon: "success", useCupertino: widget.useCupertino);
    sendBackgroundNotif("Téléchargement terminé", "${transfertsDownloads.length > 1 ? "${transfertsDownloads.length} fichiers ont été placés" : "1 fichier a été placé"}${savedInGallery ? " dans la galerie" : " dans vos téléchargements"}", "download", "open-downloads");
    WakelockPlus.disable();
  }

  @override
  bool get wantKeepAlive => true;

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
                  "Besoin de télécharger un fichier ?",

                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black,
                  )
                )
              ),

              const SizedBox(height: 18.0),

              // Demander l'url de téléchargement du fichier dans un input
              TextField(
                controller: urlController,
                autocorrect: false,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: "Lien ou clé de partage du transfert",
                  hintText: "stend.example.com/d?123456",
                  suffixIcon: IconButton(
                    icon: Icon(Platform.isIOS ? Icons.arrow_forward_ios : Icons.arrow_forward),
                    onPressed: () => startDownload()
                  ),
                ),
                onSubmitted: (String value) { startDownload(); },
              ),

              const SizedBox(height: 12.0),

              // Groupe de boutons pour définir une url rapidement
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        Haptic().light();

                        // Lire le presse-papier
                        var data = await Clipboard.getData('text/plain');
                        var clipboard = data?.text;

                        // Si le presse-papier fait moins de 3 caractères ou plus de 256 caractères, on ne le prend pas en compte
                        if (clipboard == null || clipboard.length < 3 || clipboard.length > 256) {
                          Haptic().warning();
                          if (!context.mounted) return;
                          showSnackBar(context, "Aucun lien valide dans le presse-papier", icon: "warning", useCupertino: widget.useCupertino);
                        }

                        // Mettre à jour l'input avec le presse-papier
                        else {
                          urlController.text = clipboard;
                          startDownload();
                        }
                      },
                      child: const Text("Presse papier"),
                    )
                  ),

                  const SizedBox(width: 12.0),

                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => showQrScanner(),
                      child: const Text("QR Code"),
                    )
                  )
                ],
              ),

              const SizedBox(height: 22.0),

              // Titre de la section
              tips.isNotEmpty ? Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Astuces",

                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black,
                  )
                )
              ) : const SizedBox.shrink(),

              tips.isNotEmpty ? const SizedBox(height: 18.0) : const SizedBox.shrink(),

              // Cartes avec les astuces
              ListView.builder(
                shrinkWrap: true,
                // physics: const NeverScrollableScrollPhysics(),
                primary: false,
                itemCount: tips.length,
                itemBuilder: (BuildContext context, int index) {
                  return Card(
                    child: ListTile(
                      title: Text(tips[index], style: const TextStyle(fontSize: 14)),
                      trailing: IconButton(
                        icon: Icon(iconLib == 'Lucide' ? LucideIcons.trash2 : iconLib == 'Lucide (alt)' ? LucideIcons.trash : Icons.delete),
                        onPressed: () {
                          Haptic().light();
                          setState(() {
                            tips.removeAt(index);
                            box.write('tips', tips);
                          });
                        },
                      ),
                    ),
                  );
                } 
              ),

              tips.isNotEmpty ? const SizedBox(height: 18.0) : const SizedBox.shrink(),

              // Titre de la section
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Accéder à vos précédents envois",

                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black,
                  )
                )
              ),

              const SizedBox(height: 18.0),

              // Cartes avec les précédents envois
              historic.isNotEmpty ?
                ListView.builder(
                  shrinkWrap: true,
                  // physics: const NeverScrollableScrollPhysics(),
                  primary: false,
                  itemCount: historic.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Card(
                      child: ListTile(
                        title: Text(historic[index]["filename"], overflow: TextOverflow.ellipsis, maxLines: 3),
                        subtitle: Text("${formatDate(historic[index]["date"])} ― ${formatBytes(historic[index]["filesize"] ?? '0')}${historic[index]["filetype"] != null && historic[index]["filetype"].isNotEmpty ? " ― ${historic[index]["filetype"]}" : ""}"),
                        onLongPress: () {
                          Haptic().light();

                          final screenSize = MediaQuery.of(context).size;
                          final rect = Rect.fromCenter(
                            center: Offset(screenSize.width / 2, screenSize.height / 2),
                            width: 100,
                            height: 100,
                          );
                          Share.share(historic[index]["access"], sharePositionOrigin: rect);
                        },
                        onTap: () {
                          Haptic().light();
                          urlController.text = historic[index]["access"];
                          startDownload();
                        },
                        trailing: IconButton(
                          icon: Icon(iconLib == 'Lucide' ? LucideIcons.trash2 : iconLib == 'Lucide (alt)' ? LucideIcons.trash : Icons.delete),
                          onPressed: () {
                            Haptic().light();

                            // Afficher un dialogue pour demander une confirmation
                            showAdaptiveDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog.adaptive(
                                  title: const Text("Supprimer cet envoi ?"),
                                  content: Text("${widget.useCupertino ? '' : "Le fichier ne pourra pas être récupérer si vous n'en disposez pas une copie. "}Êtes-vous sûr de vouloir supprimer ce transfert des serveurs ?"),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Haptic().light();
                                        Navigator.pop(context);
                                      },
                                      child: const Text("Annuler"),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        Haptic().light();

                                        // Faire une requête pour supprimer le fichier
                                        var response = await dio.delete(
                                          "${historic[index]["apiurl"]}/files/delete",
                                          options: Options(
                                            headers: { 'Content-Type': 'application/json' },
                                          ),
                                          queryParameters: {
                                            "sharekey": historic[index]["sharekey"] ?? "",
                                            "deletekey": historic[index]["deletekey"] ?? ""
                                          },
                                        );

                                        // On supprime l'élément de la liste (même si la requête a échoué, ptet la clé a expiré et donc ça va forcément fail mais on veut le masquer)
                                        setState(() {
                                          historic.removeAt(index);
                                          box.write('historic', historic);
                                        });

                                        // On parse le JSON et affiche l'erreur si le status code n'est pas 200
                                        if (!context.mounted) return;
                                        if (response.statusCode != 200) {
                                          Haptic().error();
                                          try {
                                            showSnackBar(context, response.data["message"] ?? response.data["error"] ?? "Impossible de supprimer le transfert", icon: "error", useCupertino: widget.useCupertino);
                                          } catch (e) {
                                            showSnackBar(context, "Impossible de supprimer le transfert", icon: "error", useCupertino: widget.useCupertino);
                                          }
                                        }

                                        // Fermer le dialogue
                                        Navigator.pop(context);
                                      },
                                      child: const Text("Supprimer"),
                                    ),
                                  ],
                                );
                              }
                            );
                          },
                        ),
                      ),
                    );
                  }
                ) :
                // carte avec un icône tout en haut:
                Card(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 18.0, bottom: 18.0, left: 12.0, right: 12.0),
                    child: Column(
                      children: [
                        Icon(iconLib == 'Lucide' ? LucideIcons.folderX : iconLib == 'Lucide (alt)' ? LucideIcons.imageOff : iconLib == 'iOS' ? CupertinoIcons.bin_xmark : Icons.folder_off_outlined, size: 32, color: Theme.of(context).colorScheme.primary),
                        ListTile(
                          title: Text(disableHistory == true ? "Historique désactivé" : "Aucun envoi récent", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(disableHistory == true ? "Vous pouvez réactiver l'historique depuis les réglages" : "Commencez à envoyer des fichiers pour les retrouver ici", textAlign: TextAlign.center),
                        )
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

  void _onQRViewCreated(QRViewController qrController) {
    this.qrController = qrController;
    qrController.scannedDataStream.listen((scanData) {
      setState(() {
        if (lastScannedCode == scanData.code) return;
        lastScannedCode = scanData.code;

        if (scanData.code != null && scanData.code!.isNotEmpty && scanData.code!.length > 3 && scanData.code!.length < 256){
          setState(() {
            urlController.text = scanData.code!;
          });

          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }

          startDownload();
        }
      });
    });
  }
}