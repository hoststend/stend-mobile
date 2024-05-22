# Aller à la racine de l'app
echo "Nettoyage des fichiers dans $PWD"

# Attendre 10 secondes pour permettre à l'utilisateur d'annuler
echo "Attente de 10 secondes"
sleep 10
echo "================="

# Nettoyer Flutter
flutter clean
flutter pub get

# Mettre à jour les splash screens
dart run flutter_native_splash:create

# Redéfinir une layer dans le fichier modifié par la lib
launch_background_file="android/app/src/main/res/drawable/launch_background.xml"
new_item='    <item><bitmap android:gravity="center" android:src="@mipmap/ic_notification" /></item>'

# Utilisation de sed pour ajouter la nouvelle ligne avant la balise </layer-list>
sed -i '' '/<\/layer-list>/i\
'"$new_item"'' $launch_background_file