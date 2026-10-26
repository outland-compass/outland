# OFFLINE ONLY. Compare existing SIDEWORLD canaries from protected backup and
# independently isolated restore. No network, DB access, secrets or writes.
param(
    [Parameter(Mandatory)][string]$BackupDir,
    [Parameter(Mandatory)][string]$RestoreDir,
    [switch]$AfterGroupMigration
)
$ErrorActionPreference = 'Stop'
$failures = 0
function Check($pass, $label) {
    if ($pass) { Write-Host "PASS $label" }
    else { Write-Host "FAIL $label"; $script:failures++ }
}
function Load($root, $name) {
    $file = Join-Path $root $name
    if (-not (Test-Path $file) -or (Get-Item $file).Length -eq 0) { throw 'CANARY_FILE_MISSING' }
    return @(Import-Csv $file)
}
function Canonical($rows) {
    # Serialize ordered field/value pairs, preserving CSV column order.
    # Internal values are never printed, even when parity fails.
    $lines = foreach ($row in $rows) {
        $item = @($row.PSObject.Properties | ForEach-Object { $_.Name + '=' + $_.Value })
        $item -join [char]31
    }
    return (@($lines | Sort-Object -CaseSensitive) -join [char]30)
}
function CompareCsv($name) {
    $source = @(Load $BackupDir $name)
    $restored = @(Load $RestoreDir $name)
    Check ((Canonical $source) -ceq (Canonical $restored)) "PARITY $name"
}
function Has($rows, $key) {
    return @($rows | Where-Object { $_.object -eq $key })
}
try {
    if ((Resolve-Path $BackupDir).Path -eq (Resolve-Path $RestoreDir).Path) { throw 'SAME_SOURCE_AND_RESTORE_DIRECTORY' }
    foreach ($name in @('sideworld-counts.csv','sideworld-release-canaries.csv','sideworld-extensions.csv')) {
        CompareCsv $name
    }
    $sourceRls = @(Load $BackupDir 'sideworld-rls.csv')
    $restoredRls = @(Load $RestoreDir 'sideworld-rls.csv')
    $sourceNames = @($sourceRls | ForEach-Object { $_.object })
    $baselineRestored = @($restoredRls | Where-Object { $sourceNames -contains $_.object })
    Check ((Canonical $sourceRls) -ceq (Canonical $baselineRestored)) 'BASELINE RLS and grants unchanged'
    Check ((@($baselineRestored | ForEach-Object { $_.object } | Select-Object -Unique)).Count -eq $sourceRls.Count) 'NO missing/duplicate baseline RLS entries'
    $sourceGroup = @(Load $BackupDir 'sideworld-group-objects.csv')
    $restoreGroup = @(Load $RestoreDir 'sideworld-group-objects.csv')
    $tables = @('player.group_sessions','player.group_members','player.group_receipts')
    $migration = 'migration.20261024040523'
    foreach ($key in @($tables) + @($migration)) {
        $original = @(Has $sourceGroup $key)
        Check ($original.Count -eq 1 -and $original[0].present -eq 'f') "PRE-MIGRATION source baseline: $key"
        $restored = @(Has $restoreGroup $key)
        $expected = if ($AfterGroupMigration) { 't' } else { 'f' }
        Check ($restored.Count -eq 1 -and $restored[0].present -eq $expected) "EXPECTED restored Group state: $key"
    }
    if ($AfterGroupMigration) {
        $rpcNames = @(
            'sideworld_group_create_v1','sideworld_group_join_v1',
            'sideworld_group_get_v1','sideworld_group_receipt_get_v1',
            'sideworld_group_apply_v1','sideworld_group_leave_v1'
        )
        foreach ($rpc in $rpcNames) {
            $rows = @(Has $restoreGroup $rpc)
            Check ($rows.Count -eq 1 -and $rows[0].present -eq 't') "Group RPC installed: $rpc"
        }
        foreach ($table in $tables) {
            $rows = @(Has $restoredRls $table)
            Check ($rows.Count -eq 1 -and $rows[0].rls_enabled -eq 't' -and
                $rows[0].anon_select -eq 'f' -and $rows[0].authenticated_select -eq 'f' -and
                $rows[0].service_select -eq 'f' -and [string]$rows[0].policy_count -eq '0') "Group direct-table access denied: $table"
        }
    } else {
        Check ((Canonical $sourceGroup) -ceq (Canonical $restoreGroup)) 'GROUP pre-migration object parity'
    }
} catch {
    # Never echo any filenames, row IDs, hashes, private data or full exception.
    Write-Host 'FAIL isolated restore canary evaluation (missing/invalid inputs)'
    exit 2
}
Write-Host 'Note: metadata parity supports, but does not replace, full isolated restore/recovery verification.'
if ($failures -gt 0) { Write-Host "PARITY NO-GO ($failures mismatches)"; exit 1 }
Write-Host 'PARITY METADATA PASS — still requires complete restore, security and concurrency tests.'
