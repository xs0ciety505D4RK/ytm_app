# SoundXs backend untuk Vercel

Backend ini mempertahankan `/api/yt` untuk API katalog YouTube Music dan menambahkan `/api/audio` sebagai relai byte-range untuk URL stream HTTPS dari host `*.googlevideo.com`. Endpoint audio meneruskan permintaan `Range`/`If-Range`, membatasi redirect ke host yang sama-sama diizinkan, dan tidak menerima URL arbitrary.

## Deploy

Dari direktori `backend`, jalankan `npx vercel` dan ikuti langkah CLI untuk membuat atau memilih proyek Vercel. Setelah deployment berhasil, salin origin deployment, misalnya `https://nama-proyek.vercel.app`. Kode katalog yang sudah ada tetap berada di `/api/yt`.

Untuk mengarahkan aplikasi ke backend, build Flutter dengan:

```bash
flutter build apk --release --dart-define=BACKEND_URL=https://nama-proyek.vercel.app
```

Jangan menambahkan garis miring di akhir `BACKEND_URL`.

## Batasan

Fungsi `/api/audio` dikonfigurasi dengan `maxDuration: 300`; `/api/yt` tetap 15 detik. Batas efektif mengikuti paket dan pengaturan Vercel yang aktif. Endpoint ini hanya meneruskan URL stream yang sudah berhasil diperoleh aplikasi. Ia tidak menyelesaikan error resolver, PO-token, hak akses, atau penolakan 403 dari YouTube. Karena relay publik dapat memakai kuota bandwidth proyek, gunakan hanya untuk aplikasi sendiri dan pantau penggunaan Vercel.
