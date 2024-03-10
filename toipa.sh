#!/bin/sh

# https://gist.github.com/el2zay/1eeda0eb58032157d9f6a17e13d25339

if [ "$#" -lt 1 ]; then
    echo "Please enter a file name."
    exit 1
fi

file="$1"

if [ "${file: -4}" != ".app" ]; then
    echo "The file extension is not .app"
    exit 1
fi

if [ ! -e "$file" ]; then
    echo "File does not exist."
    exit 1
fi

echo "Please Wait..."

mkdir Payload

cp -r "$file" Payload

mv Payload/"$file" Payload/"$file".app

file="${file%.*}"

zip -r "$file".ipa Payload


rm -rf Payload

echo "Done !"

if [ "$(uname)" == "Darwin" ]; then
    # Ouvrir le dossier en paramètre dans le Finder
    open -R "$file.ipa"
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    xdg-open "$file.ipa"
elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
    explorer /select,"$file.ipa"
fi