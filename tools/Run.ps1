param([switch]$Editor, [switch]$Test, [switch]$RebuildWorld, [switch]$Compatibility)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$engine = $env:GODOT_PATH
if (!$engine) { $engine = Join-Path $PSScriptRoot 'engine\Godot_v4.5.1-stable_win64.exe' }
if (!(Test-Path -LiteralPath $engine)) {
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($command) { $engine = $command.Source }
    else { throw 'Godot not found. Place Godot 4.5+ in tools/engine or set GODOT_PATH to its executable.' }
}
$consoleEngine = $engine -replace '\.exe$', '_console.exe'
if (!(Test-Path -LiteralPath $consoleEngine)) { $consoleEngine = $engine }
if (!(Test-Path (Join-Path $projectRoot '.godot')) -or $RebuildWorld) {
    & $consoleEngine --headless --path $projectRoot --editor --import
    if ($LASTEXITCODE -ne 0) { throw 'Godot asset import failed.' }
}
if ($RebuildWorld) {
    $nodeCommand = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCommand) {
        & $nodeCommand.Source (Join-Path $PSScriptRoot 'configure-retro.cjs')
        if ($LASTEXITCODE -ne 0) { throw 'Retro texture configuration failed.' }
        & $consoleEngine --headless --path $projectRoot --editor --import
        if ($LASTEXITCODE -ne 0) { throw 'Retro texture import failed.' }
    }
    & $consoleEngine --headless --path $projectRoot --script res://tools/build-world.gd
    if ($LASTEXITCODE -ne 0) { throw 'World scene build failed.' }
}
if ($Test) {
    $nodeCommand = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCommand) {
        & $nodeCommand.Source (Join-Path $projectRoot 'tests\test_transport.cjs')
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    & $consoleEngine --headless --path $projectRoot --script res://tests/test_transport_runtime.gd --fixed-fps 60
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $consoleEngine --headless --path $projectRoot --script res://tests/test_port.gd --fixed-fps 60
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $consoleEngine --headless --path $projectRoot --script res://tests/test_retro_and_collision.gd --fixed-fps 60
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $consoleEngine --headless --path $projectRoot --script res://tests/test_windows.gd --fixed-fps 60
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $consoleEngine --headless --path $projectRoot --script res://tests/test_church_doors.gd --fixed-fps 60
    exit $LASTEXITCODE
}
$renderer = if ($Compatibility) { 'gl_compatibility' } else { 'forward_plus' }
if ($Editor) { & $engine --path $projectRoot --editor --rendering-method $renderer }
else { & $engine --path $projectRoot --rendering-method $renderer }
exit $LASTEXITCODE
