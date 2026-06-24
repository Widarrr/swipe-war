# export.ps1 - Script d'export local pour Windows
# Nécessite que godot.exe soit dans votre PATH ou spécifié ci-dessous

$GodotPath = "C:\Users\ayoub\Downloads\godot463\Godot_v4.6.3-stable_win64.exe" # Modifiez si besoin

# Keystore debug : Godot efface "debug_keystore_user" des Editor Settings,
# donc on le fournit ici via variables d'environnement (sinon erreur de config Android).
$env:GODOT_ANDROID_KEYSTORE_DEBUG_PATH = "C:/Users/ayoub/AppData/Roaming/Godot/keystores/debug.keystore"
$env:GODOT_ANDROID_KEYSTORE_DEBUG_USER = "androiddebugkey"
$env:GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD = "android"

Write-Host "=== Swipe War: Export Local ===" -ForegroundColor Cyan

# Créer les répertoires de build
New-Item -ItemType Directory -Force -Path "build/web" | Out-Null
New-Item -ItemType Directory -Force -Path "build/android" | Out-Null
New-Item -ItemType Directory -Force -Path "build/ios" | Out-Null

Write-Host "[1/3] Exportation Web (HTML5)..." -ForegroundColor Yellow
Start-Process -FilePath $GodotPath -ArgumentList "--headless", "--export-release", "Web", "build/web/index.html" -NoNewWindow -Wait

if ($LASTEXITCODE -eq 0) {
    # Télécharger et injecter coi-serviceworker pour le test local si besoin
    if (-not (Test-Path "build/web/coi-serviceworker.js")) {
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/gzguidoti/coi-serviceworker/main/coi-serviceworker.min.js" -OutFile "build/web/coi-serviceworker.js" -ErrorAction SilentlyContinue
        if (Test-Path "build/web/index.html") {
            $content = Get-Content -Path "build/web/index.html" -Raw
            $content = $content -replace '<head>', '<head><script src="coi-serviceworker.js"></script>'
            Set-Content -Path "build/web/index.html" -Value $content
        }
    }
    Write-Host "Exportation Web réussie ! Fichiers dans build/web/" -ForegroundColor Green
} else {
    Write-Warning "Exportation Web échouée. Vérifiez que godot est dans votre PATH ou modifiez ce script."
}

Write-Host "[2/3] Exportation Android (APK Debug)..." -ForegroundColor Yellow
Start-Process -FilePath $GodotPath -ArgumentList "--headless", "--export-debug", "Android", "build/android/swipe-war.apk" -NoNewWindow -Wait

if ($LASTEXITCODE -eq 0) {
    Write-Host "Exportation Android réussie ! APK disponible dans build/android/swipe-war.apk" -ForegroundColor Green
} else {
    Write-Warning "Exportation Android échouée. Vérifiez votre configuration Android SDK/Keystore."
}

Write-Host "[3/3] Exportation iOS (Xcode Project)..." -ForegroundColor Yellow
if ($IsMacOS) {
    Start-Process -FilePath $GodotPath -ArgumentList "--headless", "--export-debug", "iOS", "build/ios/SwipeWar" -NoNewWindow -Wait
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Exportation iOS réussie ! Projet Xcode dans build/ios/" -ForegroundColor Green
    } else {
        Write-Warning "Exportation iOS échouée."
    }
} else {
    Write-Host "Exportation iOS ignorée (macOS requis pour compiler iOS)." -ForegroundColor DarkGray
}
