import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:get_storage/get_storage.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_acrylic/widgets/transparent_macos_sidebar.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:window_manager/window_manager.dart';
import 'package:stendmobile/utils/haptic.dart';
import 'package:stendmobile/utils/globals.dart' as globals;
import 'package:stendmobile/utils/global_server.dart' as globalserver;
import 'package:stendmobile/utils/send_notification.dart';
import 'package:stendmobile/pages/download.dart';
import 'package:stendmobile/pages/send.dart';
import 'package:stendmobile/pages/settings.dart';
import 'package:stendmobile/pages/debug.dart';
import 'package:protocol_handler/protocol_handler.dart';

// Fonction pour convertir une chaîne de caractères HEX en couleur
Color hexToColor(String code) {
  return Color(int.parse(code.substring(1, 7), radix: 16) + 0xFF000000);
}

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await protocolHandler.register('stend');
  await GetStorage.init();

  if(Platform.isWindows || Platform.isMacOS || Platform.isLinux) await windowManager.ensureInitialized();

  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({Key? key}) : super(key: key);

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with ProtocolListener {
  late GetStorage box;

  bool firstBuildPassed = false;
  bool showRefreshButton = false;

  int _currentIndex = 0;
  int _sameIndexClickedTimes = 0;

  late String iconLib;
  late Brightness brightness;
  bool useCupertino = false;
  bool acrylicEffect = false;
  bool isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  bool windowShown = !Platform.isMacOS;

  late PageController _pageController;
  late int defaultPageIndex;
  bool _debugSettingsOpened = false;

  Key _refreshKey = UniqueKey();
  void refresh() {
    // Mettre à jour la page par défaut
    var defaultPage = box.read('defaultPage');
    if (defaultPage == null || defaultPage == 'Envoyer') {
       _pageController = PageController(initialPage: 0);
      defaultPageIndex = 0;
    } else if (defaultPage == 'Télécharger') {
       _pageController = PageController(initialPage: 1);
      defaultPageIndex = 1;
    } else if (defaultPage == 'Réglages') {
       _pageController = PageController(initialPage: 2);
      defaultPageIndex = 2;
    }

    // Déterminer la bibliothèque d'icônes par défaut
    if (box.read('iconLib') == null) {
      iconLib = Platform.isIOS ? 'Lucide' : 'Material';
      box.write('iconLib', iconLib);
    } else {
      iconLib = box.read('iconLib');
    }

    // Déterminer si on utilise Cupertino ou Material
    if (box.read('forceCupertinoDesign') == true) {
      useCupertino = true;
    } else if (box.read('useMaterialYou') == null && Platform.isIOS) {
      useCupertino = true;
    } else if (box.read('useMaterialYou') == null && !Platform.isIOS) {
      useCupertino = false;
    } else if (box.read('useMaterialYou') == true) {
      useCupertino = false;
    } else {
      useCupertino = true;
    }

    acrylicEffect = box.read('acrylicEffect') ?? false;
    brightness = box.read('theme') == 'Système' ? PlatformDispatcher.instance.platformBrightness : box.read('theme') == 'Clair' ? Brightness.light : box.read('theme') == 'Sombre' ? Brightness.dark : PlatformDispatcher.instance.platformBrightness;
    setAcrylicEffect();

    // Reset certaines globales
    globals.initializedPages = {};
    globals.intereventsStreamController = StreamController.broadcast();

    setState(() {
      _currentIndex = defaultPageIndex;
      showRefreshButton = false;
      _refreshKey = UniqueKey();
    });
  }

  void destinationSelected(int index) {
    debugPrint('$index ; $_currentIndex ; $_sameIndexClickedTimes');
    if(index == _currentIndex){
      _sameIndexClickedTimes++;
      if(_sameIndexClickedTimes == 2 && index == 2){
        _sameIndexClickedTimes = 0;
        Haptic().light();
        _debugSettingsOpened = true;
        _pageController.jumpToPage(3);
        return;
      } else {
        return;
      }
    } else {
      _sameIndexClickedTimes = 0;
    }

    Haptic().light();

    setState(() {
      _currentIndex = index;
      _debugSettingsOpened = false;
    });

    while (_pageController.hasClients == false) { // permet d'attendre que le contrôleur de page soit prêt
      debugPrint('page controller not ready');
      Future.delayed(const Duration(milliseconds: 200));
    }

    _pageController.jumpToPage(index);
    
    if (index == 1) globals.intereventsStreamController.add({'type': 'page-open', 'page': 'download'});
  }

  void setAcrylicEffect() async {
    if(!Platform.isWindows && !Platform.isMacOS) return; // pas encore testé sur Linux

    try { await Window.initialize(); } catch (e) { debugPrint('Window.initialize() warning: $e'); }
    if(acrylicEffect && Platform.isWindows) Window.setEffect(effect: WindowEffect.contentBackground);
    // if(Platform.isMacOs) Window.setEffect(effect: WindowEffect.contentBackground); // déjà par défaut sur macOS, et empêche le resize de la sidebar quand défini manuellement

    await Window.makeTitlebarTransparent();
    await Window.hideTitle();
    await Window.enableFullSizeContentView();
    await Window.overrideMacOSBrightness(dark: brightness == Brightness.dark);

    if(!windowShown){
      windowShown = true;
      await windowManager.show();
    }
  }

  @override
  void initState() {
    box = GetStorage();

    // Déterminer la page par défaut et définir le contrôleur de page
    var defaultPage = box.read('defaultPage');
    if (defaultPage == null || defaultPage == 'Envoyer') {
      _pageController = PageController(initialPage: 0);
      _currentIndex = 0;
      defaultPageIndex = 0;
    } else if (defaultPage == 'Télécharger') {
      _pageController = PageController(initialPage: 1);
      _currentIndex = 1;
      defaultPageIndex = 1;
    } else if (defaultPage == 'Réglages') {
      _pageController = PageController(initialPage: 2);
      _currentIndex = 2;
      defaultPageIndex = 2;
    }

    acrylicEffect = box.read('acrylicEffect') ?? false;
    brightness = box.read('theme') == 'Système' ? PlatformDispatcher.instance.platformBrightness : box.read('theme') == 'Clair' ? Brightness.light : box.read('theme') == 'Sombre' ? Brightness.dark : PlatformDispatcher.instance.platformBrightness;
    setAcrylicEffect();

    // Déterminer la bibliothèque d'icônes par défaut
    if (box.read('iconLib') == null) {
      iconLib = Platform.isIOS ? 'Lucide' : 'Material';
      box.write('iconLib', iconLib);
    } else {
      iconLib = box.read('iconLib');
    }

    // Déterminer si on utilise Cupertino ou Material
    if (box.read('forceCupertinoDesign') == true) {
      useCupertino = true;
    } else if (box.read('useMaterialYou') == null && Platform.isIOS) {
      useCupertino = true;
    } else if (box.read('useMaterialYou') == null && !Platform.isIOS) {
      useCupertino = false;
    } else if (box.read('useMaterialYou') == true) {
      useCupertino = false;
    } else {
      useCupertino = true;
    }

    notifInitialize();
    super.initState();

    // Protocol Handler (après que l'app soit initialisée)
    protocolHandler.addListener(this); // pour les URLs ouvertes pendant que l'app est ouverte
    protocolHandler.getInitialUrl().then((initialUrl) => { // pour les URLs ouvertes avant que l'app soit ouverte
      debugPrint('initialUrl: $initialUrl'),
      if (initialUrl != null) onProtocolUrlReceived(initialUrl)
    });

    // Fichiers partagés vers l'app avec un intent
    if(Platform.isAndroid){
      ReceiveSharingIntent.instance.getMediaStream().listen((value) { // pendant que l'app est ouverte
        debugPrint(value.toString());
        onMediaIntentReceived(value);
      }, onError: (err) { debugPrint("SharingIntent getMediaStream() error: $err"); });
      ReceiveSharingIntent.instance.getInitialMedia().then((value) { // avant que l'app soit ouverte
        debugPrint(value.toString());
        onMediaIntentReceived(value);
        ReceiveSharingIntent.instance.reset();
      });
    }

    if(!windowShown && !acrylicEffect){
      windowShown = true;
      windowManager.show();
    }

    // Déterminer quand l'app est en avant/arrière plan
    if(isDesktop){
      // TODO: https://pub.dev/packages/window_manager#quick-start
    } else {
      FGBGEvents.stream.listen((event) {
        globals.appIsInForeground = event == FGBGType.foreground;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    protocolHandler.removeListener(this);
    super.dispose();
  }

  @override
  void onProtocolUrlReceived(String url) async {
    var urlSplit = url.split('://');
    var urlPath = urlSplit.sublist(1).join('://');
    var unformattedParams = urlPath.split('?');
    urlPath = unformattedParams[0];
    Map<String, String> urlParams = {};
    unformattedParams = unformattedParams.sublist(1).join('?').split('&');
    for (var param in unformattedParams) {
      var paramSplit = param.split('=');
      urlParams[paramSplit[0]] = paramSplit.length > 1 ? paramSplit[1] : paramSplit[0];
    }
    debugPrint('urlParams: $urlParams');
    if(urlPath.endsWith('/')) urlPath = urlPath.substring(0, urlPath.length - 1);
    debugPrint('urlPath: $urlPath');

    if (urlPath == 'send') {
      destinationSelected(0);
    } else if (urlPath == 'download') {
      destinationSelected(1);
    }
    else if (urlPath == 'settings') {
      destinationSelected(2); 
    }
    else if (urlPath == 'debug') {
      _pageController.jumpToPage(3);
      setState(() {
        _debugSettingsOpened = true;
        _currentIndex = 2;
      });
    } else if(urlPath == 'download/qrcode'){
      destinationSelected(1);

      while (globals.initializedPages['download'] != true) { // permet d'attendre que la page soit initialisée, et donc qu'elle soit prête à recevoir des événements
        debugPrint('page not initialized yet');
        await Future.delayed(const Duration(milliseconds: 100));
      }
      debugPrint('page initialized');

      globals.intereventsStreamController.add({'type': 'open-qrcode-scanner'});
    } else if(urlPath == 'download/start'){
      var urlDownload = urlParams['url'];
      if(urlDownload == null){
        debugPrint("Stend a été ouvert via une URL personnalisée qui n'a pas été reconnue");
        askNotifPermission();
        sendNotif("Échec de l'ouverture", "Stend a été ouvert via une URL personnalisée, mais le paramètre \"url\" qui était nécessaire n'a pas été trouvé. URL : \"$url\"", 'warnings', null);
        return;
      }

      destinationSelected(1);

      while (globals.initializedPages['download'] != true) { // permet d'attendre que la page soit initialisée, et donc qu'elle soit prête à recevoir des événements
        debugPrint('page not initialized yet');
        await Future.delayed(const Duration(milliseconds: 100));
      }
      debugPrint('page initialized');

      globals.intereventsStreamController.add({'type': 'download', 'url': urlDownload});
    } else if(urlPath == 'send/files' || urlPath == 'send/images' || urlPath == 'send/videos' || urlPath == 'send/camera'){
      destinationSelected(0);

      while (globals.initializedPages['send'] != true) {
        debugPrint('page not initialized yet');
        await Future.delayed(const Duration(milliseconds: 100));
      }
      debugPrint('page initialized');

      var action = urlPath.split('/')[1];
      globals.intereventsStreamController.add({'type': 'open-send-picker', 'picker': action});
    } else if(urlPath == 'settings/reset' || urlPath == 'settings/checkInstance' || urlPath == 'settings/configInstance'){
      destinationSelected(2);

      while (globals.initializedPages['settings'] != true) {
        debugPrint('page not initialized yet');
        await Future.delayed(const Duration(milliseconds: 100));
      }
      debugPrint('page initialized');

      var action = urlPath.split('/')[1];
      globals.intereventsStreamController.add({'type': 'settings', 'action': action, 'initialWebUrl': urlParams['webUrl'], 'initialApiUrl': urlParams['apiUrl'], 'initialPassword': urlParams['password']});
    } else if(urlPath == 'globalserver/auth'){
      var code = urlParams['code'];
      if(code == null){
        debugPrint("Stend a été ouvert via une URL personnalisée qui n'a pas été reconnue");
        askNotifPermission();
        sendNotif("Échec de l'ouverture", "Stend a été ouvert via une URL personnalisée, mais le paramètre \"code\" qui était nécessaire n'a pas été trouvé. URL : \"$url\"", 'warnings', null);
        return;
      }

      // ouvrir les réglages
      if(_currentIndex != 2){
        destinationSelected(2);
        while (globals.initializedPages['settings'] != true) {
          debugPrint('page not initialized yet');
          await Future.delayed(const Duration(milliseconds: 100));
        }
        debugPrint('page initialized');
      } else {
        debugPrint('skipping settings page initialization');
      }

      // échanger le code contre un token
      var codeExchange = await globalserver.checkcodeAuth(code);
      if(codeExchange != true){
        sendNotif("Échec de la connexion", "La connexion au compte Stend a échoué. $codeExchange.", 'warnings', null);
      }
    } else {
      debugPrint("Stend a été ouvert via une URL personnalisée qui n'a pas été reconnue du tout");
      askNotifPermission();
      sendNotif("Échec de l'ouverture", "Stend a été ouvert via une URL personnalisée, mais celle-ci n'a pas été reconnue. URL : \"$url\"", 'warnings', null);
    }
  }

  void onMediaIntentReceived(List<SharedMediaFile> value) async {
    if(value.isEmpty) return;
    List files = [];

    for (var file in value) {
      if (file.type == SharedMediaType.url || file.type == SharedMediaType.text){
        debugPrint('One of media in intent received is of type "url" / "text", ignoring it');
        continue;
      }

      File fileToShare = File(file.path);
      if (fileToShare.existsSync()) {
        files.add(fileToShare);
      } else {
        debugPrint('File does not exist: ${file.path}');
        debugPrint(file.toString());
      }
    }

    if (files.isEmpty) return;
    destinationSelected(0);

    while (globals.initializedPages['send'] != true) {
      debugPrint('page not initialized yet');
      await Future.delayed(const Duration(milliseconds: 100));
    }
    debugPrint('page initialized');

    globals.intereventsStreamController.add({'type': 'add-files-to-selection', 'files': files});
  }

  @override
  Widget build(BuildContext context) {
    if (firstBuildPassed == false){
      firstBuildPassed = true;

      // Couleurs pour la barre de status/navigation système
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.black.withOpacity(0.002),
        systemNavigationBarIconBrightness: Brightness.dark,
      ));
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

      // Masquer le splash screen et afficher l'app
      FlutterNativeSplash.remove();
    }

    return DynamicColorBuilder(
      builder: (lightColorScheme, darkColorScheme) {
        if (lightColorScheme == null && darkColorScheme == null) {
          lightColorScheme = ColorScheme.fromSeed(
            seedColor: box.read('appColor') != null ? hexToColor(box.read('appColor')) : Colors.blueAccent,
            brightness: Brightness.light,
          );
          darkColorScheme = ColorScheme.fromSeed(
            seedColor: box.read('appColor') != null ? hexToColor(box.read('appColor')) : Colors.blueAccent,
            brightness: Brightness.dark,
          );
        }

        ThemeData lightTheme = ThemeData(
          colorScheme: lightColorScheme,
          primaryColor: Colors.black,
          brightness: Brightness.light,
          useMaterial3: true,
          splashFactory: Platform.isIOS || isDesktop ? NoSplash.splashFactory : null,
          splashColor: Platform.isIOS || isDesktop ? Colors.transparent : null,
          highlightColor: Platform.isIOS || isDesktop ? Colors.transparent : null,
          hoverColor: isDesktop ? Colors.transparent : null,
          platform: !useCupertino ? TargetPlatform.android : null,
          scaffoldBackgroundColor: acrylicEffect ? Colors.transparent : null,
        );
        ThemeData darkTheme = ThemeData(
          colorScheme: darkColorScheme,
          primaryColor: Colors.white,
          brightness: Brightness.dark,
          useMaterial3: true,
          splashFactory: Platform.isIOS || isDesktop ? NoSplash.splashFactory : null,
          splashColor: Platform.isIOS || isDesktop ? Colors.transparent : null,
          highlightColor: Platform.isIOS || isDesktop ? Colors.transparent : null,
          hoverColor: isDesktop ? Colors.transparent : null,
          platform: !useCupertino ? TargetPlatform.android : null,
          cupertinoOverrideTheme: const CupertinoThemeData(
            textTheme: CupertinoTextThemeData(),
          ),
          scaffoldBackgroundColor: acrylicEffect ? Colors.transparent : null,
        );

        return MaterialApp(
          key: _refreshKey,
          title: 'Stend',
          themeMode: box.read('theme') == 'Système' ? ThemeMode.system : box.read('theme') == 'Clair' ? ThemeMode.light : box.read('theme') == 'Sombre' ? ThemeMode.dark : ThemeMode.system,
          theme: lightTheme,
          darkTheme: darkTheme,
          home: Scaffold(
            floatingActionButton: showRefreshButton && MediaQuery.of(context).size.width > 900
            ? FloatingActionButton.extended(
              onPressed: () {
                Haptic().light();
                refresh();
              },
              enableFeedback: false,
              label: const Text('Rafraîchir'),
              icon: Icon(iconLib == 'Lucide' ? LucideIcons.rotateCw : iconLib == 'Lucide (alt)' ? LucideIcons.rotateCw : iconLib == 'iOS' ? CupertinoIcons.refresh : Icons.refresh),
            ) : showRefreshButton ? FloatingActionButton(
              onPressed: () {
                Haptic().light();
                refresh();
              },
              enableFeedback: false,
              child: Icon(iconLib == 'Lucide' ? LucideIcons.rotateCw : iconLib == 'Lucide (alt)' ? LucideIcons.rotateCw : iconLib == 'iOS' ? CupertinoIcons.refresh : Icons.refresh),
            ) : null,
            floatingActionButtonLocation: MediaQuery.of(context).size.width > 600 ? FloatingActionButtonLocation.startFloat : FloatingActionButtonLocation.endFloat,
            body: PopScope(
              canPop: false, // permet d'appeler notre fonction
              onPopInvoked: (didPop) {
                debugPrint('_currentIndex: $_currentIndex');
                // Si la page ouverte est les réglages de débogage, ouvrir les réglages normaux
                if (_debugSettingsOpened) {
                  _pageController.jumpToPage(2);
                  setState(() {
                    _debugSettingsOpened = false;
                    _currentIndex = 2;
                  });
                  return;
                }

                // Sinon, si on est pas sur la page d'origine, on retourne celle-ci
                if (_currentIndex != defaultPageIndex) {
                  destinationSelected(defaultPageIndex);
                  return;
                }

                // Sinon, on retourne réellement en arrière
                SystemNavigator.pop();
              },
              child: SafeArea(
                bottom: true,

                child: Row(
                  children: [
                    MediaQuery.of(context).size.width > 600 ? TransparentMacOSSidebar(
                      effect: acrylicEffect ? (Platform.isMacOS ? WindowEffect.sidebar : WindowEffect.fullScreenUI) : WindowEffect.disabled,
                      child: NavigationRail(
                        selectedIndex: _currentIndex,
                        onDestinationSelected: destinationSelected,
                        extended: MediaQuery.of(context).size.width > 900,
                        backgroundColor: acrylicEffect ? Colors.transparent : isDesktop ? (brightness == Brightness.dark ? Theme.of(context).focusColor : Theme.of(context).colorScheme.onInverseSurface) : null,
                        indicatorColor: useCupertino ? Colors.transparent : null,
                        selectedIconTheme: useCupertino ? IconThemeData(color: brightness == Brightness.dark ? Colors.white : Colors.black) : null,
                        selectedLabelTextStyle: useCupertino ? TextStyle(color: brightness == Brightness.dark ? Colors.white : Colors.black, fontWeight: FontWeight.w500) : null,
                        unselectedIconTheme: useCupertino ? IconThemeData(color: Colors.grey[400]) : null,
                        unselectedLabelTextStyle: useCupertino ? TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[400]) : null,
                        leading: MediaQuery.of(context).size.width > 900 ? (
                          useCupertino ? SizedBox(
                            width: MediaQuery.of(context).size.width > 500 ? 240 : 72,
                            child: Padding(
                              padding: EdgeInsets.only(left: 16.0, top: isDesktop ? 28.0 : 4.0, bottom: 4.0),
                              child: const Text("Stend", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700), textAlign: TextAlign.left)
                            )
                          )
                          : Column(
                            children: [
                              SizedBox(height: isDesktop ? 28 : 20),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "Stend",
                                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700)
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          )) : SizedBox(height: isDesktop ? 20 : 2),
                        destinations: [
                          NavigationRailDestination(
                            icon: Icon(iconLib == 'Lucide' ? LucideIcons.fileUp : iconLib == 'Lucide (alt)' ? LucideIcons.uploadCloud : iconLib == 'iOS' ? CupertinoIcons.square_arrow_up : Icons.upload_file),
                            label: const Text('Envoyer'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(iconLib == 'Lucide' ? LucideIcons.fileDown : iconLib == 'Lucide (alt)' ? LucideIcons.downloadCloud : iconLib == 'iOS' ? CupertinoIcons.square_arrow_down : Icons.file_download),
                            label: const Text('Télécharger'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(iconLib == 'Lucide' ? LucideIcons.settings : iconLib == 'Lucide (alt)' ? LucideIcons.cog : iconLib == 'iOS' ? CupertinoIcons.settings : Icons.settings),
                            label: const Text('Réglages'),
                          )
                        ],
                      ),
                    ) : const SizedBox(),

                    Theme(
                      data: brightness == Brightness.dark ? darkTheme : lightTheme,
                      child: Expanded(
                        flex: 1,
                        child: Padding(
                          padding: MediaQuery.of(context).size.width > 500 ? const EdgeInsets.symmetric(horizontal: 50.0) : EdgeInsets.zero,
                          child: PageView(
                            physics: const NeverScrollableScrollPhysics(),
                            controller: _pageController,
                            children: [
                              SendPage(useCupertino: useCupertino),
                              DownloadPage(useCupertino: useCupertino),
                              SettingsPage(
                                refresh: refresh,
                                showRefreshButton: (bool value) { setState(() { showRefreshButton = value; }); },
                                updateState: () { setState(() {}); },
                                updateAcrylic: () {
                                  brightness = box.read('theme') == 'Système' ? PlatformDispatcher.instance.platformBrightness : box.read('theme') == 'Clair' ? Brightness.light : box.read('theme') == 'Sombre' ? Brightness.dark : PlatformDispatcher.instance.platformBrightness;
                                  setAcrylicEffect();
                                },
                                useCupertino: useCupertino
                              ),
                              DebugPage(refresh: refresh, useCupertino: useCupertino),
                            ]
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: MediaQuery.of(context).size.width > 600 ? null : useCupertino
            ? CupertinoTabBar(
              currentIndex: _currentIndex,
              onTap: destinationSelected,
              height: 60,
              iconSize: 28,
              backgroundColor: Colors.transparent,
              items: [
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Icon(iconLib == 'Lucide' ? LucideIcons.fileUp : iconLib == 'Lucide (alt)' ? LucideIcons.uploadCloud : iconLib == 'iOS' ? CupertinoIcons.square_arrow_up : Icons.upload_file),
                  ),
                  tooltip: '',
                  label: 'Envoyer',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Icon(iconLib == 'Lucide' ? LucideIcons.fileDown : iconLib == 'Lucide (alt)' ? LucideIcons.downloadCloud : iconLib == 'iOS' ? CupertinoIcons.square_arrow_down : Icons.file_download),
                  ),
                  tooltip: '',
                  label: 'Télécharger',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Icon(iconLib == 'Lucide' ? LucideIcons.settings : iconLib == 'Lucide (alt)' ? LucideIcons.cog : iconLib == 'iOS' ? CupertinoIcons.settings : Icons.settings),
                  ),
                  tooltip: '',
                  label: 'Réglages',
                ),
              ],
            )
            : NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: destinationSelected,
              destinations: [
                NavigationDestination(
                  icon: Icon(iconLib == 'Lucide' ? LucideIcons.fileUp : iconLib == 'Lucide (alt)' ? LucideIcons.uploadCloud : iconLib == 'iOS' ? CupertinoIcons.square_arrow_up : Icons.upload_file),
                  label: 'Envoyer',
                ),
                NavigationDestination(
                  icon: Icon(iconLib == 'Lucide' ? LucideIcons.fileDown : iconLib == 'Lucide (alt)' ? LucideIcons.downloadCloud : iconLib == 'iOS' ? CupertinoIcons.square_arrow_down : Icons.file_download),
                  label: 'Télécharger',
                ),
                NavigationDestination(
                  icon: Icon(iconLib == 'Lucide' ? LucideIcons.settings : iconLib == 'Lucide (alt)' ? LucideIcons.settings : iconLib == 'iOS' ? CupertinoIcons.settings : Icons.settings),
                  label: 'Réglages',
                ),
              ],
            )
          ),
        );
      }
    );
  }
}
