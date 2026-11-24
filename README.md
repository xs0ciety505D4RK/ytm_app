# SoundXs

Aplikasi pemutar musik Flutter dengan UI glassmorphism, lirik sinkron, kontrol media Android, dan Dynamic Island mengambang. Android platform files dibuat saat build agar konfigurasi CI dan APK tetap konsisten.

## Build Android

Memerlukan Flutter stable, Android SDK, Java 17, dan Python 3.

```bash
flutter pub get
flutter create . --platforms=android --org com.glass --project-name ytm_glass
python3 tool/patch_android.py
flutter build apk --release --split-per-abi \
  --target-platform android-arm,android-arm64 \
  --dart-define=BACKEND_URL=https://ytm-glass-backend.vercel.app
```

APK berada di `build/app/outputs/flutter-apk/`. Untuk APK rilis yang dapat dipasang sebagai pembaruan versi resmi, jalankan workflow **Build APK** pada GitHub; workflow memakai stable release key yang disimpan sebagai repository secrets.

## Izin Android

SoundXs meminta izin notifikasi untuk kontrol media dan izin **Tampil di atas aplikasi lain** untuk Dynamic Island. Dynamic Island menampilkan placeholder setelah diaktifkan, lalu metadata dan tombol playback ketika lagu diputar.
