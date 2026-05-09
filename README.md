# Haunted Abandoned Building — Roblox Survival Map

Map Roblox bertema **survival horror** di sebuah gedung tua terbengkalai.
Pemain terdampar, diberi **1 alat survival (Senter)**, dan harus mengumpulkan
**5 Lampu Kuno** sambil menghindari hantu jumpscare & hantu pengejar.
Semua pemain di server yang sama bisa bertemu, **membentuk aliansi**, dan
**memecahkan teka-teki** bersama di setiap ruangan.

---

## Fitur

- Procedural Map Generator: gedung tua 3 lantai dengan banyak ruangan, lorong gelap, debu, pintu berderit.
- Quest System: 5 Lampu Kuno tersebar di ruangan random (cari & ambil).
- Tool System: setiap pemain spawn mendapat **Flashlight** (senter survival).
- Ghost System:
  - Jumpscare Ghost (muncul tiba-tiba, kaget, tidak membunuh).
  - Hunter Ghost (mengejar & membunuh pemain).
- Puzzle System: teka-teki di beberapa ruangan (pintu terkunci, butuh kode/kombinasi).
- Alliance System: pemain bisa mengundang pemain lain untuk beraliansi — aliansi berbagi progress quest & tidak saling damage.
- Atmosphere: fog gelap, ambient suara angin, langkah kaki, bisikan, petir.

---

## Cara Install ke Roblox Studio

### Opsi A — Pakai Rojo (recommended)
1. Install [Rojo](https://rojo.space/) (plugin Studio + CLI).
2. Clone repo ini: `git clone https://github.com/Zerxxz/map-roblox-new`
3. Di terminal: `rojo serve default.project.json`
4. Di Roblox Studio, buka plugin Rojo → **Connect**.
5. Script otomatis sync ke place Anda.

### Opsi B — Manual (copy-paste)
Buka file di folder `src/` lalu copy-paste ke lokasi yang sesuai di Studio:

| File                                                        | Lokasi di Studio                           | Tipe           |
|-------------------------------------------------------------|--------------------------------------------|----------------|
| `src/ReplicatedStorage/Shared/Config.lua`                   | ReplicatedStorage → Shared                 | ModuleScript   |
| `src/ReplicatedStorage/Shared/RemoteEvents.lua`             | ReplicatedStorage → Shared                 | ModuleScript   |
| `src/ReplicatedStorage/Shared/Utils.lua`                    | ReplicatedStorage → Shared                 | ModuleScript   |
| `src/ServerScriptService/Main.server.lua`                   | ServerScriptService                        | Script         |
| `src/ServerScriptService/MapGenerator.lua`                  | ServerScriptService                        | ModuleScript   |
| `src/ServerScriptService/GhostSystem.lua`                   | ServerScriptService                        | ModuleScript   |
| `src/ServerScriptService/QuestSystem.lua`                   | ServerScriptService                        | ModuleScript   |
| `src/ServerScriptService/PuzzleSystem.lua`                  | ServerScriptService                        | ModuleScript   |
| `src/ServerScriptService/AllianceSystem.lua`                | ServerScriptService                        | ModuleScript   |
| `src/ServerScriptService/ToolGiver.lua`                     | ServerScriptService                        | ModuleScript   |
| `src/StarterPlayer/StarterPlayerScripts/ClientMain.client.lua` | StarterPlayer → StarterPlayerScripts    | LocalScript    |

Pastikan nama persis sama (tanpa `.lua`/`.server.lua`/`.client.lua`).

---

## Kredit

Dibuat sebagai contoh lengkap Lua survival horror map generator untuk Roblox.
Silakan modifikasi bebas.
