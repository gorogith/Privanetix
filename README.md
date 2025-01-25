## 🔧 Persyaratan Sistem

- OS: Ubuntu/Debian
- RAM: Minimal 4GB
- Storage: Minimal 20GB
- CPU: Minimal 2 core
- Docker (akan diinstal otomatis jika belum ada)



## 🚀 Quick Start

Buat folder dan masuk ke direktori

```
mkdir privasea
cd privasea
```

Download script
```
curl -LO https://raw.githubusercontent.com/gorogith/Privanetix/main/privasea.sh
```

Berikan permission eksekusi
```
chmod +x privasea.sh
```

Jalankan script
```
./privasea.sh
```


## 🔍 Troubleshooting

### Node Tidak Berjalan
- Pastikan node sudah terdaftar di dashboard
- Periksa file konfigurasi di `~/privasea/config/`
- Periksa logs dengan opsi "Check Node Status"

### Error Umum
- "Node not configured" - Daftar node di dashboard
- "Password file missing" - Jalankan setup ulang
- "Docker error" - Restart Docker service
