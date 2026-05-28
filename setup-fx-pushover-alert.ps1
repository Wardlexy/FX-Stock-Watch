param(
    [Parameter(Mandatory = $true)][string]$PushoverToken,
    [Parameter(Mandatory = $true)][string]$PushoverUser,
    [string]$TaskName = "USD SGD BBCA BMRI Watch",
    [double]$FxThresholdPercent = 0.50,
    [double]$StockThresholdPercent = 2.00,
    [switch]$SendStableNotifications
)

$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $PSScriptRoot "fx-pushover-alert.ps1"
$configPath = Join-Path $PSScriptRoot "fx-pushover-config.json"

if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "File tidak ditemukan: $scriptPath"
}

$config = @{
    pushover = @{
        token = $PushoverToken
        user  = $PushoverUser
    }
    thresholds = @{
        fxPercent    = $FxThresholdPercent
        stockPercent = $StockThresholdPercent
    }
    sendStableNotifications = $SendStableNotifications.IsPresent
    fxPairs = @(
        @{ label = "USD/IDR"; base = "USD"; quote = "IDR" },
        @{ label = "SGD/IDR"; base = "SGD"; quote = "IDR" },
        @{ label = "CNY/IDR"; base = "CNY"; quote = "IDR" },
        @{ label = "EUR/IDR"; base = "EUR"; quote = "IDR" },
        @{ label = "MYR/IDR"; base = "MYR"; quote = "IDR" },
        @{ label = "JPY/IDR"; base = "JPY"; quote = "IDR" }
    )
    stocks = @(
        @{ label = "BCA"; ticker = "BBCA.JK" },
        @{ label = "Mandiri"; ticker = "BMRI.JK" }
    )
}

$config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configPath -Encoding UTF8

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

$triggers = @(
    New-ScheduledTaskTrigger -Daily -At "08:00",
    New-ScheduledTaskTrigger -Daily -At "12:00",
    New-ScheduledTaskTrigger -Daily -At "20:00"
)

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $triggers `
    -Settings $settings `
    -Description "Pantau USD/IDR, SGD/IDR, CNY/IDR, EUR/IDR, MYR/IDR, JPY/IDR, BBCA.JK, BMRI.JK dan kirim alert Pushover." `
    -Force | Out-Null

Write-Host "Config tersimpan: $configPath"
Write-Host "Scheduled Task dibuat/diupdate: $TaskName"
Write-Host "Jadwal: 08:00, 12:00, 20:00 WIB saat PC nyala dan ada internet."
Write-Host "Tes manual:"
Write-Host "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -SendStableNotifications"
