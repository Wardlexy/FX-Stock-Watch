param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "fx-pushover-config.json"),
    [string]$StatePath = (Join-Path $PSScriptRoot "fx-pushover-state.json"),
    [switch]$SendStableNotifications
)

$ErrorActionPreference = "Stop"

function Get-DefaultConfig {
    @{
        pushover = @{
            token = $env:PUSHOVER_APP_TOKEN
            user  = $env:PUSHOVER_USER_KEY
        }
        thresholds = @{
            fxPercent    = 0.50
            stockPercent = 2.00
        }
        sendStableNotifications = $false
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
}

function Read-JsonFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$DefaultValue
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $DefaultValue
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $DefaultValue
    }

    return $raw | ConvertFrom-Json -AsHashtable
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Value
    )

    $Value | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Get-FxRate {
    param(
        [Parameter(Mandatory = $true)][string]$Base,
        [Parameter(Mandatory = $true)][string]$Quote
    )

    $url = "https://open.er-api.com/v6/latest/$Base"
    $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 30
    if ($response.result -ne "success") {
        throw "Gagal ambil kurs $Base/$Quote dari $url"
    }

    $rate = $response.rates.$Quote
    if ($null -eq $rate) {
        throw "Quote $Quote tidak ditemukan untuk base $Base"
    }

    [double]$rate
}

function Get-StockPrice {
    param(
        [Parameter(Mandatory = $true)][string]$Ticker
    )

    $url = "https://query1.finance.yahoo.com/v8/finance/chart/$Ticker"
    $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 30
    $result = $response.chart.result | Select-Object -First 1
    if ($null -eq $result -or $null -eq $result.meta.regularMarketPrice) {
        throw "Gagal ambil harga saham $Ticker dari Yahoo Finance"
    }

    [double]$result.meta.regularMarketPrice
}

function Format-Idr {
    param([double]$Value)
    "Rp{0:N0}" -f $Value
}

function Get-MoveStatus {
    param(
        [double]$Current,
        [AllowNull()]$Previous,
        [double]$ThresholdPercent
    )

    if ($null -eq $Previous -or [double]$Previous -eq 0) {
        return @{
            status = "baru"
            pct = $null
            significant = $true
        }
    }

    $pct = (($Current - [double]$Previous) / [double]$Previous) * 100
    $status = "stabil"
    if ($pct -ge $ThresholdPercent) {
        $status = "naik"
    }
    elseif ($pct -le (-1 * $ThresholdPercent)) {
        $status = "turun"
    }

    @{
        status = $status
        pct = $pct
        significant = [math]::Abs($pct) -ge $ThresholdPercent
    }
}

function Send-Pushover {
    param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$User,
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $body = @{
        token   = $Token
        user    = $User
        title   = $Title
        message = $Message
    }

    Invoke-RestMethod -Uri "https://api.pushover.net/1/messages.json" -Method Post -Body $body -TimeoutSec 30 | Out-Null
}

$config = Read-JsonFile -Path $ConfigPath -DefaultValue (Get-DefaultConfig)
$state = Read-JsonFile -Path $StatePath -DefaultValue @{ values = @{}; lastRun = $null }

$token = $config.pushover.token
$user = $config.pushover.user
if ([string]::IsNullOrWhiteSpace($token) -or [string]::IsNullOrWhiteSpace($user)) {
    throw "Isi pushover.token dan pushover.user di $ConfigPath, atau set env PUSHOVER_APP_TOKEN dan PUSHOVER_USER_KEY."
}

$stableEnabled = [bool]$config.sendStableNotifications -or $SendStableNotifications.IsPresent
$now = Get-Date
$lines = New-Object System.Collections.Generic.List[string]
$hasAlert = $false

foreach ($pair in $config.fxPairs) {
    $key = "FX:$($pair.label)"
    $current = Get-FxRate -Base $pair.base -Quote $pair.quote
    $previous = $state.values[$key]
    $move = Get-MoveStatus -Current $current -Previous $previous -ThresholdPercent ([double]$config.thresholds.fxPercent)
    $pctText = if ($null -eq $move.pct) { "baseline baru" } else { "{0:+0.00;-0.00;0.00}%" -f $move.pct }

    if ($move.significant -or $stableEnabled) {
        $lines.Add("$($pair.label): $(Format-Idr $current) - $($move.status) ($pctText)")
    }
    $hasAlert = $hasAlert -or [bool]$move.significant
    $state.values[$key] = $current
}

foreach ($stock in $config.stocks) {
    $key = "STOCK:$($stock.ticker)"
    $current = Get-StockPrice -Ticker $stock.ticker
    $previous = $state.values[$key]
    $move = Get-MoveStatus -Current $current -Previous $previous -ThresholdPercent ([double]$config.thresholds.stockPercent)
    $pctText = if ($null -eq $move.pct) { "baseline baru" } else { "{0:+0.00;-0.00;0.00}%" -f $move.pct }

    if ($move.significant -or $stableEnabled) {
        $lines.Add("$($stock.label) ($($stock.ticker)): $(Format-Idr $current) - $($move.status) ($pctText)")
    }
    $hasAlert = $hasAlert -or [bool]$move.significant
    $state.values[$key] = $current
}

$state.lastRun = $now.ToString("o")
Write-JsonFile -Path $StatePath -Value $state

if ($lines.Count -gt 0 -and ($hasAlert -or $stableEnabled)) {
    $title = if ($hasAlert) { "Alert kurs & saham" } else { "Kurs & saham stabil" }
    $message = ($lines -join "`n") + "`nCek: $($now.ToString("yyyy-MM-dd HH:mm:ss")) WIB"
    Send-Pushover -Token $token -User $user -Title $title -Message $message
    Write-Host "Pushover terkirim."
}
else {
    Write-Host "Tidak ada perubahan signifikan. State tetap diperbarui."
}
