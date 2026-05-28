# FX Stock Watch

Automated FX and Indonesian bank stock monitoring with Pushover alerts.

This project can run in two modes:

- **Cloud mode, recommended:** Google Apps Script. Runs even when your laptop is off.
- **Local mode, optional:** Windows PowerShell + Task Scheduler. Runs only when your PC is on and connected to the internet.

## Monitored Assets

FX pairs:

- USD/IDR
- SGD/IDR
- CNY/IDR
- EUR/IDR
- MYR/IDR
- JPY/IDR

Stocks:

- BBCA.JK
- BMRI.JK

## Cloud Setup: Google Apps Script

Use this if you want the alerts to keep running without your laptop.

File:

- `google-apps-script-fx-pushover.gs`

Setup:

1. Open [Google Apps Script](https://script.google.com/).
2. Create a new project.
3. Open `Code.gs`.
4. Replace the contents of `Code.gs` with the contents of `google-apps-script-fx-pushover.gs`.
5. In `setPushoverSecrets()`, replace:
   - `ISI_TOKEN_APP_PUSHOVER` with your Pushover app token.
   - `ISI_USER_KEY_PUSHOVER` with your Pushover user key.
6. Run `setPushoverSecrets()` once.
7. Run `setupTriggers()` once.
8. Run `checkMarketsAndNotify()` once to test the notification.

Default cloud schedule:

- 08:00 Asia/Jakarta
- 12:00 Asia/Jakarta
- 20:00 Asia/Jakarta

After the triggers are installed, Google runs the checks in the cloud. Your laptop does not need to be on.

## Local Setup: Windows PowerShell

Use this only if you also want a local Windows Scheduled Task.

Files:

- `fx-pushover-alert.ps1`
- `setup-fx-pushover-alert.ps1`

Setup:

```powershell
.\setup-fx-pushover-alert.ps1 -PushoverToken "PUSHOVER_APP_TOKEN" -PushoverUser "PUSHOVER_USER_KEY"
```

Default local schedule:

- 08:00 local time
- 12:00 local time
- 20:00 local time

This local version only runs while the Windows machine is on.

## Alert Behavior

Default thresholds:

- FX pairs: `0.50%`
- Stocks: `2.00%`

The script stores the latest checked values and compares each new value with the previous saved value.

By default, stable updates are stored but not sent as notifications. To receive notifications even when values are stable, set:

```js
sendStableNotifications: true,
```

in the Google Apps Script config.

## Notes

This project only sends monitoring alerts. It does not buy, sell, exchange, or execute any transaction automatically.

Trading, investing, and currency exchange decisions remain manual.
