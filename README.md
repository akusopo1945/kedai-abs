# Kedai POS - Aplikasi Kasir Pintar UMKM

Aplikasi Point of Sale (POS) Android berbasis **Flutter** dengan konsep **Offline-First**, arsitektur bersih, dan antarmuka **Premium Clean Light**.

## ✨ Fitur Utama

1. **Mesin Kasir (POS):**
   - Katalog produk berbasis kategori & pencarian instan.
   - Keranjang belanja interaktif dengan tombol kuantitas cepat.
   - Pilihan metode bayar: Tunai, QRIS, Transfer Bank / E-Wallet, Kasbon (bisa diaktif/nonaktifkan).
   - QRIS statis diunggah sekali dan ditampilkan layar penuh ke pelanggan; rekening transfer tampil dengan tombol salin.
   - No. referensi pembayaran (opsional atau wajib) tersimpan di transaksi, struk, dan rekap CSV.
   - Tombol nominal uang pas & pecahan cepat (Rp 10.000, 20.000, 50.000, 100.000).
   - Perhitungan otomatis uang kembalian.
2. **Manajemen Produk & Stok:**
   - Tambah, edit, dan hapus katalog produk.
   - Penetapan harga beli (modal), harga jual, dan perhitungan margin keuntungan.
   - Pengingat stok menipis (*low-stock badge*).
3. **Cetak Struk Bluetooth (ESC/POS 58mm / 80mm):**
   - Pilih printer thermal Bluetooth yang sudah dipasangkan di Android (tanpa izin lokasi).
   - Cetak otomatis setelah transaksi, 1–3 salinan, potong kertas otomatis, dan buka laci kas untuk pembayaran tunai.
   - Cetak ulang struk, tes cetak, cetak rekap closing, atau kirim struk lewat WhatsApp.
4. **Laporan & Ringkasan Penjualan:**
   - Ringkasan omzet harian & laba bersih (*net profit*).
   - Riwayat transaksi detail dan pencetakan ulang struk.
5. **100% Offline-First (SQLite):**
   - Semua data tersimpan lokal di perangkat Android.
   - Tidak memerlukan langganan cloud bulanan.
6. **Shift & Tutup Kasir:**
   - Shift dibuka otomatis saat transaksi pertama; modal awal kas bisa diisi.
   - Closing menghitung omzet, uang masuk per metode, kas seharusnya, dan selisih kas fisik, lalu mengunci shift.
   - Closing ditolak selama masih ada open bill atau keranjang berisi pesanan.
7. **Kasbon (Piutang Pelanggan):**
   - Metode bayar "Kasbon" mencatat penjualan sekali; pelunasan (penuh/cicil) dicatat sebagai uang masuk di shift saat dibayar, bukan penjualan baru.
   - Daftar kasbon menampilkan sisa, umur hutang, dan pengingat yang bisa dibagikan.
8. **Cadangan Data:**
   - File cadangan JSON dibuat dan dibagikan otomatis saat Tutup Kasir (Google Drive/WhatsApp), atau manual dari Pengaturan.
   - Pulihkan data di HP baru dari file cadangan.

---

## 🚀 Build Otomatis APK via GitHub Actions (0 Beban VPS)

Workflow `.github/workflows/build-apk.yml` menjalankan analisis Dart, unit test, build APK release, verifikasi tanda tangan, dan checksum SHA-256. APK/checksum tersedia di **Actions > Artifacts** selama 14 hari; simbol obfuscation disimpan sebagai artifact terpisah selama 90 hari dan tidak dipublikasikan bersama GitHub Release.

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
