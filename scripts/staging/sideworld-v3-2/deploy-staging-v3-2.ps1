# OUTLAND STAGING ONLY: SIDEWORLD Schema V3.2 rehearsal (202610060001..202610060004), operator script.
#   -Mode Prepare : READ ONLY. Pinned-checkout gate, fresh verified backup with fingerprints, staging target gate,
#                   fingerprint freshness, Compass API exposure probe, migration list, exact dry run. Never writes.
#   -Mode Execute : all Prepare gates (own fresh backup), typed confirmation, all four wrapperless migrations in ONE
#                   outer transaction with statement_timeout 60s / lock_timeout 5s, committed-state verification,
#                   then ledger rows via `migration repair --status applied`, then post-apply validation.
#                   Requires separate written founder approval naming -SourceSha.
#   -Mode CompleteLedger : recovery only after the schema transaction committed but one or more V3.2 ledger repairs
#                   failed. Verifies the committed empty/private schema before repairing ONLY missing V3.2 versions.
# The target is hard-coded to staging clgpxvyflycudzhdzjlv; any production reference aborts. One password prompt.
# Stops at the first failed gate. No automatic rollback (see docs/architecture/SIDEWORLD_V3_2_STAGING_REHEARSAL_PLAN.md).
#   powershell -ExecutionPolicy Bypass -File <checkout>\scripts\staging\sideworld-v3-2\deploy-staging-v3-2.ps1 -Mode Prepare
param(
    [Parameter(Mandatory)][ValidateSet('Prepare', 'Execute', 'CompleteLedger')][string]$Mode,
    [string]$Repo         = 'C:\deploy\outland-sideworld-v3-2',
    [Parameter(Mandatory)][string]$SourceSha,
    [string]$FeatureSha   = 'e8634721dc46cb6735e320a441ec45eb8bc5167c',
    [string]$AnonKeyFile  = 'C:\deploy\outland-legacy-cleanup\apps\compass\web\src\environments\environment.local.ts',
    [switch]$IncludeWritePathSuites,
    [string]$EvidenceRoot = (Join-Path $HOME 'outland-backups')
)
$ErrorActionPreference = 'Continue'   # native CLIs write progress to stderr; every gate is checked explicitly
$Here = $PSScriptRoot
. (Join-Path $Here 'cli-output.lib.ps1')
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$StagingRef    = 'clgpxvyflycudzhdzjlv'
$ProductionRef = 'huzcukdovavejejwohey'
$StagingUrl    = "postgresql://postgres.$StagingRef@aws-1-eu-west-1.pooler.supabase.com:5432/postgres?sslmode=require"
$StagingApi    = "https://$StagingRef.supabase.co"
$ExpectedApiSchemas = 'public, graphql_public, shared, land'
# Pinned V3.2 wrapperless migrations: file -> git blob id at main 2683c548 (merge of PR #35).
$V32 = [ordered]@{
    '202610060001_sideworld_universe_foundation.sql' = '108ced4d481f90990650d9f041bb74b0eac95cff'
    '202610060002_sideworld_geo_foundation.sql'      = 'b06b95ca8d4dc6fe461a4bd73dbfbb3e314b09a9'
    '202610060003_sideworld_universe_mapping.sql'    = '770723c9c973800deb2db18ee2fc959eb137dbf7'
    '202610060004_sideworld_canon_foundation.sql'    = '9830e8496f3189c8356920160d23a9259fd7c56c'
}
$Expected = @($V32.Keys)
if ($StagingUrl -match $ProductionRef -or $StagingApi -match $ProductionRef) { throw 'Refusing: production reference in the target.' }
$cli = @('--yes', 'supabase@2.119.0')

$Ev = Join-Path $EvidenceRoot ("staging-v3-2-{0}-{1}" -f $Mode.ToLower(), (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $Ev | Out-Null
$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
icacls $Ev /inheritance:r /grant:r "*${sid}:(OI)(CI)F" | Out-Null
Start-Transcript -Path (Join-Path $Ev 'transcript.txt') | Out-Null
$state = 'NOT STARTED (no staging changes)'
function Gate($ok, $msg) { if (-not $ok) { throw "GATE FAILED: $msg" }; Write-Host "GATE OK: $msg" -ForegroundColor Green }
function Txt { process { "$_" } }
function Step($s) { Write-Host "`n===== $s =====" -ForegroundColor Cyan }

function Invoke-V32Psql {
    # psql 17 in Docker against the staging session. Prints psql output to the transcript BEFORE throwing on failure.
    param([string[]]$Files, [string[]]$Pre = @(), [string[]]$Vars = @(), [string]$MountDir = $Here, [string]$MigrationsDir = '', [switch]$Single)
    $c = $global:StagingConn
    $args2 = @('run','--rm','-i','-e','PGPASSWORD','-e',"PGSSLMODE=$($c.SslMode)",'-v',"$((Resolve-Path $MountDir).Path):/s:ro")
    if ($MigrationsDir) { $args2 += @('-v', "$((Resolve-Path $MigrationsDir).Path):/m:ro") }
    $args2 += @('postgres:17','psql','-X','-v','ON_ERROR_STOP=1','-h',$c.Host,'-p',$c.Port,'-U',$c.User,'-d','postgres')
    if ($Single) { $args2 += '-1' }
    foreach ($v in $Vars) { $args2 += @('-v', $v) }
    foreach ($p in $Pre) { $args2 += @('-c', $p) }
    foreach ($f in $Files) { $args2 += @('-f', $f) }
    $ErrorActionPreference = 'Continue'
    $out = @(docker @args2 2>&1 | Txt)
    if ($LASTEXITCODE -ne 0) { $out | ForEach-Object { Write-Host $_ }; throw "psql failed: $($Files -join ', ') - STOP" }
    return ,$out
}
function Export-V32Fingerprints($OutDir) {
    New-Item -ItemType Directory -Force $OutDir | Out-Null
    $c = $global:StagingConn
    $ErrorActionPreference = 'Continue'
    $out = @(docker run --rm -e PGPASSWORD -e "PGSSLMODE=$($c.SslMode)" -v "$((Resolve-Path $OutDir).Path):/out" -v "${Here}:/s:ro" postgres:17 `
        psql -X -q -h $c.Host -p $c.Port -U $c.User -d postgres -f /s/fingerprints.sql 2>&1 | Txt)
    if ($LASTEXITCODE -ne 0) { $out | ForEach-Object { Write-Host $_ }; throw 'Fingerprint export failed - STOP.' }
}
function Compare-V32Fingerprints($a, $b, $what) {
    $files = @(Get-ChildItem $b -Filter 'fp-*.csv' | ForEach-Object Name | Sort-Object)
    Gate ($files.Count -eq 9) "${what}: 9 fingerprint files in the baseline"
    foreach ($f in $files) {
        $other = Join-Path $a $f
        Gate ((Test-Path $other) -and ((Get-FileHash (Join-Path $b $f)).Hash -eq (Get-FileHash $other).Hash)) "${what}: $f identical"
    }
}
function Test-ApiExposure {
    # Read-only PostgREST probe: an unexposed profile is rejected with the list of exposed schemas.
    $cfg = Get-Content $AnonKeyFile -Raw
    $url = ([regex]::Match($cfg, "supabaseUrl: '([^']+)'")).Groups[1].Value
    if ($url -ne $StagingApi) { throw "API probe key file targets $url, not staging - STOP" }
    $key = ([regex]::Match($cfg, "supabasePublishableKey: '([^']+)'")).Groups[1].Value
    # HttpClient returns the body of a 406 without throwing (Invoke-WebRequest in PS 5.1 does not reliably).
    Add-Type -AssemblyName System.Net.Http
    $http = New-Object System.Net.Http.HttpClient
    $http.Timeout = [TimeSpan]::FromSeconds(20)
    $results = @{}
    try {
        foreach ($p in 'universe', 'geo', 'canon') {
            $req = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Get, "$StagingApi/rest/v1/worlds?select=id&limit=0")
            $req.Headers.Add('apikey', $key); $req.Headers.Add('Accept-Profile', $p)
            $resp = $http.SendAsync($req).GetAwaiter().GetResult()
            $body = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            $results[$p] = if ($resp.IsSuccessStatusCode) { "EXPOSED (HTTP $([int]$resp.StatusCode))" } else { "HTTP $([int]$resp.StatusCode) $body" }
        }
    } finally { $http.Dispose(); $key = $null }
    return $results
}

$Summary = [ordered]@{ mode = $Mode; target = $StagingRef; source_sha = $SourceSha; started = (Get-Date).ToString('o') }
$scriptExitCode = 0
try {
    Set-Location $Repo
    Step '1 pinned deployment checkout'
    Gate ((git rev-parse HEAD) -eq $SourceSha) "HEAD is the approved commit $SourceSha"
    Gate (-not (Test-Path supabase\.temp\project-ref)) 'checkout is not linked to any project'
    Gate ([string]::IsNullOrEmpty((git status --porcelain) -join '')) 'checkout is clean'
    Gate ((Get-ChildItem supabase\migrations\*.sql).Count -eq 23) '23 migration files present'
    foreach ($f in $V32.Keys) { Gate ((git rev-parse "HEAD:supabase/migrations/$f") -eq $V32[$f]) "$f blob is the pinned $($V32[$f])" }
    git merge-base --is-ancestor $FeatureSha HEAD
    Gate ($LASTEXITCODE -eq 0) "approved feature commit $FeatureSha is contained in HEAD"
    $runs = @(gh run list --commit $FeatureSha --workflow 'Database CI' --json conclusion 2>$null | ConvertFrom-Json)
    Gate (@($runs | Where-Object { $_.conclusion -eq 'success' }).Count -ge 1) 'Database CI succeeded on the feature commit'

    Step '2 staging session (one masked prompt)'
    . (Join-Path $Here '..\staging-session.ps1')
    Gate ($StagingDbUrl -eq $StagingUrl) "URL is exactly the staging pooler URL for $StagingRef (no password inside)"
    Gate ($StagingDbUrl -notmatch $ProductionRef) 'URL does not reference production'

    if ($Mode -eq 'CompleteLedger') {
        Step '3 committed-state recovery gate (READ ONLY)'
        $o = Invoke-V32Psql -Files '/s/committed-state-check.sql'
        $o | Out-File -Encoding utf8 (Join-Path $Ev 'committed-state-check.txt')
        Gate ($o -match 'V3.2 COMMITTED STATE VERIFIED') 'committed V3.2 schema exactly matches the recovery guard'
        $m = [regex]::Match(($o -join "`n"), "MISSING_LEDGER_VERSIONS=([^`r`n]*)")
        Gate $m.Success 'committed-state check reports missing ledger versions'
        $missing = @($m.Groups[1].Value.Trim() -split '\s+' | Where-Object { $_ })
        $allowed = @('202610060001','202610060002','202610060003','202610060004')
        Gate (@($missing | Where-Object { $_ -notin $allowed }).Count -eq 0) 'only V3.2 versions may be missing from the ledger'
        if ($missing.Count -eq 0) {
            Write-Host 'Ledger already complete; no repair needed.' -ForegroundColor Yellow
        } else {
            Step '4 complete ONLY missing V3.2 ledger rows (separately approved recovery)'
            Write-Host ('Missing versions: ' + ($missing -join ', ')) -ForegroundColor Yellow
            $confirm = Read-Host "Type COMPLETE-V32-LEDGER-STAGING-$StagingRef to repair ONLY these missing versions (anything else stops)"
            Gate ($confirm -ceq "COMPLETE-V32-LEDGER-STAGING-$StagingRef") 'operator confirmed ledger-only recovery'
            foreach ($v in $allowed) {
                if ($missing -contains $v) {
                    $state = "SCHEMA COMMITTED; REPAIRING LEDGER $v"
                    $r = npx @cli migration repair --status applied $v --db-url $StagingDbUrl 2>&1 | Txt
                    $r | Out-File -Encoding utf8 (Join-Path $Ev "ledger-recovery-$v.txt")
                    Gate (($LASTEXITCODE -eq 0) -and ($r -match "Repaired migration history: \[$v\] => applied")) "ledger records $v"
                    # Re-verify the exact committed schema and ledger subset after every repair.
                    $check = Invoke-V32Psql -Files '/s/committed-state-check.sql'
                    $check | Out-File -Encoding utf8 (Join-Path $Ev "committed-state-after-$v.txt")
                    Gate ($check -match 'V3.2 COMMITTED STATE VERIFIED') "schema still matches after ledger repair $v"
                }
            }
        }
        Step '5 final post-validation after ledger recovery'
        $o = Invoke-V32Psql -Files '/s/post-validate.sql'
        $o | Out-File -Encoding utf8 (Join-Path $Ev 'post-validate-ledger-recovery.txt')
        Gate ($o -match 'STAGING V3.2 POST-APPLY VALIDATION PASSED') 'ledger recovery complete and post-validation passed'
        $state = 'V3.2 SCHEMA VERIFIED; LEDGER COMPLETE (23 versions)'
        $Summary.result = 'SUCCESS'
        return
    }

    Step '3 fresh backup with fingerprints + verification'
    $before = @(Get-ChildItem $EvidenceRoot -Directory -Filter 'staging-2*' | ForEach-Object FullName)
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Here '..\backup-staging.ps1') -OutRoot $EvidenceRoot -FingerprintSql (Join-Path $Here 'fingerprints.sql')
    Gate ($LASTEXITCODE -eq 0) 'backup-staging.ps1 completed (dumps, inventory, fingerprints)'
    $new = @(Get-ChildItem $EvidenceRoot -Directory -Filter 'staging-2*' | Where-Object { $before -notcontains $_.FullName })
    Gate ($new.Count -eq 1) 'exactly one new backup folder'
    $bk = $new[0].FullName
    $vout = powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Here '..\verify-backup.ps1') -BackupDir $bk 2>&1 | Txt
    $vout | Out-File -Encoding utf8 (Join-Path $Ev 'backup-verification.txt'); $vout | Select-Object -Last 3
    Gate (($LASTEXITCODE -eq 0) -and ($vout -match 'VERIFY: ALL CHECKS PASSED')) 'backup verification ALL CHECKS PASSED'
    $Summary.backup_dir = $bk
    $Summary.backup_full_dump_sha256 = (Get-FileHash -Algorithm SHA256 (Join-Path $bk 'staging-full.dump')).Hash.ToLower()

    Step '4 read-only target gate, freshness, API exposure, ledger'
    $o = Invoke-V32Psql -Files '/s/preflight.sql'; $o | Out-File -Encoding utf8 (Join-Path $Ev 'preflight.txt'); $o | Select-String 'VERIFIED'
    Gate ($o -match 'STAGING V3.2 TARGET VERIFIED') 'STAGING V3.2 TARGET VERIFIED (19 versions, cleanup complete, no V3.2 objects, timeouts effective)'
    Export-V32Fingerprints (Join-Path $Ev 'fingerprints-before')
    Compare-V32Fingerprints (Join-Path $Ev 'fingerprints-before') $bk 'live data unchanged since backup'
    $api = Test-ApiExposure; $api | ConvertTo-Json | Out-File -Encoding utf8 (Join-Path $Ev 'api-exposure-before.json')
    foreach ($p in $api.Keys) { Gate ($api[$p] -match [regex]::Escape("Only the following schemas are exposed: $ExpectedApiSchemas")) "API does not expose $p (exposed: $ExpectedApiSchemas)" }
    $o = npx @cli migration list --db-url $StagingDbUrl 2>&1 | Txt; $o | Out-File -Encoding utf8 (Join-Path $Ev 'migration-list-before.txt')
    Gate ($LASTEXITCODE -eq 0) 'migration list succeeded'

    Step '5 dry run (exactly the four V3.2 migrations, nothing else)'
    $o = npx @cli db push --db-url $StagingDbUrl --dry-run 2>&1 | Txt; $o | Out-File -Encoding utf8 (Join-Path $Ev 'dry-run.txt')
    Gate ($LASTEXITCODE -eq 0) 'dry run succeeded'
    $listed = Get-PushListing $o
    Write-Host ('Dry run lists: ' + ($listed -join ', '))
    Gate (($listed -join '|') -eq ($Expected -join '|')) 'dry run lists exactly 202610060001..202610060004 in order'

    if ($Mode -eq 'Prepare') {
        $state = 'PREPARED - read-only checks passed, no staging changes'
        $Summary.result = 'PREPARED'
    } else {
        Step '6 apply to STAGING (separately approved)'
        $confirm = Read-Host "Type APPLY-V32-STAGING-$StagingRef to apply exactly the four V3.2 migrations to STAGING (anything else stops)"
        Gate ($confirm -ceq "APPLY-V32-STAGING-$StagingRef") 'operator confirmed the staging apply'
        Gate (((git rev-parse HEAD) -eq $SourceSha) -and [string]::IsNullOrEmpty((git status --porcelain) -join '')) 'checkout still clean at the approved commit'
        foreach ($f in $V32.Keys) { Gate ((git hash-object "supabase\migrations\$f") -eq $V32[$f]) "working file $f still has the pinned blob" }
        $wrapped = @($V32.Keys | Where-Object { (Get-Content "supabase\migrations\$_" -Raw) -match '(?im)^\s*begin\s*;' -or (Get-Content "supabase\migrations\$_" -Raw) -match '(?im)^\s*commit\s*;' })
        Gate ($wrapped.Count -eq 0) 'all four pinned migrations are wrapperless; atomic outer transaction is the only apply path'
        $mig = Join-Path $Repo 'supabase\migrations'
        $state = 'APPLYING V3.2 ATOMICALLY (one transaction: commits fully or not at all)'
        $o = Invoke-V32Psql -Files @('/s/apply-atomic.sql') -MigrationsDir $mig -Single
        $o | Out-File -Encoding utf8 (Join-Path $Ev 'apply-atomic.txt')
        Gate ($o -match 'V3.2 ATOMIC APPLY SUCCEEDED') 'all four migrations committed in one transaction'

        # Critical recovery gate: schema is committed, but ledger is still the 19-version baseline.
        # Verify the exact expected empty/private V3.2 state BEFORE touching migration history.
        $state = 'V3.2 SCHEMA COMMITTED, LEDGER NOT YET RECORDED - validating committed state'
        $o = Invoke-V32Psql -Files '/s/committed-state-check.sql'
        $o | Out-File -Encoding utf8 (Join-Path $Ev 'committed-state-before-ledger.txt')
        Gate ($o -match 'V3.2 COMMITTED STATE VERIFIED') 'committed V3.2 schema passes the ledger-recovery guard'

        # Record one version at a time so any CLI failure leaves an explicit, recoverable subset.
        # CompleteLedger mode can safely finish ONLY the missing rows after re-verifying the committed schema.
        foreach ($v in @('202610060001','202610060002','202610060003','202610060004')) {
            $state = "V3.2 SCHEMA COMMITTED; LEDGER PARTIAL - next repair $v (never db push)"
            $r = npx @cli migration repair --status applied $v --db-url $StagingDbUrl 2>&1 | Txt
            $r | Out-File -Encoding utf8 (Join-Path $Ev "ledger-$v.txt")
            Gate (($LASTEXITCODE -eq 0) -and ($r -match "Repaired migration history: \[$v\] => applied")) "ledger records $v"
        }
        $state = 'V3.2 APPLIED AND RECORDED (23 versions expected), post-apply validation pending'

        Step '7 post-apply validation'
        $o = Invoke-V32Psql -Files '/s/post-validate.sql'; $o | Out-File -Encoding utf8 (Join-Path $Ev 'post-validate.txt'); $o | Select-String 'PASSED'
        Gate ($o -match 'STAGING V3.2 POST-APPLY VALIDATION PASSED') 'STAGING V3.2 POST-APPLY VALIDATION PASSED'
        $tests = Join-Path $Repo 'supabase\tests'
        foreach ($t in 'verify-sideworld-bases', 'verify-sideworld-universe', 'verify-sideworld-geo', 'verify-sideworld-canon', 'verify-sideworld-boundaries') {
            $o = Invoke-V32Psql -Files "/s/$t.sql" -MountDir $tests -Pre @('set default_transaction_read_only = on'); $o | Out-File -Encoding utf8 (Join-Path $Ev "$t.txt")
            Gate $true "$t.sql passed (read-only session)"
        }
        $o = Invoke-V32Psql -Files '/s/verify-schema.sql' -MountDir $tests -Pre @('set outland.world_canon = legacy_compatible'); $o | Out-File -Encoding utf8 (Join-Path $Ev 'verify-schema.txt')
        Gate $true 'verify-schema.sql passed (legacy_compatible; temp function only, rolled back)'
        if ($IncludeWritePathSuites) {
            $o = Invoke-V32Psql -Files '/s/verify-workflow-security.sql' -MountDir $tests -Pre @('set outland.world_canon = legacy_compatible'); $o | Out-File -Encoding utf8 (Join-Path $Ev 'verify-workflow-security.txt')
            Gate $true 'verify-workflow-security.sql passed (write-path, rolled back; explicitly approved)'
            $o = Invoke-V32Psql -Files '/s/diagnose-compass-promotion.sql' -MountDir $tests; $o | Out-File -Encoding utf8 (Join-Path $Ev 'diagnose-compass-promotion.txt')
            Gate $true 'diagnose-compass-promotion.sql passed (write-path, rolled back; explicitly approved)'
        } else { Write-Host 'NOT RUN: verify-workflow-security.sql, diagnose-compass-promotion.sql (write-path; need -IncludeWritePathSuites and approval)' -ForegroundColor Yellow }
        Export-V32Fingerprints (Join-Path $Ev 'fingerprints-after')
        Compare-V32Fingerprints (Join-Path $Ev 'fingerprints-after') $bk 'preserved OUTLAND data unchanged by V3.2'
        $api = Test-ApiExposure; $api | ConvertTo-Json | Out-File -Encoding utf8 (Join-Path $Ev 'api-exposure-after.json')
        foreach ($p in $api.Keys) { Gate ($api[$p] -match [regex]::Escape("Only the following schemas are exposed: $ExpectedApiSchemas")) "API still does not expose $p" }
        $o = npx @cli migration list --db-url $StagingDbUrl 2>&1 | Txt; $o | Out-File -Encoding utf8 (Join-Path $Ev 'migration-list-after.txt')
        Gate ($LASTEXITCODE -eq 0) 'migration list succeeded'
        $o = npx @cli db push --db-url $StagingDbUrl --dry-run 2>&1 | Txt; $o | Out-File -Encoding utf8 (Join-Path $Ev 'dry-run-after.txt')
        Gate (($LASTEXITCODE -eq 0) -and ($o -match '(?i)database is up to date')) 'CLI sees staging as up to date'
        $state = 'V3.2 APPLIED AND VALIDATED ON STAGING (23 versions)'
        $Summary.result = 'SUCCESS'
    }
}
catch {
    $scriptExitCode = 1
    $Summary.result = 'STOPPED'
    $Summary.stop_reason = $_.Exception.Message
    Write-Host "`nSTOPPED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Staging state: $state. Do NOT retry or roll back ad hoc - follow the rehearsal plan after review." -ForegroundColor Red
}
finally {
    if (Get-Command Close-StagingSession -ErrorAction SilentlyContinue) { Close-StagingSession }
    $Summary.state = $state
    $Summary.finished = (Get-Date).ToString('o')
    $Summary.evidence_dir = $Ev
    $Summary | ConvertTo-Json | Out-File -Encoding utf8 (Join-Path $Ev 'summary.json')
    Write-Host "`nEvidence: $Ev"
    Stop-Transcript | Out-Null
    Get-ChildItem $Ev -Recurse -File | Where-Object Name -ne 'ARCHIVE-SHA256SUMS.txt' | Get-FileHash -Algorithm SHA256 |
        ForEach-Object { "{0}  {1}" -f $_.Hash.ToLower(), $_.Path.Substring($Ev.Length + 1) } |
        Set-Content -Encoding ascii (Join-Path $Ev 'ARCHIVE-SHA256SUMS.txt')
}
if ($scriptExitCode -ne 0) { exit $scriptExitCode }
