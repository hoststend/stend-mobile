library stendmobile.globals;

import 'dart:async';
import 'dart:io';

void indicatePageInitialized(String pageName) {
  initializedPages[pageName] = true;
}

bool isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
bool appIsInForeground = true;
Map initializedPages = {};
StreamController intereventsStreamController = StreamController.broadcast();