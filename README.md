# Kedai POS - Aplikasi Kasir Pintar UMKM

Aplikasi Point of Sale (POS) Android berbasis **Flutter** dengan konsep **Offline-First**, arsitektur bersih, dan antarmuka **Premium Clean Light**.

## ✨ Fitur Utama

1. **Mesin Kasir (POS):**
   - Katalog produk berbasis kategori & pencarian instan.
   - Keranjang belanja interaktif dengan tombol kuantitas cepat.
   - Pilihan metode bayar: Tunai, QRIS, Transfer Bank.
   - Tombol nominal uang pas & pecahan cepat (Rp 10.000, 20.000, 50.000, 100.000).
   - Perhitungan otomatis uang kembalian.
2. **Manajemen Produk & Stok:**
   - Tambah, edit, dan hapus katalog produk.
   - Penetapan harga beli (modal), harga jual, dan perhitungan margin keuntungan.
   - Pengingat stok menipis (*low-stock badge*).
3. **Cetak Struk Pembayaran:**
   - Pratinjau struk realistis dengan format struk belanja.
   - Siap integrasi printer thermal Bluetooth (ESC/POS 58mm / 80mm).
4. **Laporan & Ringkasan Penjualan:**
   - Ringkasan omzet harian & laba bersih (*net profit*).
   - Riwayat transaksi detail dan pencetakan ulang struk.
5. **100% Offline-First (SQLite):**
   - Semua data tersimpan lokal di perangkat Android.
   - Tidak memerlukan langganan cloud bulanan.

---

## 🚀 Build Otomatis APK via GitHub Actions (0 Beban VPS)

Workflow `.github/workflows/build-apk.yml` menjalankan analisis Dart, unit test, build APK release, verifikasi tanda tangan, dan checksum SHA-256. APK dan simbol obfuscation tersedia di **Actions > Artifacts** selama 14 hari.

Build dari branch, pull request, dan workflow manual memakai kunci sementara untuk pengujian; APK tersebut tidak dapat dipakai untuk memperbarui instalasi rilis. Rilis bertag memakai keystore permanen. Sebelum membuat tag rilis, simpan keempat secret berikut di **Settings > Secrets and variables > Actions**:

- `ANDROID_KEYSTORE_BASE64`: konten keystore upload `.jks` yang di-Base64.
- `ANDROID_KEYSTORE_PASSWORD`: kata sandi keystore.
- `ANDROID_KEY_ALIAS`: alias kunci.
- `ANDROID_KEY_PASSWORD`: kata sandi kunci.

Jaga dan cadangkan keystore permanen dengan aman. Jangan commit keystore atau `android/key.properties` ke repository. Setelah secrets tersedia, tag seperti `v1.2.0` membangun APK bertanda tangan permanen dan membuat GitHub Release beserta checksum.

### Cara Download APK uji:
1. Masuk ke halaman repositori di GitHub.
2. Klik tab **Actions** di bagian atas.
3. Klik workflow run terbaru yang berstatus centang hijau.
4. Di bagian bawah (Artifacts), klik artifact `kedai-pos-release-*` untuk mengunduh APK, checksum, dan simbol.
5. APK uji dapat dipasang, tetapi karena tanda tangannya sementara, hapus APK uji lama sebelum memasang build uji dari run berikutnya. Untuk APK yang dapat memperbarui instalasi produksi, gunakan APK dari GitHub Release bertag.

---

## 🎨 Design System
Detail spesifikasi warna, tipografi, dan komponen mengacu pada [`DESIGN.md`](./DESIGN.md).

- **Primary:** Royal Sapphire (`#2563EB`)
- **Background:** Slate 50 (`#F8FAFC`)
- **Card / Surface:** Pure White (`#FFFFFF`) dengan border halus (`#E2E8F0`)
- **Typography:** `Inter` (Sans-serif)
