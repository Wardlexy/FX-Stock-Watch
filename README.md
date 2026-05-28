# IDR Market Watch

Pantau kurs dan saham secara otomatis, lalu kirim alert ke HP lewat Pushover.

## Yang Dipantau

- USD/IDR
- SGD/IDR
- CNY/IDR
- EUR/IDR
- MYR/IDR
- JPY/IDR
- BBCA.JK
- BMRI.JK

## Versi Lokal

File:

- `fx-pushover-alert.ps1`
- `setup-fx-pushover-alert.ps1`

Jalan lewat Windows Scheduled Task saat laptop/PC menyala dan ada internet.

Contoh setup:

```powershell
.\setup-fx-pushover-alert.ps1 -PushoverToken "TOKEN_APP" -PushoverUser "USER_KEY"
```

Jadwal default:

- 08:00 WIB
- 12:00 WIB
- 20:00 WIB

## Versi Cloud

File:

- `google-apps-script-fx-pushover.gs`

Jalan lewat Google Apps Script time-driven trigger, sehingga tetap jalan walau laptop mati.

Langkah singkat:

1. Copy isi `google-apps-script-fx-pushover.gs` ke `Code.gs` di Google Apps Script.
2. Isi token dan user key Pushover di `setPushoverSecrets()`.
3. Run `setPushoverSecrets()` sekali.
4. Run `setupTriggers()` sekali.
5. Run `checkMarketsAndNotify()` untuk tes manual.

## Catatan

Project ini hanya mengirim alert naik, turun, atau stabil. Tidak ada auto-beli, auto-jual, atau transaksi otomatis. Keputusan beli, jual, dan tukar tetap manual.
