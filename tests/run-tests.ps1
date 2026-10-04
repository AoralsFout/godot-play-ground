param(
    [Parameter(Mandatory = $true)]
    [string]$Godot,
    [switch]$Visual
)

$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
$runtimePath = Join-Path $projectPath '.godot/test_runtime'
$savedAppData = $env:APPDATA
$savedLocalAppData = $env:LOCALAPPDATA
$testProcesses = [System.Collections.Generic.List[System.Diagnostics.Process]]::new()

function Start-Suite([string]$Suite, [int]$Port = 17170) {
    $arguments = @('--headless', '--path', $projectPath, 'res://tests/功能验收.tscn', '--', "--suite=$Suite", "--port=$Port")
    if ($Suite -eq 'visual') {
        $arguments = @('--path', $projectPath, '--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3', '--audio-driver', 'Dummy', 'res://tests/功能验收.tscn', '--', '--suite=visual')
    }
    $logPath = Join-Path $runtimePath "$Suite.log"
    $errorPath = Join-Path $runtimePath "$Suite.errors.log"
    $process = Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $logPath -RedirectStandardError $errorPath
    $testProcesses.Add($process)
    return @{ Process = $process; Log = $logPath; ErrorLog = $errorPath; Suite = $Suite }
}

function Complete-Suite($Run) {
    if (-not $Run.Process.WaitForExit(30000)) {
        throw "Test timed out: $($Run.Suite)"
    }
    $result = Select-String -LiteralPath $Run.Log -Pattern '^RESULT' | ForEach-Object { $_.Line }
    if ($Run.Process.ExitCode -ne 0 -or -not $result) {
        Get-Content -LiteralPath $Run.Log, $Run.ErrorLog
        throw "Test failed: $($Run.Suite)"
    }
    Write-Output $result
}

function Run-NetworkPair([string]$HostSuite, [string]$ClientSuite, [int]$Port) {
    $hostRun = Start-Suite $HostSuite $Port
    $deadline = (Get-Date).AddSeconds(10)
    $ready = $false
    while ((Get-Date) -lt $deadline -and -not $hostRun.Process.HasExited) {
        if ((Test-Path -LiteralPath $hostRun.Log) -and (Select-String -LiteralPath $hostRun.Log -Pattern 'HOST_READY' -Quiet)) {
            $ready = $true
            break
        }
        Start-Sleep -Milliseconds 100
    }
    if (-not $ready) {
        Get-Content -LiteralPath $hostRun.Log, $hostRun.ErrorLog
        throw "Host failed to start: $HostSuite"
    }
    $clientRun = Start-Suite $ClientSuite $Port
    Complete-Suite $hostRun
    Complete-Suite $clientRun
}

try {
    $env:APPDATA = Join-Path $runtimePath 'roaming'
    $env:LOCALAPPDATA = Join-Path $runtimePath 'local'
    New-Item -ItemType Directory -Path $env:APPDATA, $env:LOCALAPPDATA -Force | Out-Null
    $singleRun = Start-Suite 'single'
    $failureRun = Start-Suite 'connection_failure' 17173
    Complete-Suite $singleRun
    Complete-Suite $failureRun
    Run-NetworkPair 'host' 'client' 17170
    Run-NetworkPair 'disconnect_host' 'disconnect_client' 17171
    if ($Visual) {
        Complete-Suite (Start-Suite 'visual')
    }
} finally {
    foreach ($process in $testProcesses) {
        if (-not $process.HasExited) {
            $process.Kill()
        }
        $process.Dispose()
    }
    $env:APPDATA = $savedAppData
    $env:LOCALAPPDATA = $savedLocalAppData
}
