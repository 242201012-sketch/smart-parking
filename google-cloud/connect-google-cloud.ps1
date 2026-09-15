$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'SmartParking Google Cloud Giris'

$candidates = @(
    (Join-Path $env:LOCALAPPDATA 'Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd'),
    'C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd',
    'C:\Program Files\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd'
)
$gcloud = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $gcloud) {
    throw 'Google Cloud CLI bulunamadi.'
}

Write-Host 'Google hesabinizla giris yapmaniz icin guvenli tarayici sayfasi aciliyor.'
Write-Host 'Sifre veya kart bilginizi bu pencereye yazmayin; yalnizca Google sayfasini kullanin.'
& $gcloud auth login --brief
if ($LASTEXITCODE -ne 0) {
    throw "Google Cloud girisi tamamlanamadi (kod: $LASTEXITCODE)."
}

Write-Host 'Google Cloud hesabi baglandi. Bu pencere birazdan kapanacak.'
Start-Sleep -Seconds 5
