param([string]$path)

if (-not $path) {
    Write-Host "Usage: analyze_apk.ps1 <path_to_apk>"
    exit 1
}

$cleanPath = $path.Trim("'").Trim('"')
if (-not (Test-Path $cleanPath)) {
    Write-Host "File not found: '$cleanPath'"
    exit 1
}

Add-Type -Assembly System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($cleanPath)
Write-Host "=== Breakdown for $cleanPath ==="
Write-Host "Total ZIP Entries: $($zip.Entries.Count)"
Write-Host ""

$zip.Entries | Group-Object { $_.FullName.Split('/')[0] } | Select-Object Name,
    @{N='Count';E={$_.Count}},
    @{N='CompressedMB';E={[math]::Round(($_.Group | Measure-Object CompressedLength -Sum).Sum / 1MB, 2)}},
    @{N='UncompressedMB';E={[math]::Round(($_.Group | Measure-Object Length -Sum).Sum / 1MB, 2)}} | Format-Table -AutoSize

Write-Host "=== Native Libraries (lib/) Breakdown ==="
$zip.Entries | Where-Object { $_.FullName.StartsWith("lib/") } | Group-Object { $_.FullName.Split('/')[1] } | Select-Object Name,
    @{N='Count';E={$_.Count}},
    @{N='CompressedMB';E={[math]::Round(($_.Group | Measure-Object CompressedLength -Sum).Sum / 1MB, 2)}},
    @{N='UncompressedMB';E={[math]::Round(($_.Group | Measure-Object Length -Sum).Sum / 1MB, 2)}} | Format-Table -AutoSize

Write-Host "=== Top 15 Largest Files in APK ==="
$zip.Entries | Sort-Object Length -Descending | Select-Object -First 15 FullName,
    @{N='CompressedKB';E={[math]::Round($_.CompressedLength / 1KB, 1)}},
    @{N='UncompressedKB';E={[math]::Round($_.Length / 1KB, 1)}} | Format-Table -AutoSize

$zip.Dispose()
