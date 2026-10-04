$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

function Invoke-Checked {
    param([string]$Program, [string[]]$Arguments)
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed with exit code $LASTEXITCODE" }
}

Invoke-Checked python @((Join-Path $repoRoot 'tools/test_vendor.py'))

foreach ($package in @('packages/aurora', 'packages/aurora_flutter', 'examples/theater', 'examples/textures')) {
    Push-Location (Join-Path $repoRoot $package)
    try {
        if ($package -eq 'packages/aurora') {
            Invoke-Checked dart @('pub', 'get')
            Invoke-Checked dart @('format', '--output=none', '--set-exit-if-changed', 'lib', 'test', 'tool', 'example', 'bin')
            Invoke-Checked dart @('analyze')
            Invoke-Checked dart @('test')
        } else {
            Invoke-Checked flutter @('pub', 'get')
            $formatPaths = @('lib')
            if (Test-Path -LiteralPath 'test') { $formatPaths += 'test' }
            Invoke-Checked dart (@('format', '--output=none', '--set-exit-if-changed') + $formatPaths)
            Invoke-Checked flutter @('analyze')
            if (Test-Path -LiteralPath 'test') { Invoke-Checked flutter @('test') }
        }
    } finally {
        Pop-Location
    }
}
