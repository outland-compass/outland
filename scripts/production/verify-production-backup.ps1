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


# Optional STRICT Group readiness mode: does not weaken verification of older
# OUTLAND backups. This proves only existence and consistency of protected
# logical backup files. It CANNOT prove restorability without isolated restore.
if ($RequireSideworldGroupCanaries -or $RequireGroupPreMigrationState) {
    $requiredCanaries = @(
        'sideworld-counts.csv',
        'sideworld-release-canaries.csv',
        'sideworld-rls.csv',
        'sideworld-group-objects.csv',
        'sideworld-extensions.csv'
    )
    $haveAll = $true
    foreach ($name in $requiredCanaries) {
        $p = Join-Path $BackupDir $name
        $ok = (Test-Path $p) -and (Get-Item $p).Length -gt 0
        Check $ok "SIDEWORLD canary present: $name"
        if (-not $ok) { $haveAll = $false }
    }
    if ($haveAll) {
        $swCounts = @(Import-Csv (Join-Path $BackupDir 'sideworld-counts.csv'))
        foreach ($object in @('auth.users','universe.universes','geo.locations',
                'canon.quest_drafts','canon.quest_draft_revisions',
                'canon.quest_releases','player.quest_runs','player.run_receipts',
                'player.private_access','player.qa_access')) {
            $rows = @($swCounts | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and "$($rows[0].n)" -match '^[0-9]+"SIDEWORLD count: $object"
        }
        $releaseCountRows = @($swCounts | Where-Object { $_.object -eq 'canon.quest_releases' })
        $canaries = @(Import-Csv (Join-Path $BackupDir 'sideworld-release-canaries.csv'))
        if ($releaseCountRows.Count -eq 1 -and "$($releaseCountRows[0].n)" -match '^[0-9]+
            Check ([long]$releaseCountRows[0].n -eq $canaries.Count) 'SIDEWORLD release canary count parity'
        }
        Check (@($canaries | Where-Object {
            $_.engine_content_hash -notmatch '^[0-9a-f]{64}
            $_.document_md5 -notmatch '^[0-9a-f]{32}        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]"Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }) "SIDEWORLD count: $object"
        }
        $releaseCountRows = @($swCounts | Where-Object { $_.object -eq 'canon.quest_releases' })
        $canaries = @(Import-Csv (Join-Path $BackupDir 'sideworld-release-canaries.csv'))
        if ($releaseCountRows.Count -eq 1 -and "$($releaseCountRows[0].n)" -match '^[0-9]+$') {
            Check ([long]$releaseCountRows[0].n -eq $canaries.Count) 'SIDEWORLD release canary count parity'
        }
        Check (@($canaries | Where-Object {
            $_.engine_content_hash -notmatch '^[0-9a-f]{64}$' -or
            $_.document_md5 -notmatch '^[0-9a-f]{32}$'
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]$') "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }) {
            Check ([long]$releaseCountRows[0].n -eq $canaries.Count) 'SIDEWORLD release canary count parity'
        }
        Check (@($canaries | Where-Object {
            $_.engine_content_hash -notmatch '^[0-9a-f]{64} -or
            $_.document_md5 -notmatch '^[0-9a-f]{32}
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }) "SIDEWORLD count: $object"
        }
        $releaseCountRows = @($swCounts | Where-Object { $_.object -eq 'canon.quest_releases' })
        $canaries = @(Import-Csv (Join-Path $BackupDir 'sideworld-release-canaries.csv'))
        if ($releaseCountRows.Count -eq 1 -and "$($releaseCountRows[0].n)" -match '^[0-9]+$') {
            Check ([long]$releaseCountRows[0].n -eq $canaries.Count) 'SIDEWORLD release canary count parity'
        }
        Check (@($canaries | Where-Object {
            $_.engine_content_hash -notmatch '^[0-9a-f]{64} -or
            $_.document_md5 -notmatch '^[0-9a-f]{32}
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' } -or
            $_.document_md5 -notmatch '^[0-9a-f]{32}
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }) "SIDEWORLD count: $object"
        }
        $releaseCountRows = @($swCounts | Where-Object { $_.object -eq 'canon.quest_releases' })
        $canaries = @(Import-Csv (Join-Path $BackupDir 'sideworld-release-canaries.csv'))
        if ($releaseCountRows.Count -eq 1 -and "$($releaseCountRows[0].n)" -match '^[0-9]+) {
            Check ([long]$releaseCountRows[0].n -eq $canaries.Count) 'SIDEWORLD release canary count parity'
        }
        Check (@($canaries | Where-Object {
            $_.engine_content_hash -notmatch '^[0-9a-f]{64} -or
            $_.document_md5 -notmatch '^[0-9a-f]{32}
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }) {
            Check ([long]$releaseCountRows[0].n -eq $canaries.Count) 'SIDEWORLD release canary count parity'
        }
        Check (@($canaries | Where-Object {
            $_.engine_content_hash -notmatch '^[0-9a-f]{64} -or
            $_.document_md5 -notmatch '^[0-9a-f]{32}
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }) "SIDEWORLD count: $object"
        }
        $releaseCountRows = @($swCounts | Where-Object { $_.object -eq 'canon.quest_releases' })
        $canaries = @(Import-Csv (Join-Path $BackupDir 'sideworld-release-canaries.csv'))
        if ($releaseCountRows.Count -eq 1 -and "$($releaseCountRows[0].n)" -match '^[0-9]+) {
            Check ([long]$releaseCountRows[0].n -eq $canaries.Count) 'SIDEWORLD release canary count parity'
        }
        Check (@($canaries | Where-Object {
            $_.engine_content_hash -notmatch '^[0-9a-f]{64} -or
            $_.document_md5 -notmatch '^[0-9a-f]{32}
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }) "SIDEWORLD count: $object"
        }
        $releaseCountRows = @($swCounts | Where-Object { $_.object -eq 'canon.quest_releases' })
        $canaries = @(Import-Csv (Join-Path $BackupDir 'sideworld-release-canaries.csv'))
        if ($releaseCountRows.Count -eq 1 -and "$($releaseCountRows[0].n)" -match '^[0-9]+) {
            Check ([long]$releaseCountRows[0].n -eq $canaries.Count) 'SIDEWORLD release canary count parity'
        }
        Check (@($canaries | Where-Object {
            $_.engine_content_hash -notmatch '^[0-9a-f]{64} -or
            $_.document_md5 -notmatch '^[0-9a-f]{32}
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }) {
            Check ([long]$releaseCountRows[0].n -eq $canaries.Count) 'SIDEWORLD release canary count parity'
        }
        Check (@($canaries | Where-Object {
            $_.engine_content_hash -notmatch '^[0-9a-f]{64} -or
            $_.document_md5 -notmatch '^[0-9a-f]{32}
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }) "SIDEWORLD count: $object"
        }
        $releaseCountRows = @($swCounts | Where-Object { $_.object -eq 'canon.quest_releases' })
        $canaries = @(Import-Csv (Join-Path $BackupDir 'sideworld-release-canaries.csv'))
        if ($releaseCountRows.Count -eq 1 -and "$($releaseCountRows[0].n)" -match '^[0-9]+) {
            Check ([long]$releaseCountRows[0].n -eq $canaries.Count) 'SIDEWORLD release canary count parity'
        }
        Check (@($canaries | Where-Object {
            $_.engine_content_hash -notmatch '^[0-9a-f]{64} -or
            $_.document_md5 -notmatch '^[0-9a-f]{32}
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' } -or
            $_.document_md5 -notmatch '^[0-9a-f]{32}
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }) "SIDEWORLD count: $object"
        }
        $releaseCountRows = @($swCounts | Where-Object { $_.object -eq 'canon.quest_releases' })
        $canaries = @(Import-Csv (Join-Path $BackupDir 'sideworld-release-canaries.csv'))
        if ($releaseCountRows.Count -eq 1 -and "$($releaseCountRows[0].n)" -match '^[0-9]+) {
            Check ([long]$releaseCountRows[0].n -eq $canaries.Count) 'SIDEWORLD release canary count parity'
        }
        Check (@($canaries | Where-Object {
            $_.engine_content_hash -notmatch '^[0-9a-f]{64} -or
            $_.document_md5 -notmatch '^[0-9a-f]{32}
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }) {
            Check ([long]$releaseCountRows[0].n -eq $canaries.Count) 'SIDEWORLD release canary count parity'
        }
        Check (@($canaries | Where-Object {
            $_.engine_content_hash -notmatch '^[0-9a-f]{64} -or
            $_.document_md5 -notmatch '^[0-9a-f]{32}
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }) "SIDEWORLD count: $object"
        }
        $releaseCountRows = @($swCounts | Where-Object { $_.object -eq 'canon.quest_releases' })
        $canaries = @(Import-Csv (Join-Path $BackupDir 'sideworld-release-canaries.csv'))
        if ($releaseCountRows.Count -eq 1 -and "$($releaseCountRows[0].n)" -match '^[0-9]+) {
            Check ([long]$releaseCountRows[0].n -eq $canaries.Count) 'SIDEWORLD release canary count parity'
        }
        Check (@($canaries | Where-Object {
            $_.engine_content_hash -notmatch '^[0-9a-f]{64} -or
            $_.document_md5 -notmatch '^[0-9a-f]{32}
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }) "SIDEWORLD count: $object"
        }
        $releaseCountRows = @($swCounts | Where-Object { $_.object -eq 'canon.quest_releases' })
        $canaries = @(Import-Csv (Join-Path $BackupDir 'sideworld-release-canaries.csv'))
        if ($releaseCountRows.Count -eq 1 -and "$($releaseCountRows[0].n)" -match '^[0-9]+) {
            Check ([long]$releaseCountRows[0].n -eq $canaries.Count) 'SIDEWORLD release canary count parity'
        }
        Check (@($canaries | Where-Object {
            $_.engine_content_hash -notmatch '^[0-9a-f]{64} -or
            $_.document_md5 -notmatch '^[0-9a-f]{32}
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }) {
            Check ([long]$releaseCountRows[0].n -eq $canaries.Count) 'SIDEWORLD release canary count parity'
        }
        Check (@($canaries | Where-Object {
            $_.engine_content_hash -notmatch '^[0-9a-f]{64} -or
            $_.document_md5 -notmatch '^[0-9a-f]{32}
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }) "SIDEWORLD count: $object"
        }
        $releaseCountRows = @($swCounts | Where-Object { $_.object -eq 'canon.quest_releases' })
        $canaries = @(Import-Csv (Join-Path $BackupDir 'sideworld-release-canaries.csv'))
        if ($releaseCountRows.Count -eq 1 -and "$($releaseCountRows[0].n)" -match '^[0-9]+) {
            Check ([long]$releaseCountRows[0].n -eq $canaries.Count) 'SIDEWORLD release canary count parity'
        }
        Check (@($canaries | Where-Object {
            $_.engine_content_hash -notmatch '^[0-9a-f]{64} -or
            $_.document_md5 -notmatch '^[0-9a-f]{32}
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' } -or
            $_.document_md5 -notmatch '^[0-9a-f]{32}
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }) "SIDEWORLD count: $object"
        }
        $releaseCountRows = @($swCounts | Where-Object { $_.object -eq 'canon.quest_releases' })
        $canaries = @(Import-Csv (Join-Path $BackupDir 'sideworld-release-canaries.csv'))
        if ($releaseCountRows.Count -eq 1 -and "$($releaseCountRows[0].n)" -match '^[0-9]+) {
            Check ([long]$releaseCountRows[0].n -eq $canaries.Count) 'SIDEWORLD release canary count parity'
        }
        Check (@($canaries | Where-Object {
            $_.engine_content_hash -notmatch '^[0-9a-f]{64} -or
            $_.document_md5 -notmatch '^[0-9a-f]{32}
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }) {
            Check ([long]$releaseCountRows[0].n -eq $canaries.Count) 'SIDEWORLD release canary count parity'
        }
        Check (@($canaries | Where-Object {
            $_.engine_content_hash -notmatch '^[0-9a-f]{64} -or
            $_.document_md5 -notmatch '^[0-9a-f]{32}
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }) "SIDEWORLD count: $object"
        }
        $releaseCountRows = @($swCounts | Where-Object { $_.object -eq 'canon.quest_releases' })
        $canaries = @(Import-Csv (Join-Path $BackupDir 'sideworld-release-canaries.csv'))
        if ($releaseCountRows.Count -eq 1 -and "$($releaseCountRows[0].n)" -match '^[0-9]+) {
            Check ([long]$releaseCountRows[0].n -eq $canaries.Count) 'SIDEWORLD release canary count parity'
        }
        Check (@($canaries | Where-Object {
            $_.engine_content_hash -notmatch '^[0-9a-f]{64} -or
            $_.document_md5 -notmatch '^[0-9a-f]{32}
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }) "SIDEWORLD count: $object"
        }
        $releaseCountRows = @($swCounts | Where-Object { $_.object -eq 'canon.quest_releases' })
        $canaries = @(Import-Csv (Join-Path $BackupDir 'sideworld-release-canaries.csv'))
        if ($releaseCountRows.Count -eq 1 -and "$($releaseCountRows[0].n)" -match '^[0-9]+) {
            Check ([long]$releaseCountRows[0].n -eq $canaries.Count) 'SIDEWORLD release canary count parity'
        }
        Check (@($canaries | Where-Object {
            $_.engine_content_hash -notmatch '^[0-9a-f]{64} -or
            $_.document_md5 -notmatch '^[0-9a-f]{32}
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }) {
            Check ([long]$releaseCountRows[0].n -eq $canaries.Count) 'SIDEWORLD release canary count parity'
        }
        Check (@($canaries | Where-Object {
            $_.engine_content_hash -notmatch '^[0-9a-f]{64} -or
            $_.document_md5 -notmatch '^[0-9a-f]{32}
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }) "SIDEWORLD count: $object"
        }
        $releaseCountRows = @($swCounts | Where-Object { $_.object -eq 'canon.quest_releases' })
        $canaries = @(Import-Csv (Join-Path $BackupDir 'sideworld-release-canaries.csv'))
        if ($releaseCountRows.Count -eq 1 -and "$($releaseCountRows[0].n)" -match '^[0-9]+) {
            Check ([long]$releaseCountRows[0].n -eq $canaries.Count) 'SIDEWORLD release canary count parity'
        }
        Check (@($canaries | Where-Object {
            $_.engine_content_hash -notmatch '^[0-9a-f]{64} -or
            $_.document_md5 -notmatch '^[0-9a-f]{32}
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' } -or
            $_.document_md5 -notmatch '^[0-9a-f]{32}
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }) "SIDEWORLD count: $object"
        }
        $releaseCountRows = @($swCounts | Where-Object { $_.object -eq 'canon.quest_releases' })
        $canaries = @(Import-Csv (Join-Path $BackupDir 'sideworld-release-canaries.csv'))
        if ($releaseCountRows.Count -eq 1 -and "$($releaseCountRows[0].n)" -match '^[0-9]+) {
            Check ([long]$releaseCountRows[0].n -eq $canaries.Count) 'SIDEWORLD release canary count parity'
        }
        Check (@($canaries | Where-Object {
            $_.engine_content_hash -notmatch '^[0-9a-f]{64} -or
            $_.document_md5 -notmatch '^[0-9a-f]{32}
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }) {
            Check ([long]$releaseCountRows[0].n -eq $canaries.Count) 'SIDEWORLD release canary count parity'
        }
        Check (@($canaries | Where-Object {
            $_.engine_content_hash -notmatch '^[0-9a-f]{64} -or
            $_.document_md5 -notmatch '^[0-9a-f]{32}
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }) "SIDEWORLD count: $object"
        }
        $releaseCountRows = @($swCounts | Where-Object { $_.object -eq 'canon.quest_releases' })
        $canaries = @(Import-Csv (Join-Path $BackupDir 'sideworld-release-canaries.csv'))
        if ($releaseCountRows.Count -eq 1 -and "$($releaseCountRows[0].n)" -match '^[0-9]+) {
            Check ([long]$releaseCountRows[0].n -eq $canaries.Count) 'SIDEWORLD release canary count parity'
        }
        Check (@($canaries | Where-Object {
            $_.engine_content_hash -notmatch '^[0-9a-f]{64} -or
            $_.document_md5 -notmatch '^[0-9a-f]{32}
        }).Count -eq 0) 'SIDEWORLD immutable release hash format'
        $rls = @(Import-Csv (Join-Path $BackupDir 'sideworld-rls.csv'))
        foreach ($object in @('canon.quest_releases','player.quest_runs','player.private_access','player.qa_access')) {
            $rows = @($rls | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f') "SIDEWORLD RLS direct-API boundary: $object"
        }
        $groupObjects = @(Import-Csv (Join-Path $BackupDir 'sideworld-group-objects.csv'))
        foreach ($object in @('player.group_sessions','player.group_members',
                'player.group_receipts','migration.20261024040523')) {
            $rows = @($groupObjects | Where-Object { $_.object -eq $object })
            Check ($rows.Count -eq 1 -and $rows[0].present -match '^[tf]) "Group object snapshot: $object"
            if ($RequireGroupPreMigrationState) {
                Check ($rows.Count -eq 1 -and $rows[0].present -eq 'f') "Group migration still pending: $object"
            }
        }
        $ext = @(Import-Csv (Join-Path $BackupDir 'sideworld-extensions.csv'))
        Check ($ext.Count -gt 0) 'SIDEWORLD extension inventory nonempty'
    }
}
Write-Host 'Note: integrity and catalog checks alone do NOT verify a successful isolated restore.'

if ($fail) { Write-Host "VERIFY: $fail check(s) FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'VERIFY: ALL CHECKS PASSED' }