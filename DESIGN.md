---
name: kedai-pos-premium-light
description: Premium Clean Light Design System for Kedai POS Android
colors:
  primary: "#2563EB"
  primaryDark: "#1D4ED8"
  primaryLight: "#EFF6FF"
  accent: "#10B981"
  background: "#F8FAFC"
  surface: "#FFFFFF"
  card: "#FFFFFF"
  textPrimary: "#0F172A"
  textSecondary: "#64748B"
  textMuted: "#94A3B8"
  border: "#E2E8F0"
  borderSubtle: "#F1F5F9"
  success: "#16A34A"
  warning: "#D97706"
  danger: "#DC2626"
typography:
  headline:
    fontFamily: "Inter"
    fontSize: "24px"
    fontWeight: "700"
    lineHeight: "32px"
  title:
    fontFamily: "Inter"
    fontSize: "18px"
    fontWeight: "600"
    lineHeight: "24px"
  body:
    fontFamily: "Inter"
    fontSize: "14px"
    fontWeight: "400"
    lineHeight: "20px"
  label:
    fontFamily: "Inter"
    fontSize: "12px"
    fontWeight: "500"
    lineHeight: "16px"
  currency:
    fontFamily: "Inter"
    fontSize: "16px"
    fontWeight: "700"
    lineHeight: "22px"
rounded:
  sm: "6px"
  md: "10px"
  lg: "14px"
  xl: "20px"
  pill: "9999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
  xxl: "32px"
---

# Kedai POS Design System

## 1. Overview
Kedai POS mengusung gaya **Premium, Clean, and Light**. Desain berfokus pada kecepatan transaksi kasir, kejelasan data numerik, dan hierarki visual yang elegan tanpa elemen berlebih.

## 2. Colors
- **Primary:** Royal Sapphire `#2563EB` memberikan impresi profesional & terpercaya.
- **Background:** Slate 50 `#F8FAFC` untuk kenyamanan visual saat operasional kasir seharian.
- **Surface & Cards:** Pure White `#FFFFFF` dengan subtle shadow `0 2px 8px rgba(15, 23, 42, 0.04)` dan border tipis `#E2E8F0`.
- **Text:** High-contrast slate `#0F172A` untuk keterbacaan optimal struk dan total nominal.

## 3. Typography
- Font clean sans-serif (`Inter`).
- Angka uang/harga selalu semi-bold atau bold.
- Label status kasir ringkas dengan letter-spacing proporsional.

## 4. Layout & Spacing
- Grid katalog kasir responsif (2 kolom pada ponsel potret, 3-4 kolom pada tablet).
- Bottom Sheet checkout ergonomis (mudah dijangkau jempol satu tangan).
- Quick cash chips (Pas, Rp 10.000, Rp 20.000, Rp 50.000, Rp 100.000).

## 5. Elevation & Depth
- Card kasir: border 1px solid `#E2E8F0`, elevation 0 atau 1dp.
- Active cart bar: Floating badge di bagian bawah dengan shadow lembut.

## 6. Shapes
- Sudut tombol & input: `12px` (modern rounded).
- Kategori badge: `9999px` (pill chip).
- Dialog checkout: `20px` top corner.

## 7. Components
- `ProductCard`: Thumbnail / inisial kategori, nama produk, stok chip, badge harga.
- `CartItemTile`: Tombol counter (+ / -) dengan haptic touch feeling.
- `ReceiptPreview`: Visualisasi struk thermal 58mm dengan garis putus-putus realistis.
- `StatCard`: Ringkasan omzet, keuntungan bersih, dan total transaksi.

## 8. Do's and Don'ts
- **DO:** Gunakan format rupiah standar (`Rp 25.000`).
- **DO:** Berikan visual feedback seketika saat produk ditekan masuk keranjang.
- **DON'T:** Jangan gunakan warna background gelap pekat secara default.
- **DON'T:** Jangan sembunyikan tombol bayar saat keranjang berisi barang.
