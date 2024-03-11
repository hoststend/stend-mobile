import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:get_storage/get_storage.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:stendmobile/pages/download.dart';
import 'package:stendmobile/pages/send.dart';
import 'package:stendmobile/pages/settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();

  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({Key? key}) : super(key: key);

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late PageController _pageController;
  late GetStorage box;
  bool firstBuildPassed = false;
  int _currentIndex = 0;

  @override
  void initState() {
    box = GetStorage();

    var defaultPage = box.read('defaultPage');
    if (defaultPage == null) {
      _pageController = PageController(initialPage: 0);
    } else if (defaultPage == 'Envoyer') {
      _pageController = PageController(initialPage: 0);
    } else if (defaultPage == 'Télécharger') {
      _pageController = PageController(initialPage: 1);
      _currentIndex = 1;
    } else if (defaultPage == 'Réglages') {
      _pageController = PageController(initialPage: 2);
      _currentIndex = 2;
    }

    super.initState();
  }

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

      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ));
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    return DynamicColorBuilder(
      builder: (lightColorScheme, darkColorScheme) {
        return MaterialApp(
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
                  children: const [
                    SendPage(),
                    DownloadPage(),
                    SettingsPage(),
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

                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.ease,
                );
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
