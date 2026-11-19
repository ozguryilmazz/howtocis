# HOW TO ÇİŞ - APK imza anahtarı kurulumu
#
# Bu betik bir kez çalıştırılır:
#   1. Rastgele bir şifreyle Android imza anahtarı (keystore) oluşturur.
#   2. Anahtarı ve şifreyi Belgeler\howtocis-imza klasörüne kaydeder.
#   3. Anahtarı GitHub Secrets'a ekler, böylece GitHub Actions imzalı APK derleyebilir.
#
# ÖNEMLİ: Belgeler\howtocis-imza klasörünü güvenli bir yere (USB bellek, bulut) yedekleyin.
# Anahtar kaybolursa telefondaki oyun güncellenemez, silinip yeniden kurulması gerekir.

$ErrorActionPreference = "Stop"
$repo = "ozguryilmazz/howtocis"
$gh = "C:\Program Files\GitHub CLI\gh.exe"
$dir = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "howtocis-imza"
$ks = Join-Path $dir "howtocis-release.keystore"

if (Test-Path $ks) {
    Write-Host "Anahtar zaten var: $ks" -ForegroundColor Yellow
    Write-Host "Yeni anahtar oluşturulmadı. Mevcut anahtarı kullanmaya devam edin."
    exit 1
}

$keytool = (Get-Command keytool -ErrorAction SilentlyContinue).Source
if (-not $keytool) {
    $java = (Get-Command java -ErrorAction Stop).Source
    $keytool = Join-Path (Split-Path $java) "keytool.exe"
}

New-Item -ItemType Directory -Force $dir | Out-Null
$chars = [char[]]((48..57) + (65..90) + (97..122))
$pass = -join (1..32 | ForEach-Object { $chars | Get-Random })

& $keytool -genkeypair -keystore $ks -storetype PKCS12 -alias howtocis -keyalg RSA -keysize 2048 `
    -validity 10000 -storepass $pass -keypass $pass -dname "CN=HOW TO CIS, O=howtocis, C=TR" | Out-Null
if (-not (Test-Path $ks)) { throw "Anahtar oluşturulamadı." }

Set-Content -Path (Join-Path $dir "SIFRE.txt") -Encoding UTF8 -Value @"
HOW TO ÇİŞ imza anahtarı - BU KLASÖRÜ YEDEKLEYİN, KİMSEYLE PAYLAŞMAYIN
Dosya : $ks
Alias : howtocis
Şifre : $pass
"@

$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($ks))
$b64 | & $gh secret set ANDROID_KEYSTORE_BASE64 -R $repo
$pass | & $gh secret set ANDROID_KEYSTORE_PASSWORD -R $repo
"howtocis" | & $gh secret set ANDROID_KEY_ALIAS -R $repo

Write-Host ""
Write-Host "Tamam. İmza anahtarı oluşturuldu ve GitHub'a eklendi." -ForegroundColor Green
Write-Host "Şimdi şu klasörü yedekleyin: $dir" -ForegroundColor Yellow
