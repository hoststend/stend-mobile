import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:open_file_manager/open_file_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

bool isInitialized = false;
bool appIsInForeground = true;

Map channels = {
  'upload': const AndroidNotificationDetails(
    'upload',
    'Envoi de fichiers',
    channelDescription: 'Notifications liés à l\'envoi de fichiers',
    category: AndroidNotificationCategory.progress,
    visibility: NotificationVisibility.public,
    groupKey: 'transfert'
  ),
  'download': const AndroidNotificationDetails(
    'download',
    'Téléchargement',
    channelDescription: 'Notifications liés au téléchargement de fichiers',
    category: AndroidNotificationCategory.progress,
    visibility: NotificationVisibility.public,
    groupKey: 'transfert'
  )
};

void notifInitialize() async {
  // Vérifie qu'on n'a pas déjà initialisé
  if(isInitialized) return;
  isInitialized = true;

  // Fonction quand on clique sur une notification
  void onDidReceiveNotificationResponse(NotificationResponse notificationResponse) {
    String? payload = notificationResponse.payload;
    debugPrint('Payload notification reçue: $payload');
    if(payload == null) return;

    if(payload == 'open-downloads'){
      openFileManager(
        androidConfig: AndroidConfig(folderType: FolderType.download)
        // Pas de config pour iOS, pour ouvrir le dossier de l'app (par défaut)
      );
    }
  }

  // Initialiser le plugin de notifications
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  if(Platform.isIOS){
    var initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      onDidReceiveLocalNotification: (int id, String? title, String? body, String? payload) async {}
    );
    var initializationSettings = InitializationSettings(iOS: initializationSettingsIOS);
    flutterLocalNotificationsPlugin.initialize(initializationSettings, onDidReceiveNotificationResponse: onDidReceiveNotificationResponse);
  } else if(Platform.isAndroid){
    var initializationSettingsAndroid = const AndroidInitializationSettings('@mipmap/ic_notification');
    var initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    flutterLocalNotificationsPlugin.initialize(initializationSettings, onDidReceiveNotificationResponse: onDidReceiveNotificationResponse);
  }

  FGBGEvents.stream.listen((event) {
    appIsInForeground = event == FGBGType.foreground;
  });
}

void askNotifPermission() async {
  if(Platform.isAndroid){
    // Si on sur Android 12 ou -, on ne demande pas la permission
    var deviceInfo = DeviceInfoPlugin();
    var androidInfo = await deviceInfo.androidInfo; // on utilisera ça pdnt l'upload pour un user agent plus précis
    debugPrint("SDK Android: ${androidInfo.version.sdkInt}");
    if(androidInfo.version.sdkInt <= 32) return;

    // Demander la permission si on ne l'a pas
    var status = await Permission.notification.status;
    if (!status.isGranted) await Permission.notification.request();
  } else if(Platform.isIOS){
    final result = await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
      alert: true,
      badge: true,
      sound: false
    );
    debugPrint('Notification permission allowed: $result');
  }

  return;
}

void sendBackgroundNotif(String title, String body, String channelKey, String ?payload) async {
  // Vérifier si l'app est à l'avant-plan
  if(appIsInForeground) return;
  if(!isInitialized) return;

  // Créer et afficher la notification
  try {
    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      payload: payload,
      NotificationDetails(android: channels[channelKey])
    );
  } catch (e) {
    debugPrint('Impossible d\'envoyer une notification: $e');
  }
}