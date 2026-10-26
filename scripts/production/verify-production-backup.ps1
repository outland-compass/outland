# Offline integrity verification of a production backup folder. Never connects to production.
param(
    [Parameter(Mandatory)][string]$BackupDir,
    [switch]$RequireSideworldGroupCanaries,
    [switch]$RequireGroupPreMigrationState
)
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

# Optional strict Sideworld/Group canary checks. This never connects to production.
if ($RequireSideworldGroupCanaries -or $RequireGroupPreMigrationState) {
    $required = @('sideworld-counts.csv','sideworld-release-canaries.csv',
        'sideworld-rls.csv','sideworld-group-objects.csv','sideworld-extensions.csv')
    $all = $true
    foreach ($name in $required) {
        $p = Join-Path $BackupDir $name
        $ok = (Test-Path $p) -and (Get-Item $p).Length -gt 0
        Check $ok "SIDEWORLD canary exists: $name"
        if (-not $ok) { $all = $false }
    }
    if ($all) {
        $rows = @(Import-Csv (Join-Path $BackupDir 'sideworld-counts.csv'))
        $countObjects = @('auth.users','universe.universes','universe.worlds',
            'geo.locations','canon.quest_drafts','canon.quest_draft_revisions',
            'canon.quest_releases','player.quest_runs','player.run_receipts',
            'player.private_access','player.qa_access')
        foreach ($object in $countObjects) {
            $matching = @($rows | Where-Object { $_.object -eq $object })
            $valid = $matching.Count -eq 1
            if ($valid) { $valid = [string]$matching[0].n -match '^[0-9]+$' }
            Check $valid "SIDEWORLD row count metadata: $object"
        }
        $releaseRows = @($rows | Where-Object { $_.object -eq 'canon.quest_releases' })
        $releases = @(Import-Csv (Join-Path $BackupDir 'sideworld-release-canaries.csv'))
        if ($releaseRows.Count -eq 1 -and [string]$releaseRows[0].n -match '^[0-9]+$') {
            Check ([long]$releaseRows[0].n -eq $releases.Count) 'SIDEWORLD immutable release count parity'
        } else { Check $false 'SIDEWORLD immutable release count format' }
        foreach ($row in $releases) {
            Check (($row.engine_content_hash -match '^[a-f0-9]{64}$') -and
                ($row.document_md5 -match '^[a-f0-9]{32}$')) 'SIDEWORLD release hash format'
        }
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $matching = @($rls | Where-Object { $_.object -eq $object })
            $ok = $matching.Count -eq 1
            if ($ok) { $ok = $matching[0].rls_enabled -eq 't' -and $matching[0].anon_select -eq 'f' }
            Check $ok "SIDEWORLD RLS boundary: $object"
        }
        $groups = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
            'player.group_receipts','migration.20261024040523')) {
            $matching = @($groups | Where-Object { $_.object -eq $object })
            $ok = $matching.Count -eq 1
            if ($ok) { $ok = $matching[0].present -match '^[tf]$' }
            Check $ok "SIDEWORLD Group object inventory: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($ok -and $matching[0].present -eq 'f') "Group must be absent before migration: $object"
            }
        }
        $extensions = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($extensions.Count -gt 0) 'SIDEWORLD extension inventory'
    }
}
Write-Host 'Integrity metadata is not proof of a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }