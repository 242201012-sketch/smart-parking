param(
    [string]$ApiBaseUrl = "http://10.0.2.2:58278",
    [string]$MapsApiKey = "",
    [string]$GoogleWebClientId = ""
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
        Write-Warning "MAPS_API_KEY tanımlı değil; harita ekranı çalışmaz."
    }
    if (-not (Test-Path (Join-Path $PSScriptRoot "android\app\google-services.json"))) {
        Write-Warning "google-services.json yok; Google girişi ve push bildirimleri pasif kalır."
    }

    $runArgs = @("run", "--dart-define=API_BASE_URL=$ApiBaseUrl")
    if (-not [string]::IsNullOrWhiteSpace($GoogleWebClientId)) {
        $runArgs += "--dart-define=GOOGLE_WEB_CLIENT_ID=$GoogleWebClientId"
    }
    & flutter @runArgs
}
finally {
    Pop-Location
}
