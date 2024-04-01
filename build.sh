#!/bin/bash

DATE=$(date +"%Y-%m-%d")

echo "================= 1/3 - Android"
flutter build apk --release
mv build/app/outputs/flutter-apk/app-release.apk build/
rm -f build/StendMobile-android-$DATE.apk
mv build/app-release.apk build/StendMobile-android-$DATE.apk

echo "================= 2/3 - iOS (Open)"
flutter build ios --release
sh ./toipa.sh build/ios/iphoneos/Runner.app
mv build/ios/iphoneos/Runner.ipa build/
rm -f build/StendMobile-ios-open-$DATE.ipa
mv build/Runner.ipa build/StendMobile-ios-open-$DATE.ipa

echo "================= 3/3 - iOS (Store)"
flutter build ios --release --dart-define="storeRelease=true"
sh ./toipa.sh build/ios/iphoneos/Runner.app
mv build/ios/iphoneos/Runner.ipa build/
rm -f build/StendMobile-ios-store-$DATE.ipa
mv build/Runner.ipa build/StendMobile-ios-store-$DATE.ipa

echo "================= Files paths:"
echo "iOS (Store):  $(pwd)/build/StendMobile-ios-store-$DATE.ipa"
echo "iOS (Open):   $(pwd)/build/StendMobile-ios-open-$DATE.ipa"
echo "Android:      $(pwd)/build/StendMobile-android-open-$DATE.apk"
echo "Folder:       $(pwd)/build"
echo "================="