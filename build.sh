#!/bin/bash

DATE=$(date +"%Y-%m-%d")

# Release Android - Store - APK
echo "================= 1/5 - Android (Store - APK)"
flutter build apk --release --dart-define="storeRelease=true"
mv build/app/outputs/flutter-apk/app-release.apk build/
rm -f build/StendMobile-android-$DATE-store.apk
mv build/app-release.apk build/StendMobile-android-$DATE-store.apk

# Release Android - Store - AAB
echo "================= 2/5 - Android (Store - AAB)"
flutter build appbundle --release --dart-define="storeRelease=true"
mv build/app/outputs/bundle/release/app-release.aab build/
rm -f build/StendMobile-android-$DATE-store.aab
mv build/app-release.aab build/StendMobile-android-$DATE-store.aab

# Release Android - Open - APK
echo "================= 3/5 - Android (Open - APK)"
flutter build apk --release
mv build/app/outputs/flutter-apk/app-release.apk build/
rm -f build/StendMobile-android-$DATE-open.apk
mv build/app-release.apk build/StendMobile-android-$DATE-open.apk

# Release iOS - Store - IPA
echo "================= 4/5 - iOS (Store - IPA)"
flutter build ios --release --dart-define="storeRelease=true"
sh ./utils/toipa.sh build/ios/iphoneos/Runner.app
mv build/ios/iphoneos/Runner.ipa build/
rm -f build/StendMobile-ios-$DATE-store.ipa
mv build/Runner.ipa build/StendMobile-ios-$DATE-store.ipa

# Release iOS - Open - IPA
echo "================= 5/5 - iOS (Open - IPA)"
flutter build ios --release
sh ./utils/toipa.sh build/ios/iphoneos/Runner.app
mv build/ios/iphoneos/Runner.ipa build/
rm -f build/StendMobile-ios-$DATE-open.ipa
mv build/Runner.ipa build/StendMobile-ios-$DATE-open.ipa

echo "================= Files paths:"
echo "iOS (Store IPA):        $(pwd)/build/StendMobile-ios-$DATE-store.ipa"
echo "iOS (Open IPA):         $(pwd)/build/StendMobile-ios-$DATE-open.ipa"
echo "Android (Store AAB):    $(pwd)/build/StendMobile-android-$DATE-store.aab"
echo "Android (Store APK):    $(pwd)/build/StendMobile-android-$DATE-store.apk"
echo "Android (Open APK):     $(pwd)/build/StendMobile-android-$DATE-open.apk"
echo "Folder:                 $(pwd)/build"
echo "================="