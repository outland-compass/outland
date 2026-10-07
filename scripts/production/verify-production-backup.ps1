# Offline integrity verification of a production backup folder. Never connects to production.
param([Parameter(Mandatory)][string]$BackupDir)
$ErrorActionPreference = 'Stop'
$fail = 0
function Check($ok, $msg) { if ($ok) { Write-Host "PASS  $msg" } else { Write-Host "FAIL  $msg" -ForegroundColor Red; $script:fail++ } }

$sums = Get-Content "$BackupDir\SHA256SUMS.txt" | Where-Object { $_ -match '\S' }
foreach ($line in $sums) {
    $hash, $name = $line -split '\s+', 2
    $actual = (Get-FileHash -Algorithm SHA256 (Join-Path $BackupDir $name)).Hash.ToLower()
    Check ($actual -eq $hash.ToLower()) "sha256 $name"
}
$listed = $sums | ForEach-Object { ($_ -split '\s+', 2)[1] }
Get-ChildItem $BackupDir -File | Where-Object { $_.Name -ne 'SHA256SUMS.txt' -and $listed -notcontains $_.Name } | ForEach-Object { Check $false "unlisted file $($_.Name)" }

foreach ($f in 'roles.sql','schema.sql','data.sql','production-full.dump','inventory-migrations.csv','inventory-counts.csv','inventory-worlds.csv','inventory-candidates.csv') {
    $p = Join-Path $BackupDir $f
    Check ((Test-Path $p) -and (Get-Item $p).Length -gt 0) "present and non-empty: $f"
}
Check (-not (Test-Path "$BackupDir\production-full.dump.FAILED")) 'no failed full dump'

$toc = docker run --rm -v "${BackupDir}:/b:ro" postgres:17 pg_restore --list /b/production-full.dump
Check ($LASTEXITCODE -eq 0) 'pg_restore --list reads production-full.dump'
Check (($toc | Select-String 'TABLE DATA supabase_migrations schema_migrations') -ne $null) 'full dump has migration history'
Check (($toc | Select-String 'TABLE DATA land candidates') -ne $null) 'full dump has land.candidates data'
Check (($toc | Select-String 'TABLE DATA shared worlds') -ne $null) 'full dump has shared.worlds data'

$cand = Import-Csv "$BackupDir\inventory-candidates.csv"
$counts = Import-Csv "$BackupDir\inventory-counts.csv"
$n = ($counts | Where-Object { $_.schema -eq 'land' -and $_.table -eq 'candidates' }).n
Check ([int]$n -eq $cand.Count) "inventory candidates rows ($($cand.Count)) match count ($n)"
Write-Host "Candidates in inventory: $($cand.Count); worlds: $((Import-Csv "$BackupDir\inventory-worlds.csv").Count); applied migrations: $((Import-Csv "$BackupDir\inventory-migrations.csv").Count)"

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }