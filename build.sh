#!/bin/bash

DATE=$(date +"%Y-%m-%d")

# fr.johanstick.stendmobile
echo "================= 1/4 - Android (Store)"
sed -i '' 's/fr.johanstick.stendmobile.dev/fr.johanstick.stendmobile/g' android/app/build.gradle
sed -i '' 's/fr.johanstick.stendmobile.dev/fr.johanstick.stendmobile/g' android/app/src/main/kotlin/com/example/stendmobile/MainActivity.kt
flutter build apk --release --dart-define="storeRelease=true"
mv build/app/outputs/flutter-apk/app-release.apk build/
rm -f build/StendMobile-android-$DATE-store.apk
mv build/app-release.apk build/StendMobile-android-$DATE-store.apk

# fr.johanstick.stendmobile.dev
echo "================= 2/4 - Android (Open)"
sed -i '' 's/fr.johanstick.stendmobile"/fr.johanstick.stendmobile.dev"/g' android/app/build.gradle
sed -i '' '/fr\.johanstick\.stendmobile\.dev/! s/fr\.johanstick\.stendmobile/fr.johanstick.stendmobile.dev/g' android/app/src/main/kotlin/com/example/stendmobile/MainActivity.kt
flutter build apk --release
mv build/app/outputs/flutter-apk/app-release.apk build/
rm -f build/StendMobile-android-$DATE-open.apk
mv build/app-release.apk build/StendMobile-android-$DATE-open.apk

# fr.johanstick.stendmobile
echo "================= 3/4 - iOS (Store)"
# sed -i '' 's/fr.johanstick.stendmobile.dev/fr.johanstick.stendmobile/g' ios/Runner.xcodeproj/project.pbxproj
flutter build ios --release --dart-define="storeRelease=true"
sh ./toipa.sh build/ios/iphoneos/Runner.app
mv build/ios/iphoneos/Runner.ipa build/
rm -f build/StendMobile-ios-$DATE-store.ipa
mv build/Runner.ipa build/StendMobile-ios-$DATE-store.ipa

# fr.johanstick.stendmobile.dev
echo "================= 4/4 - iOS (Open)"
sed -i '' 's/fr.johanstick.stendmobile;/fr.johanstick.stendmobile.dev;/g' ios/Runner.xcodeproj/project.pbxproj
sed -i '' 's/fr.johanstick.stendmobile.Runner/fr.johanstick.stendmobile.dev.Runner/g' ios/Runner.xcodeproj/project.pbxproj
flutter build ios --release
sh ./toipa.sh build/ios/iphoneos/Runner.app
mv build/ios/iphoneos/Runner.ipa build/
rm -f build/StendMobile-ios-$DATE-open.ipa
mv build/Runner.ipa build/StendMobile-ios-$DATE-open.ipa

echo "================= Files paths:"
echo "iOS (Store):         $(pwd)/build/StendMobile-ios-$DATE-store.ipa"
echo "iOS (Open):          $(pwd)/build/StendMobile-ios-$DATE-open.ipa"
echo "Android (Store):     $(pwd)/build/StendMobile-android-$DATE-store.apk"
echo "Android (Open):      $(pwd)/build/StendMobile-android-$DATE-open.apk"
echo "Folder:              $(pwd)/build"
echo "================="