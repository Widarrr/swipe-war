#!/bin/bash
# export.sh - Script d'export local pour macOS/Linux

GODOT_PATH="godot" # Modifiez si besoin

echo -e "\e[36m=== Swipe War: Export Local ===\e[0m"

# Créer les dossiers
mkdir -p build/web
mkdir -p build/android
mkdir -p build/ios

echo -e "\e[33m[1/3] Exportation Web (HTML5)...\e[0m"
$GODOT_PATH --headless --export-release "Web" build/web/index.html

if [ $? -eq 0 ]; then
    # Injecter coi-serviceworker
    curl -sSL https://raw.githubusercontent.com/gzguidoti/coi-serviceworker/main/coi-serviceworker.min.js -o build/web/coi-serviceworker.js
    sed -i 's|<head>|<head><script src="coi-serviceworker.js"></script>|g' build/web/index.html
    echo -e "\e[32mExportation Web réussie ! Fichiers dans build/web/\e[0m"
else
    echo -e "\e[31mExportation Web échouée. Vérifiez votre PATH.\e[0m"
fi

echo -e "\e[33m[2/3] Exportation Android (APK Debug)...\e[0m"
$GODOT_PATH --headless --export-debug "Android" build/android/swipe-war.apk

if [ $? -eq 0 ]; then
    echo -e "\e[32mExportation Android réussie ! APK disponible dans build/android/swipe-war.apk\e[0m"
else
    echo -e "\e[31mExportation Android échouée.\e[0m"
fi

echo -e "\e[33m[3/3] Exportation iOS (Xcode Project)...\e[0m"
if [[ "$OSTYPE" == "darwin"* ]]; then
    $GODOT_PATH --headless --export-debug "iOS" build/ios/SwipeWar
    if [ $? -eq 0 ]; then
        echo -e "\e[32mExportation iOS réussie ! Projet Xcode dans build/ios/\e[0m"
    else
        echo -e "\e[31mExportation iOS échouée.\e[0m"
    fi
else
    echo -e "\e[90mExportation iOS ignorée (macOS requis pour compiler iOS).\e[0m"
fi
