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

Repository ini telah dikonfigurasi dengan workflow CI/CD `.github/workflows/build-apk.yml`. Setiap ada kode baru yang di-push ke GitHub:
1. GitHub Actions runner akan menjalankan unit test.
2. Melakukan kompilasi `flutter build apk --release`.
3. Mengunggah file instalasi `app-release.apk` ke tab **Actions > Artifacts**.
4. Jika membuat tag rilis (contoh: `git tag v1.0.0 && git push --tags`), APK akan otomatis dipublikasikan di halaman **Releases**.

### Cara Download APK:
1. Masuk ke halaman repositori di GitHub.
2. Klik tab **Actions** di bagian atas.
3. Klik workflow run terbaru yang berstatus centang hijau.
4. Di bagian bawah (Artifacts), klik `kedai-pos-release-apk` untuk mengunduh file `.apk`.
5. Salin ke ponsel Android dan pasang (install).

---

## 🎨 Design System
Detail spesifikasi warna, tipografi, dan komponen mengacu pada [`DESIGN.md`](./DESIGN.md).

- **Primary:** Royal Sapphire (`#2563EB`)
- **Background:** Slate 50 (`#F8FAFC`)
- **Card / Surface:** Pure White (`#FFFFFF`) dengan border halus (`#E2E8F0`)
- **Typography:** `Inter` (Sans-serif)
