# Offline integrity verification of a staging backup folder. Never connects to staging.
#   powershell -ExecutionPolicy Bypass -File verify-backup.ps1 -BackupDir C:\Users\ThinkPad\outland-backups\staging-YYYYMMDD-HHMMSS
param([Parameter(Mandatory)][string]$BackupDir)
$ErrorActionPreference = 'Stop'
$fail = 0
function Check($ok, $msg) { if ($ok) { Write-Host "PASS  $msg" } else { Write-Host "FAIL  $msg" -ForegroundColor Red; $script:fail++ } }

# 1. Checksums
$sums = Get-Content "$BackupDir\SHA256SUMS.txt" | Where-Object { $_ -match '\S' }
foreach ($line in $sums) {
    $hash, $name = $line -split '\s+', 2
    $actual = (Get-FileHash -Algorithm SHA256 (Join-Path $BackupDir $name)).Hash.ToLower()
    Check ($actual -eq $hash.ToLower()) "sha256 $name"
}
$listed = $sums | ForEach-Object { ($_ -split '\s+', 2)[1] }
Get-ChildItem $BackupDir -File | Where-Object { $_.Name -ne 'SHA256SUMS.txt' -and $listed -notcontains $_.Name } |
    ForEach-Object { Check $false "unlisted file $($_.Name)" }

# 2. Required files, non-empty
foreach ($f in 'roles.sql','schema.sql','data.sql','staging-full.dump','inventory-migrations.csv','inventory-counts.csv','inventory-worlds.csv','inventory-candidates.csv') {
    $p = Join-Path $BackupDir $f
    Check ((Test-Path $p) -and (Get-Item $p).Length -gt 0) "present and non-empty: $f"
}
Check (-not (Test-Path "$BackupDir\staging-full.dump.FAILED")) 'no failed full dump'

# 3. Content sanity
$schema = Get-Content "$BackupDir\schema.sql" -Raw
foreach ($t in '"shared"."worlds"','"land"."candidates"') { Check ($schema.Contains("CREATE TABLE IF NOT EXISTS $t") -or $schema.Contains("CREATE TABLE $t")) "schema.sql defines $t" }
$data = Get-Content "$BackupDir\data.sql" -Raw
foreach ($t in '"shared"."worlds"','"land"."candidates"') { Check ($data.Contains("COPY $t")) "data.sql has COPY for $t" }

# 4. Full dump readable by pg_restore and contains migration history + candidates data
$toc = docker run --rm -v "${BackupDir}:/b:ro" postgres:17 pg_restore --list /b/staging-full.dump
Check ($LASTEXITCODE -eq 0) 'pg_restore --list reads staging-full.dump'
Check (($toc | Select-String 'TABLE DATA supabase_migrations schema_migrations') -ne $null) 'full dump has supabase_migrations.schema_migrations data'
Check (($toc | Select-String 'TABLE DATA land candidates') -ne $null) 'full dump has land.candidates data'
Check (($toc | Select-String 'TABLE DATA shared worlds') -ne $null) 'full dump has shared.worlds data'

# 5. Inventory cross-checks
$cand = Import-Csv "$BackupDir\inventory-candidates.csv"
$counts = Import-Csv "$BackupDir\inventory-counts.csv"
$n = ($counts | Where-Object { $_.schema -eq 'land' -and $_.table -eq 'candidates' }).n
Check ([int]$n -eq $cand.Count) "inventory candidates rows ($($cand.Count)) match count ($n)"
Write-Host "Candidates in inventory: $($cand.Count); worlds: $((Import-Csv "$BackupDir\inventory-worlds.csv").Count); applied migrations: $((Import-Csv "$BackupDir\inventory-migrations.csv").Count)"

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }
