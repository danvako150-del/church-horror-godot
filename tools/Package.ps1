param([string]$Name = 'Church-Godot-v29.zip')
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
& node (Join-Path $PSScriptRoot 'package.cjs')
if ($LASTEXITCODE -ne 0) { throw 'Manifest generation failed.' }
$destination = Join-Path (Split-Path $projectRoot -Parent) $Name
if (Test-Path -LiteralPath $destination) { throw 'Archive already exists. Choose a new name or move the old archive.' }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$stream = [IO.File]::Open($destination, [IO.FileMode]::CreateNew)
$archive = New-Object IO.Compression.ZipArchive($stream, [IO.Compression.ZipArchiveMode]::Create)
try {
    $manifest = Get-Content (Join-Path $projectRoot 'PROJECT_MANIFEST.json') -Raw | ConvertFrom-Json
    $paths = @($manifest.files.path) + @('PROJECT_MANIFEST.json')
    foreach ($relative in $paths) {
        $source = Join-Path $projectRoot $relative
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $source, ('church_godot/' + $relative), [IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally { $archive.Dispose(); $stream.Dispose() }
$hash = Get-FileHash -LiteralPath $destination -Algorithm SHA256
Set-Content -LiteralPath ($destination + '.sha256') -Value ($hash.Hash.ToLower() + '  ' + [IO.Path]::GetFileName($destination)) -Encoding ascii
Write-Host $destination
