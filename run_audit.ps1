Add-Type -Assembly System.IO.Compression.FileSystem

$releaseApk = "C:\build\app\outputs\flutter-apk\app-release.apk"
$debugApk = "C:\build\app\outputs\flutter-apk\app-debug.apk"

function Analyze-ApkFile ($path, $label) {
    if (Test-Path $path) {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($path)
        Write-Host "=== Breakdown for $label ($path) ==="
        Write-Host "Total Zip Entries: $($zip.Entries.Count)"
        $zip.Entries | Group-Object { $_.FullName.Split('/')[0] } | Select-Object Name, Count,
            @{N='CompressedMB';E={[math]::Round(($_.Group | Measure-Object CompressedLength -Sum).Sum / 1MB, 2)}},
            @{N='UncompressedMB';E={[math]::Round(($_.Group | Measure-Object Length -Sum).Sum / 1MB, 2)}} | Format-Table -AutoSize

        Write-Host "=== Native Libraries (lib/) Breakdown for $label ==="
        $zip.Entries | Where-Object { $_.FullName.StartsWith("lib/") } | Group-Object { $_.FullName.Split('/')[1] } | Select-Object Name, Count,
            @{N='CompressedMB';E={[math]::Round(($_.Group | Measure-Object CompressedLength -Sum).Sum / 1MB, 2)}},
            @{N='UncompressedMB';E={[math]::Round(($_.Group | Measure-Object Length -Sum).Sum / 1MB, 2)}} | Format-Table -AutoSize

        Write-Host "=== Top 10 Largest Files in $label ==="
        $zip.Entries | Sort-Object Length -Descending | Select-Object -First 10 FullName,
            @{N='CompressedKB';E={[math]::Round($_.CompressedLength / 1KB, 1)}},
            @{N='UncompressedKB';E={[math]::Round($_.Length / 1KB, 1)}} | Format-Table -AutoSize

        $zip.Dispose()
    } else {
        Write-Host "Path not found: $path"
    }
}

Analyze-ApkFile $releaseApk "Release APK"
Analyze-ApkFile $debugApk "Debug APK"
