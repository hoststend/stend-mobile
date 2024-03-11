#!/bin/bash

# Build
echo "================= Building... 0/2 (Android)"
flutter build apk --release
echo "================= Building... 1/2 (iOS)"
flutter build ios --release
echo "================= Built."

# Convert .app to .ipa (iOS)
echo "================= Converting .app to .ipa"
sh ./toipa.sh build/ios/iphoneos/Runner.app
echo "================= Converted."

# Add files to main build folder
echo "================= Moving files to build folder"
mv build/ios/iphoneos/Runner.ipa build/
mv build/app/outputs/flutter-apk/app-release.apk build/
echo "================= Moved."

# Better naming
echo "================= Renaming files"
DATE=$(date +"%Y-%m-%d")
rm -f build/StendMobile-ios-$DATE.ipa
mv build/Runner.ipa build/StendMobile-ios-$DATE.ipa
rm -f build/StendMobile-android-$DATE.apk
mv build/app-release.apk build/StendMobile-android-$DATE.apk
echo "================= Renamed."

# Logs files paths
echo "================= Files paths:"
echo "iOS:       $(pwd)/build/StendMobile-ios-$DATE.ipa"
echo "Android:   $(pwd)/build/StendMobile-android-$DATE.apk"
echo "Folder:    $(pwd)/build"
echo "================="