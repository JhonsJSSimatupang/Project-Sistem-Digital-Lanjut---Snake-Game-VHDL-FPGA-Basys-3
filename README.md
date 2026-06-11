#  Snake Game — VHDL FPGA Basys 3

**Project Akhir Mata Kuliah Sistem Digital Lanjut**


> Implementasi klasik **Snake Game** menggunakan bahasa **VHDL** yang berjalan langsung di atas hardware **FPGA Xilinx Basys 3**, dengan output visual ke monitor via **VGA 640×480@60Hz** dan kontrol menggunakan **keyboard PS/2**.

---

## 📚 Pengenalan Teknologi

### 🔲 Apa itu FPGA?

**FPGA (Field Programmable Gate Array)** adalah chip semikonduktor yang bisa diprogram ulang sesuai kebutuhan. Berbeda dengan prosesor biasa yang menjalankan instruksi secara berurutan, FPGA menjalankan banyak proses **secara paralel** di dalam hardware — mirip seperti kita merancang rangkaian digital sendiri.

Keunggulan FPGA:
- ⚡ Sangat cepat karena berjalan langsung di level hardware
- 🔄 Dapat diprogram ulang berkali-kali
- 🧩 Cocok untuk sistem real-time, pemrosesan sinyal, dan game sederhana

### 🛠️ Apa itu Basys 3?

**Basys 3** adalah development board FPGA buatan **Digilent** yang menggunakan chip **Xilinx Artix-7 (XC7A35T)**. Board ini sangat populer untuk pembelajaran karena sudah dilengkapi:

| Fitur | Detail |
|---|---|
| FPGA Chip | Xilinx Artix-7 XC7A35T |
| Clock Onboard | 100 MHz |
| I/O | 16 switch, 5 tombol, LED, 7-segment display |
| Port VGA | Output video ke monitor |
| Port PS/2 | Input keyboard/mouse |
| Programming | Via USB (Micro USB ke PC) |

### 💻 Apa itu VHDL?

**VHDL (VHSIC Hardware Description Language)** adalah bahasa untuk mendeskripsikan rangkaian digital. VHDL bukan bahasa pemrograman biasa — kita tidak menulis "instruksi yang dieksekusi satu per satu", melainkan **mendeskripsikan perilaku hardware** yang akan berjalan secara paralel.

Contoh perbedaan cara berpikir:
- **C/Python**: "Lakukan A, lalu B, lalu C"
- **VHDL**: "Komponen A, B, dan C semuanya aktif sekaligus dan saling terhubung"

### 🖥️ Apa itu Vivado?

**Vivado Design Suite** adalah software resmi dari **Xilinx/AMD** untuk merancang, mensimulasikan, dan mengimplementasikan desain ke FPGA Xilinx. Alur kerja di Vivado:

```
Tulis VHDL → Sintesis → Implementasi → Generate Bitstream → Upload ke FPGA
```

Download: [https://www.xilinx.com/support/download.html](https://www.xilinx.com/support/download.html)

---

## ✨ Fitur Game

- 🎮 Gameplay Snake klasik yang berjalan di atas hardware nyata
- 🖥️ Output VGA 640×480 @ 60Hz — real-time rendering setiap pixel
- ⌨️ Input keyboard PS/2 (WASD + ENTER)
- 👁️ Animasi mata ular — bergerak sesuai arah ular
- 🏆 Sistem skor live di pojok kanan atas (0–999)
- 🌵 Background bertekstur pola gurun dua warna
- 🔄 Restart tanpa perlu power-cycle, cukup tekan ENTER
- 💥 Deteksi tabrakan dinding dan self-collision

---

## 🛠️ Hardware yang Dibutuhkan

| Komponen | Fungsi |
|---|---|
| FPGA Xilinx Basys 3 | Board utama tempat game berjalan |
| Monitor dengan port VGA | Menampilkan game |
| Kabel VGA | Menghubungkan Basys 3 ke monitor |
| Keyboard PS/2 | Kontrol permainan |
| Kabel Micro USB | Programming dari PC ke Basys 3 |
| PC dengan Vivado | Untuk compile dan upload kode |

---

## 📁 Struktur Repository

```
📦 Project-Sistem-Digital-Lanjut-Snake-Game-VHDL-FPGA-Basys-3/
│
├── 📂 src/                         ← Kode sumber VHDL
│   ├── snake_game_top.vhd          ← Top-level: logika game + VGA renderer + keyboard handler
│   └── ps2_keyboard.vhd            ← Modul decoder protokol PS/2
│
├── 📂 constraints/                 ← Konfigurasi pin FPGA
│   └── Basys3_Master.xdc           ← Pemetaan sinyal ke pin fisik Basys 3
│
├── 📂 bitstream/                   ← File siap upload ke board
│   └── snake_game_top.bit          ← Bitstream hasil compile (langsung pakai!)
│
├── 📂 docs/                        ← Dokumentasi lengkap
│   ├── Laporan_Project_Akhir_..._Kelompok_2.pdf
│   └── Slide_Presentasi_..._Kelompok_2.pdf
│
├── .gitignore
└── README.md
```

---

## 🧠 Cara Kerja Sistem

### Arsitektur Keseluruhan

```
┌─────────────────────────────────────────────────────────┐
│                     FPGA Basys 3                        │
│                                                         │
│  Keyboard PS/2 ──▶ [ ps2_keyboard.vhd ]                │
│                           │ scan_code                   │
│                           ▼                             │
│                 [ snake_game_top.vhd ]                  │
│                 ┌─────────────────────┐                 │
│                 │  Input Handler      │                 │
│                 │  Game Logic (FSM)   │──▶ VGA RGB ──▶ Monitor
│                 │  VGA Renderer       │──▶ Hsync/Vsync  │
│                 │  Score Display      │                 │
│                 │  Character ROM      │                 │
│                 └─────────────────────┘                 │
│                                                         │
│  Clock 100MHz ──▶ Divider ──▶ 25MHz (pixel clock VGA)  │
└─────────────────────────────────────────────────────────┘
```

### Modul `snake_game_top.vhd` — Kode Utama

File utama ini mengandung semua logika permainan sekaligus renderer VGA. Terdiri dari beberapa bagian:

**1. Clock Divider**
Clock board 100MHz dibagi menjadi 25MHz menggunakan counter 2-bit untuk menghasilkan pixel enable signal yang tepat bagi timing VGA standar.

**2. VGA Timing Controller**
Menghasilkan sinyal Hsync dan Vsync sesuai standar 640×480@60Hz (total 800×525 pixel termasuk blanking period). Counter `h_count` dan `v_count` menggerakkan posisi pixel saat ini.

**3. Input Handler (Keyboard PS/2)**
Menangkap scan code dari modul `ps2_keyboard`, lalu menginterpretasikan:
- `5A` hex → ENTER (mulai/restart)
- `1D` hex → W (atas)
- `1B` hex → S (bawah)
- `1C` hex → A (kiri)
- `23` hex → D (kanan)
- `F0` hex → break code (tombol dilepas, diabaikan)

**4. Game Logic**
Berjalan pada game clock ~10fps (setiap 10 juta cycle = 0.1 detik):
- Hitung posisi kepala baru berdasarkan `direction`
- Cek collision dinding dan self-collision
- Geser seluruh tubuh ular dengan teknik **FIFO shift**
- Deteksi apakah kepala memakan makanan

**5. Food Generator**
Menggunakan pseudo-random sederhana: `food_counter + score` di-modulo dengan ukuran grid, lalu divalidasi agar tidak muncul di atas tubuh ular.

**6. VGA Renderer**
Proses kombinasional yang menentukan warna setiap pixel dengan urutan prioritas:
```
Teks (SCORE/PRESS ENTER/GAME OVER)
  ↓ kalau tidak ada teks
Mata ular (hitam, di kepala)
  ↓
Badan ular (hijau)
  ↓
Makanan (merah)
  ↓
Background gurun (pola dua warna kuning)
```

**7. Character ROM**
Array bitmap 8×16 pixel hardcoded untuk huruf A-Z dan angka 0-9, digunakan untuk menampilkan teks di layar tanpa memerlukan font eksternal.

---

### Modul `ps2_keyboard.vhd` — Decoder Keyboard

Keyboard PS/2 mengirimkan data secara serial dengan protokol 11-bit:
```
[Start=0] [D0] [D1] [D2] [D3] [D4] [D5] [D6] [D7] [Parity] [Stop=1]
```

Modul ini menangani:
- **Sinkronisasi multi-stage** (shift register 3-bit untuk clock, 2-bit untuk data) untuk menghindari metastability
- **Deteksi falling edge** dari PS/2 clock (pattern "100" pada history 3-bit)
- **Sampling serial** setiap bit pada saat yang tepat
- Output `scan_code` 8-bit + pulse `scan_ready` saat data lengkap

---

## 🚀 Cara Implementasi

### Opsi A — Upload Bitstream Langsung ⚡ (Paling Cepat)

Tidak perlu install Vivado, langsung pakai file `.bit` yang sudah dikompilasi:

1. Install **Vivado Lab Edition** (gratis, ukuran kecil, hanya untuk programming)
2. Hubungkan Basys 3 ke PC via **kabel Micro USB**
3. Nyalakan board (switch power ke ON)
4. Buka Vivado → **Hardware Manager** → **Open Target** → **Auto Connect**
5. Klik kanan device → **Program Device**
6. Browse ke file: `bitstream/snake_game_top.bit`
7. Klik **Program** — tunggu beberapa detik
8. Hubungkan keyboard PS/2 dan kabel VGA ke monitor
9. **Tekan ENTER dan mulai bermain!** 🎮

---

### Opsi B — Build dari Source di Vivado 🔧

Gunakan ini jika ingin memodifikasi kode atau belajar proses sintesis FPGA.

#### Langkah 1: Buat Project Baru

1. Buka **Vivado 2020.x** atau lebih baru
2. Klik **Create Project** → Next
3. Beri nama project, misalnya `snake_game` → Next
4. Pilih **RTL Project**, centang *"Do not specify sources at this time"* → Next
5. Di bagian Default Part, cari dan pilih board **Basys3**
   (atau manual: Family=Artix-7, Package=cpg236, Speed=-1, Part=xc7a35tcpg236-1)
6. Finish

#### Langkah 2: Tambahkan File VHDL

1. Di panel **Sources** → klik **+** → **Add Sources**
2. Pilih **Add or Create Design Sources** → Next
3. Klik **Add Files** → pilih kedua file berikut:
   - `src/snake_game_top.vhd`
   - `src/ps2_keyboard.vhd`
4. Centang **Copy sources into project** → Finish

#### Langkah 3: Tambahkan Constraints

1. Klik **+** lagi → **Add Sources**
2. Pilih **Add or Create Constraints** → Next
3. Klik **Add Files** → pilih: `constraints/Basys3_Master.xdc`
4. Finish

#### Langkah 4: Set Top Module

Di panel Sources, klik kanan `snake_game_top` → **Set as Top**

#### Langkah 5: Jalankan Sintesis

Di **Flow Navigator** (panel kiri):
```
Run Synthesis → (tunggu selesai) → Run Implementation → (tunggu) → Generate Bitstream
```

> Proses ini memakan waktu 5–15 menit tergantung spesifikasi PC.

#### Langkah 6: Upload ke Board

1. Setelah Generate Bitstream selesai → klik **Open Hardware Manager**
2. **Open Target** → **Auto Connect**
3. Klik kanan device → **Program Device**
4. File `.bit` otomatis terisi → klik **Program**

---

## 🎮 Cara Bermain

| Tombol | Aksi |
|---|---|
| `ENTER` | Mulai game / Restart setelah Game Over |
| `W` | Gerak ke Atas |
| `S` | Gerak ke Bawah |
| `A` | Gerak ke Kiri |
| `D` | Gerak ke Kanan |

**Aturan:**
- Makan kotak **merah** → ular bertambah panjang + skor +1
- Tabrak **dinding** atau **tubuh sendiri** → Game Over
- Tidak bisa berbalik 180° langsung (hanya boleh belok 90°)
- Skor maksimum: 999, panjang ular maksimum: 100 segmen

---

## 📐 Spesifikasi Teknis

| Parameter | Nilai |
|---|---|
| Clock utama | 100 MHz |
| Clock pixel VGA | 25 MHz |
| Resolusi output | 640 × 480 @ 60Hz |
| Area bermain | 21 × 16 kotak grid |
| Ukuran tiap kotak | 30 × 30 pixel |
| Kecepatan game | ~10 FPS (tick per 0.1 detik) |
| Panjang ular maks | 100 segmen |
| Skor maks | 999 |
| Warna output | 12-bit RGB (4-bit per channel) |

---

## 🔌 Pemetaan Pin Basys 3

| Sinyal | Pin | Keterangan |
|---|---|---|
| `clk` | W5 | Clock 100MHz dari osilator board |
| `reset` | U18 | Tombol tengah (btnC) |
| `PS2_CLK` | C17 | Clock PS/2 keyboard (pull-up aktif) |
| `PS2_DATA` | B17 | Data PS/2 keyboard (pull-up aktif) |
| `Hsync` | P19 | Horizontal sync VGA |
| `Vsync` | R19 | Vertical sync VGA |
| `vgaRed[3:0]` | N19, J19, H19, G19 | Kanal merah VGA |
| `vgaGreen[3:0]` | D17, G17, H17, J17 | Kanal hijau VGA |
| `vgaBlue[3:0]` | J18, K18, L18, N18 | Kanal biru VGA |

Detail lengkap lihat di `constraints/Basys3_Master.xdc`.

---

## 👥 Tim Pengembang

| Nama | NIM |
|---|---|
| Dennis William Situmorang | 245150307111022 | 
| Christo Alfredo Sitorus | 245150300111022 |
| Jhons Janner Samuel S. | 245150301111009 |
| Samuel Fransjemima | 245150300111038 |
| Made Nugraha Pradnyana | 245150307111012 |
| Anastasya Sheva | 245150301111034 |

