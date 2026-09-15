$ErrorActionPreference = "Stop"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Flutter PATH içinde bulunamadı. Önce Flutter SDK'yı kurup terminali yeniden açın."
}

Push-Location $PSScriptRoot
try {
    $flutterCommand = Get-Command flutter
    $flutterSdk = Split-Path (Split-Path $flutterCommand.Source -Parent) -Parent
    $flutterSdk = $flutterSdk.Replace('\', '/')
    $localProperties = Join-Path $PSScriptRoot "android\local.properties"
    $existingProperties = if (Test-Path $localProperties) {
        Get-Content $localProperties
    } else {
        @()
    }
    @($existingProperties | Where-Object { $_ -notmatch '^flutter\.sdk=' }) +
        "flutter.sdk=$flutterSdk" | Set-Content -Encoding UTF8 $localProperties

    if (-not (Test-Path ".\android\gradlew.bat")) {
        Write-Host "Eksik Android Gradle dosyaları tamamlanıyor..." -ForegroundColor Cyan
        $bootstrap = Join-Path ([System.IO.Path]::GetTempPath()) ("smartparking_android_" + [Guid]::NewGuid().ToString("N"))
        try {
            flutter create --platforms=android --org tr.com.smartparking --project-name smart_parking_mobile $bootstrap
            Copy-Item "$bootstrap\android\gradlew" ".\android\gradlew" -Force
            Copy-Item "$bootstrap\android\gradlew.bat" ".\android\gradlew.bat" -Force
            Copy-Item "$bootstrap\android\gradle" ".\android\gradle" -Recurse -Force
        }
        finally {
            if (Test-Path $bootstrap) { Remove-Item $bootstrap -Recurse -Force }
        }
    }

    Write-Host "Flutter paketleri yükleniyor..." -ForegroundColor Cyan
    flutter pub get

    if (-not (Test-Path ".\android\app\google-services.json")) {
        Write-Warning "Firebase için android\app\google-services.json dosyasını ekleyin."
    }
    $mapsConfigured = Select-String -Path $localProperties -Pattern '^MAPS_API_KEY=(?!ADD_|\s*$).+' -Quiet
    if (-not $mapsConfigured) {
        Write-Warning "Google Maps anahtarını build-android.ps1/run-android.ps1 betiğine -MapsApiKey ile verin."
    }

    Write-Host "Kurulum tamamlandı." -ForegroundColor Green
    Write-Host "API'yi başlattıktan sonra: flutter run" -ForegroundColor Yellow
}
finally {
    Pop-Location
}
