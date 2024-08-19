library stendmobile.globals;

import 'dart:async';

void indicatePageInitialized(String pageName) {
  initializedPages[pageName] = true;
}

bool appIsInForeground = true;
Map initializedPages = {};
StreamController intereventsStreamController = StreamController.broadcast();