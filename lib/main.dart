import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:get_storage/get_storage.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:stendmobile/utils/send_notification.dart';
import 'package:stendmobile/pages/download.dart';
import 'package:stendmobile/pages/send.dart';
import 'package:stendmobile/pages/settings.dart';
import 'package:stendmobile/pages/debug.dart';

// Fonction pour convertir une chaîne de caractères HEX en couleur
Color hexToColor(String code) {
  return Color(int.parse(code.substring(1, 7), radix: 16) + 0xFF000000);
}

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await GetStorage.init();

  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({Key? key}) : super(key: key);

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late GetStorage box;

  bool firstBuildPassed = false;
  int _currentIndex = 0;

  late PageController _pageController;
  late int defaultPageIndex;

  Key _refreshKey = UniqueKey();
  void refresh() {
    // mettre à jour la page par défaut
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

    setState(() {
      _currentIndex = defaultPageIndex;
      _refreshKey = UniqueKey();
    });
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

    notifInitialize();
    super.initState();
  }

  // TODO: chercher comment faire pour que on laisse l'état précédent de la page quand on change de page, et que on ne recharge pas tout à chaque fois
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var brightness = box.read('theme') == 'Système' ? MediaQuery.of(context).platformBrightness : box.read('theme') == 'Clair' ? Brightness.light : box.read('theme') == 'Sombre' ? Brightness.dark : MediaQuery.of(context).platformBrightness;

    var iconLib = box.read('iconLib');
    if (iconLib == null) {
      iconLib = Platform.isIOS ? 'Lucide' : 'Material';
      box.write('iconLib', iconLib);
    }

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

        return MaterialApp(
          key: _refreshKey,
          title: 'Stend',
          themeMode: box.read('theme') == 'Système' ? ThemeMode.system : box.read('theme') == 'Clair' ? ThemeMode.light : box.read('theme') == 'Sombre' ? ThemeMode.dark : ThemeMode.system,
          theme: ThemeData(
            colorScheme: lightColorScheme,
            primaryColor: Colors.black,
            brightness: Brightness.light,
            useMaterial3: true,
            splashFactory: Platform.isIOS ? NoSplash.splashFactory : null,
            splashColor: Platform.isIOS ? Colors.transparent : null,
            highlightColor: Platform.isIOS ? Colors.transparent : null,
          ),
          darkTheme: ThemeData(
            colorScheme: darkColorScheme,
            primaryColor: Colors.white,
            brightness: Brightness.dark,
            useMaterial3: true,
            splashFactory: Platform.isIOS ? NoSplash.splashFactory : null,
            splashColor: Platform.isIOS ? Colors.transparent : null,
            highlightColor: Platform.isIOS ? Colors.transparent : null,
            cupertinoOverrideTheme: const CupertinoThemeData(
              textTheme: CupertinoTextThemeData(),
            ),
          ),
          home: Scaffold(
            body: SafeArea(
              bottom: true,

              child: Padding(
                padding: MediaQuery.of(context).size.width > 500 ? const EdgeInsets.symmetric(horizontal: 50.0) : EdgeInsets.zero,
                child: PageView(
                  physics: const NeverScrollableScrollPhysics(),
                  controller: _pageController,
                  children: [
                    const SendPage(),
                    const DownloadPage(),
                    SettingsPage(refresh: refresh),
                    const DebugPage(),
                  ]
                ),
              ),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (int index) {
                if(index != _currentIndex) HapticFeedback.lightImpact();

                setState(() {
                  _currentIndex = index;
                });

                if(Platform.isAndroid) {
                  _pageController.animateToPage(index, duration: const Duration(milliseconds: 200), curve: Curves.ease);
                } else {
                  _pageController.jumpToPage(index);
                }
              },
              destinations: [
                NavigationDestination(
                  icon: Icon(iconLib == 'Lucide' ? LucideIcons.fileUp : iconLib == 'Lucide (alt)' ? LucideIcons.uploadCloud : iconLib == 'iOS' ? CupertinoIcons.square_arrow_up : Icons.upload_file),
                  label: 'Envoyer',
                ),
                NavigationDestination(
                  icon: Icon(iconLib == 'Lucide' ? LucideIcons.fileDown : iconLib == 'Lucide (alt)' ? LucideIcons.downloadCloud : iconLib == 'iOS' ? CupertinoIcons.square_arrow_down : Icons.file_download),
                  label: 'Télécharger',
                ),
                GestureDetector(
                  onLongPress: () {
                    HapticFeedback.lightImpact();
                    _pageController.jumpToPage(3);
                    setState(() {
                      _currentIndex = 2;
                    });
                  },

                  child: NavigationDestination(
                    tooltip: '',
                    icon: Icon(iconLib == 'Lucide' ? LucideIcons.settings : iconLib == 'Lucide (alt)' ? LucideIcons.settings : iconLib == 'iOS' ? CupertinoIcons.settings : Icons.settings),
                    label: 'Réglages',
                  ),
                ),
              ],
            )
          ),
        );
      }
    );
  }
}
