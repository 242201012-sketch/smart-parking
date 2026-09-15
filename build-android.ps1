param(
    [string]$ApiBaseUrl = "",
    [string]$MapsApiKey = "",
    [string]$GoogleWebClientId = "",
    [bool]$FamilyLinkMode = $true
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Flutter PATH içinde bulunamadı. Önce Flutter stable SDK'yı kurun."
}

Push-Location $PSScriptRoot
try {
    $flutterCommand = Get-Command flutter
    $flutterSdk = (Split-Path (Split-Path $flutterCommand.Source -Parent) -Parent).Replace('\', '/')
    $localProperties = Join-Path $PSScriptRoot "android\local.properties"
    $existing = if (Test-Path $localProperties) { Get-Content $localProperties } else { @() }
    @($existing | Where-Object { $_ -notmatch '^flutter\.sdk=' }) +
        "flutter.sdk=$flutterSdk" | Set-Content -Encoding UTF8 $localProperties

    if (-not [string]::IsNullOrWhiteSpace($MapsApiKey)) {
        $existing = Get-Content $localProperties
        @($existing | Where-Object { $_ -notmatch '^MAPS_API_KEY=' }) +
            "MAPS_API_KEY=$MapsApiKey" | Set-Content -Encoding UTF8 $localProperties
    }

    $mapsConfigured = (Test-Path $localProperties) -and
        (Select-String -Path $localProperties -Pattern '^MAPS_API_KEY=(?!ADD_|\s*$).+' -Quiet)
    if (-not $mapsConfigured) {
        Write-Warning "MAPS_API_KEY tanımlı değil; harita ekranı gerçek derlemede çalışmaz."
    }
    if (-not (Test-Path (Join-Path $PSScriptRoot "android\app\google-services.json"))) {
        Write-Warning "google-services.json yok; Google girişi, FCM ve Firebase gözlemlenebilirliği pasif kalır."
    }

    Write-Host "Flutter paketleri hazırlanıyor..." -ForegroundColor Cyan
    flutter pub get

    Write-Host "Kod analizi çalıştırılıyor..." -ForegroundColor Cyan
    flutter analyze

    Write-Host "Birim testleri çalıştırılıyor..." -ForegroundColor Cyan
    flutter test

    $dartDefines = @(
        "--dart-define=FAMILY_LINK_MODE=$($FamilyLinkMode.ToString().ToLowerInvariant())"
    )
    if (-not [string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
        $dartDefines += "--dart-define=API_BASE_URL=$ApiBaseUrl"
    }
    if (-not [string]::IsNullOrWhiteSpace($GoogleWebClientId)) {
        $dartDefines += "--dart-define=GOOGLE_WEB_CLIENT_ID=$GoogleWebClientId"
    }

    Write-Host "Family Link uyumlu Android release APK oluşturuluyor..." -ForegroundColor Cyan
    & flutter build apk --release @dartDefines

    Write-Host "APK hazır:" -ForegroundColor Green
    Write-Host "$PSScriptRoot\build\app\outputs\flutter-apk\app-release.apk"

    $keyProperties = Join-Path $PSScriptRoot "android\key.properties"
    if (Test-Path $keyProperties) {
        Write-Host "Google Play için imzalı AAB oluşturuluyor..." -ForegroundColor Cyan
        & flutter build appbundle --release @dartDefines
        Write-Host "AAB hazır:" -ForegroundColor Green
        Write-Host "$PSScriptRoot\build\app\outputs\bundle\release\app-release.aab"
    }
    else {
        Write-Warning "android\key.properties yok; Google Play AAB derlemesi atlandı. APK test için hazırdır."
    }
}
finally {
    Pop-Location
}
