$ErrorActionPreference = 'Stop'

$bundleDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$address = if ($env:DOWNPEED_ADDRESS) { $env:DOWNPEED_ADDRESS } else { '127.0.0.1:17680' }
$dataDir = if ($env:DOWNPEED_DATA_DIR) {
    $env:DOWNPEED_DATA_DIR
} elseif ($env:LOCALAPPDATA) {
    Join-Path $env:LOCALAPPDATA 'Downpeed'
} else {
    Join-Path $env:USERPROFILE '.downpeed'
}

$enginePath = Join-Path $bundleDir 'downpeedd.exe'
$appPath = Join-Path $bundleDir 'downpeed.exe'
if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    throw "Missing Go engine: $enginePath"
}
if (-not (Test-Path -LiteralPath $appPath -PathType Leaf)) {
    throw "Missing Flutter client: $appPath"
}

New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
$engine = Start-Process -FilePath $enginePath `
    -ArgumentList @("--address=$address", "--data-dir=`"$dataDir`"") `
    -RedirectStandardOutput (Join-Path $dataDir 'engine.stdout.log') `
    -RedirectStandardError (Join-Path $dataDir 'engine.stderr.log') `
    -WindowStyle Hidden `
    -PassThru

try {
    Start-Sleep -Seconds 1
    if ($engine.HasExited) {
        throw "Downpeed engine failed to start. See logs in $dataDir"
    }
    $app = Start-Process -FilePath $appPath -PassThru
    $app.WaitForExit()
} finally {
    if (-not $engine.HasExited) {
        Stop-Process -Id $engine.Id
        $engine.WaitForExit()
    }
}

