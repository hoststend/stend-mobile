#!/bin/bash

DATE=$(date +"%Y-%m-%d")

# fr.johanstick.stendmobile
echo "================= 1/5 - Android (Store - APK)"
sed -i '' 's/fr.johanstick.stendmobile.dev/fr.johanstick.stendmobile/g' android/app/build.gradle
sed -i '' 's/fr.johanstick.stendmobile.dev/fr.johanstick.stendmobile/g' android/app/src/main/kotlin/com/example/stendmobile/MainActivity.kt
flutter build apk --release --dart-define="storeRelease=true"
mv build/app/outputs/flutter-apk/app-release.apk build/
rm -f build/StendMobile-android-$DATE-store.apk
mv build/app-release.apk build/StendMobile-android-$DATE-store.apk

# fr.johanstick.stendmobile
echo "================= 2/5 - Android (Store - AAB)"
flutter build appbundle --release --dart-define="storeRelease=true"
mv build/app/outputs/bundle/release/app-release.aab build/
rm -f build/StendMobile-android-$DATE-store.aab
mv build/app-release.aab build/StendMobile-android-$DATE-store.aab

# fr.johanstick.stendmobile.dev
echo "================= 3/5 - Android (Open - APK)"
sed -i '' 's/fr.johanstick.stendmobile"/fr.johanstick.stendmobile.dev"/g' android/app/build.gradle
sed -i '' '/fr\.johanstick\.stendmobile\.dev/! s/fr\.johanstick\.stendmobile/fr.johanstick.stendmobile.dev/g' android/app/src/main/kotlin/com/example/stendmobile/MainActivity.kt
flutter build apk --release
mv build/app/outputs/flutter-apk/app-release.apk build/
rm -f build/StendMobile-android-$DATE-open.apk
mv build/app-release.apk build/StendMobile-android-$DATE-open.apk

# fr.johanstick.stendmobile
echo "================= 4/5 - iOS (Store - IPA)"
# sed -i '' 's/fr.johanstick.stendmobile.dev/fr.johanstick.stendmobile/g' ios/Runner.xcodeproj/project.pbxproj
flutter build ios --release --dart-define="storeRelease=true"
sh ./toipa.sh build/ios/iphoneos/Runner.app
mv build/ios/iphoneos/Runner.ipa build/
rm -f build/StendMobile-ios-$DATE-store.ipa
mv build/Runner.ipa build/StendMobile-ios-$DATE-store.ipa

# fr.johanstick.stendmobile.dev
echo "================= 5/5 - iOS (Open - IPA)"
sed -i '' 's/fr.johanstick.stendmobile;/fr.johanstick.stendmobile.dev;/g' ios/Runner.xcodeproj/project.pbxproj
sed -i '' 's/fr.johanstick.stendmobile.Runner/fr.johanstick.stendmobile.dev.Runner/g' ios/Runner.xcodeproj/project.pbxproj
flutter build ios --release
sh ./toipa.sh build/ios/iphoneos/Runner.app
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