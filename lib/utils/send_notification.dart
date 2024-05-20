import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:open_file_manager/open_file_manager.dart';
import 'package:permission_handler/permission_handler.dart';

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

bool isInitialized = false;
bool appIsInForeground = true;

Map channels = {
  'upload': const AndroidNotificationDetails(
    'upload',
    'Envoi de fichiers',
    channelDescription: 'Notifications liés à l\'envoi de fichiers',
    groupKey: 'transfert'
  ),
  'download': const AndroidNotificationDetails(
    'download',
    'Téléchargement',
    channelDescription: 'Notifications liés au téléchargement de fichiers',
    groupKey: 'transfert'
  )
};

// TODO: tester les notifications sur android

void notifInitialize() async {
  // Vérifie qu'on n'a pas déjà initialisé
  if(isInitialized) return;
  isInitialized = true;

  // Fonction quand on clique sur une notification
  void onDidReceiveNotificationResponse(NotificationResponse notificationResponse) {
    String? payload = notificationResponse.payload;
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
    var initializationSettingsAndroid = const AndroidInitializationSettings('@mipmap/ic_launcher');
    var initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  FGBGEvents.stream.listen((event) {
    appIsInForeground = event == FGBGType.foreground;
  });
}

void sendBackgroundNotif(String title, String body, String channelKey, String ?payload) async {
  // Vérifier si l'app est à l'avant-plan
  if(appIsInForeground) return;
  if(!isInitialized) return;

  // Vérifier les permissions
  if(Platform.isAndroid){
    // Vérifier uniquement sur Android 13 ou +
    if (Platform.version.compareTo('33') >= 0) {
      var status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    }
  } else if(Platform.isIOS){
    final result = await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
      alert: true,
      badge: true,
      sound: false
    );
    if(result == false) return; // notifs désactivées
  }

  // Créer et afficher la notification
  await flutterLocalNotificationsPlugin.show(
    0,
    title,
    body,
    payload: payload,
    NotificationDetails(android: channels[channelKey])
  );
}