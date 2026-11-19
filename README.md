# HOW TO ÇİŞ

Ege kıyılarında geçen, 3D low-poly bir mobil balık avı oyunu. Godot 4.7 ile yapılır, Android'de oynanır.

## Oyunu telefona kurmak

1. Telefonda [en son sürümün APK dosyasını](https://github.com/ozguryilmazz/howtocis/releases/latest/download/howtocis.apk) indirin.
2. Android "bilinmeyen kaynaklardan yükleme" izni isterse, tarayıcı için izin verin.
3. Kurun ve açın. Yeni sürüm çıktığında oyunun ana menüsünde "Yeni sürüm var" düğmesi görünür.

## Klasörler

| Klasör | İçerik |
|---|---|
| `autoload/` | Her sahnede çalışan servisler: `Game` (kayıt, para, zorluk), `Firebase` (bulut kaydı), `Updater` (güncelleme kontrolü) |
| `scenes/`, `scripts/` | Ana menü, Ege koyu sahnesi, oyuncu ve dokunmatik kontroller |
| `shaders/` | Low-poly görünüm ve dalgalı deniz |
| `config/firebase.json` | Firebase web API anahtarı ve proje kimliği (gizli değildir; koruma Firestore kurallarındadır) |
| `firebase/` | Firestore güvenlik kuralları (`firebase deploy --only firestore:rules`) |
| `tools/imza-kur.ps1` | APK imza anahtarını bir kez oluşturur ve GitHub Secrets'a ekler |
| `.github/workflows/android.yml` | APK derlemesi ve sürüm yayınlama |

## Sürüm çıkarmak

```bash
git tag v0.2.0
git push origin v0.2.0
```

Etiket gönderilince GitHub Actions imzalı APK'yı derler ve **Releases** sayfasına `howtocis.apk` olarak yükler.
`main` dalına yapılan her gönderimde de test (debug) APK'sı derlenir, Actions sayfasındaki **Artifacts** bölümünden indirilebilir.

## Bilgisayarda çalıştırmak

Godot 4.7.2 ile `project.godot` dosyasını açın. Fare dokunma gibi çalışır: sol yarıda sürükleyerek yürüyün, sağ yarıda sürükleyerek bakın. Klavyede WASD ve boşluk tuşu da çalışır.
