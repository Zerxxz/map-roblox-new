# Cara Install Super Singkat (Tanpa Rojo)

Kalau kamu import manual dan "tidak ada output sama sekali", biasanya karena
nama/tipe Script salah. Versi bundle ini cuma butuh **2 Script**, tidak ada
Folder/Module/Shared.

## Langkah

1. Buka Roblox Studio, buka place kosong baru.
2. Di panel **Explorer**, cari `ServerScriptService`:
   - Klik kanan → **Insert Object** → **Script**
   - Rename menjadi **HauntedServer**
   - Buka scriptnya, hapus isi default, lalu **paste** seluruh isi
     [`HauntedServer.server.lua`](./HauntedServer.server.lua)
3. Masih di Explorer, buka `StarterPlayer` → `StarterPlayerScripts`:
   - Klik kanan → **Insert Object** → **LocalScript**
     (PENTING: LocalScript, bukan Script)
   - Rename menjadi **HauntedClient**
   - Buka, hapus isi default, **paste** isi
     [`HauntedClient.client.lua`](./HauntedClient.client.lua)
4. Buka menu **View** → **Output** supaya log terlihat.
5. Tekan **Play**.

## Yang harus muncul di Output

```
[HauntedServer] script dimulai
[HauntedServer] Remotes siap
[HauntedServer] Gedung selesai: 18 ruangan
[HauntedServer] 5 Lampu Kuno ditempatkan
[HauntedServer] 6 puzzle dibuat
[HauntedServer] SIAP. Cek dunia Workspace untuk melihat gedung.
[HauntedClient] mulai
[HauntedClient] UI siap
```

Kalau salah satu tidak muncul, berarti scriptnya salah tipe/lokasi. Ulangi
langkahnya.

## Troubleshooting

- **"Tidak ada output sama sekali"**
  - Pastikan `HauntedServer` adalah **Script** (bukan ModuleScript, bukan LocalScript).
  - Pastikan `HauntedClient` adalah **LocalScript** (bukan Script).
  - Pastikan lokasinya persis: `ServerScriptService` dan `StarterPlayer.StarterPlayerScripts`.
  - Pastikan window Output terbuka (View → Output).
- **"HauntedClient: Remotes folder tidak ditemukan"**
  - Berarti Server script tidak jalan. Cek point di atas.
- **Pemain spawn di air / jatuh**
  - Hapus SpawnLocation bawaan di `Workspace`. Server akan bikin spawn
    sendiri di dalam gedung. Atau biarkan saja, server akan teleport ulang
    tiap spawn.
- **Kotak-kotak abu saja, gelap banget**
  - Itu wajar - temanya horror. Senter otomatis masuk ke backpack, **equip
    dari hotbar** dan klik untuk menyalakan.
- **Jumpscare tidak muncul**
  - Jumpscare ada interval 25-60 detik. Tunggu.
