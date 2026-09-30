<#
.SYNOPSIS
Read load against the telemetry API with oha: random device ids over the fleet.

.EXAMPLE
.\read-load.ps1                                # 30 s, 256 connections, ids 0..199999
.\read-load.ps1 -Seconds 60 -Rate 20000        # fixed 20k requests/s, the requirement
.\read-load.ps1 -Devices 1000                  # ids 0..999

.NOTES
Needs oha on the PATH: winget install hatoo.oha (Windows), brew install oha (macOS), cargo install oha.
Run the hub emulator at the same time to measure reads under ingest.
#>
param(
    [string] $BaseUrl = "http://127.0.0.1:5080",
    [int] $Devices = 200000,            # ids 0..Devices-1, as the emulator's default range
    [int] $Seconds = 30,
    [int] $Connections = 256,
    [int] $Rate = 10000                 # requests per second over all connections; 0: as fast as the service answers
)

# Regex matching every integer in 0..$max, without leading zeros.
function RangeRegex([int] $max) {
    $s = [string] $max
    $n = $s.Length
    $parts = @()
    if ($n -gt 1) { $parts += "[0-9]"; if ($n -gt 2) { $parts += "[1-9][0-9]{1,$($n - 2)}" } }   # fewer digits than max
    for ($i = 0; $i -lt $n; $i++) {                                                            # same digits, below max
        $d = [int] $s[$i] - [int] [char] '0'
        $low = if ($i -eq 0 -and $n -gt 1) { 1 } else { 0 }
        if ($d -gt $low) {
            $rest = $n - $i - 1
            $tail = if ($rest -gt 0) { "[0-9]{$rest}" } else { "" }
            $parts += "$($s.Substring(0, $i))[$low-$($d - 1)]$tail"
        }
    }
    $parts += $s                                                                               # max itself
    return "(" + ($parts -join "|") + ")"
}

if (-not (Get-Command oha -ErrorAction SilentlyContinue)) {
    Write-Error "oha not found. Install it: winget install hatoo.oha"
    exit 1
}

$ids = RangeRegex ($Devices - 1)
$url = "$($BaseUrl.TrimEnd('/'))/devices/$ids/latest"
$args = @("-z", "${Seconds}s", "-c", $Connections, "--no-tui", "--latency-correction", "--rand-regex-url", $url)
if ($Rate -gt 0) { $args += @("-q", $Rate) }

Write-Host "oha $($args -join ' ')"
& oha @args
