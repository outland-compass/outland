# SIDEWORLD V3.2 production PREPARE ONLY. READ ONLY. No Execute mode exists here.
param(
    [string]$Repo = 'C:\deploy\outland-sideworld-v3-2-production',
    [Parameter(Mandatory)][string]$SourceSha,
    [Parameter(Mandatory)][string]$AnonKeyFile,
    [string]$FeatureSha = 'e8634721dc46cb6735e320a441ec45eb8bc5167c',
    [string]$EvidenceRoot = (Join-Path $HOME 'outland-backups')
)
$ErrorActionPreference = 'Continue'
$Here = $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $Here '..\..\..')).Path
. (Join-Path $RepoRoot 'scripts\staging\sideworld-v3-2\cli-output.lib.ps1')

$ProductionRef = 'huzcukdovavejejwohey'
$StagingRef = 'clgpxvyflycudzhdzjlv'
$ProductionUrl = "postgresql://postgres.$ProductionRef@aws-1-eu-west-1.pooler.supabase.com:5432/postgres?sslmode=require"
$ProductionApi = "https://$ProductionRef.supabase.co"
$V32 = [ordered]@{
    '202610060001_sideworld_universe_foundation.sql' = '108ced4d481f90990650d9f041bb74b0eac95cff'
    '202610060002_sideworld_geo_foundation.sql' = 'b06b95ca8d4dc6fe461a4bd73dbfbb3e314b09a9'
    '202610060003_sideworld_universe_mapping.sql' = '770723c9c973800deb2db18ee2fc959eb137dbf7'
    '202610060004_sideworld_canon_foundation.sql' = '9830e8496f3189c8356920160d23a9259fd7c56c'
}
$Expected = @($V32.Keys)
$cli = @('--yes','supabase@2.119.0')

$Ev = Join-Path $EvidenceRoot ("production-v3-2-prepare-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $Ev | Out-Null
$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
icacls $Ev /inheritance:r /grant:r "*${sid}:(OI)(CI)F" | Out-Null
Start-Transcript -Path (Join-Path $Ev 'transcript.txt') | Out-Null
$Summary = [ordered]@{ mode='Prepare'; target=$ProductionRef; source_sha=$SourceSha; started=(Get-Date).ToString('o') }
$scriptExitCode = 0
$state = 'NOT STARTED (no production changes)'

function Gate($ok,$msg){ if(-not $ok){ throw "GATE FAILED: $msg" }; Write-Host "GATE OK: $msg" -ForegroundColor Green }
function Txt { process { "$_" } }

function Open-ProductionSession {
    $DbUser = "postgres.$ProductionRef"
    $sec = Read-Host "Password for $DbUser (OUTLAND production)" -AsSecureString
    if ($sec.Length -eq 0) { throw 'Empty password - aborting.' }
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    $global:ProductionDbUrl = $ProductionUrl
    $global:ProductionConn = @{ Host='aws-1-eu-west-1.pooler.supabase.com'; Port=5432; User=$DbUser; SslMode='require' }
}
function Close-ProductionSession {
    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
    Remove-Variable -Scope Global -Name ProductionDbUrl, ProductionConn -ErrorAction SilentlyContinue
}
function Invoke-ProdPsql([string]$File) {
    $c = $global:ProductionConn
    $dir = Split-Path (Resolve-Path $File) -Parent
    $name = Split-Path $File -Leaf
    $out = @(docker run --rm -i -e PGPASSWORD -e "PGSSLMODE=$($c.SslMode)" -v "${dir}:/s:ro" postgres:17 psql -X -v ON_ERROR_STOP=1 -h $c.Host -p $c.Port -U $c.User -d postgres -f "/s/$name" 2>&1 | Txt)
    if ($LASTEXITCODE -ne 0) { $out | ForEach-Object { Write-Host $_ }; throw "psql failed: $name" }
    return ,$out
}
function Export-Fingerprints($OutDir) {
    New-Item -ItemType Directory -Force $OutDir | Out-Null
    $c = $global:ProductionConn
    $fpDir = Join-Path $RepoRoot 'scripts\staging\sideworld-v3-2'
    docker run --rm -e PGPASSWORD -e "PGSSLMODE=$($c.SslMode)" -v "$((Resolve-Path $OutDir).Path):/out" -v "${fpDir}:/fp:ro" postgres:17 psql -X -q -h $c.Host -p $c.Port -U $c.User -d postgres -f /fp/fingerprints.sql
    if ($LASTEXITCODE -ne 0) { throw 'Fingerprint export failed' }
}
function Compare-Fingerprints($a,$b) {
    $files = @(Get-ChildItem $b -Filter 'fp-*.csv' | ForEach-Object Name | Sort-Object)
    Gate ($files.Count -eq 9) '9 production fingerprint files in baseline'
    foreach($f in $files){
        $other = Join-Path $a $f
        Gate ((Test-Path $other) -and ((Get-FileHash (Join-Path $b $f)).Hash -eq (Get-FileHash $other).Hash)) "live production unchanged since backup: $f identical"
    }
}
function Test-ApiExposure {
    $cfg = Get-Content $AnonKeyFile -Raw
    $url = ([regex]::Match($cfg, "supabaseUrl: '([^']+)'")).Groups[1].Value
    if ($url -ne $ProductionApi) { throw "API probe key file targets $url, not production" }
    $key = ([regex]::Match($cfg, "supabasePublishableKey: '([^']+)'")).Groups[1].Value
    Add-Type -AssemblyName System.Net.Http
    $http = New-Object System.Net.Http.HttpClient
    $http.Timeout = [TimeSpan]::FromSeconds(20)
    $results = @{}
    try {
        foreach($p in 'universe','geo','canon'){
            $req = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Get, "$ProductionApi/rest/v1/worlds?select=id&limit=0")
            $req.Headers.Add('apikey',$key)
            $req.Headers.Add('Accept-Profile',$p)
            $resp = $http.SendAsync($req).GetAwaiter().GetResult()
            $body = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            $results[$p] = if($resp.IsSuccessStatusCode){"EXPOSED"}else{"HTTP $([int]$resp.StatusCode) $body"}
        }
    } finally { $http.Dispose(); $key=$null }
    return $results
}

try {
    Set-Location $Repo
    Gate ((git rev-parse HEAD) -eq $SourceSha) "HEAD is approved commit $SourceSha"
    Gate (-not (Test-Path supabase\.temp\project-ref)) 'checkout is unlinked'
    Gate ([string]::IsNullOrEmpty((git status --porcelain) -join '')) 'checkout is clean'
    Gate ((Get-ChildItem supabase\migrations\*.sql).Count -eq 23) '23 migration files present'
    foreach($f in $V32.Keys){ Gate ((git rev-parse "HEAD:supabase/migrations/$f") -eq $V32[$f]) "$f has pinned blob" }
    git merge-base --is-ancestor $FeatureSha HEAD
    Gate ($LASTEXITCODE -eq 0) 'approved feature commit is contained in HEAD'
    $runs = @(gh run list --commit $FeatureSha --workflow 'Database CI' --json conclusion 2>$null | ConvertFrom-Json)
    Gate (@($runs | Where-Object { $_.conclusion -eq 'success' }).Count -ge 1) 'Database CI succeeded on feature commit'

    Open-ProductionSession
    Gate ($ProductionDbUrl -eq $ProductionUrl) 'URL is exactly production pooler URL'
    Gate ($ProductionDbUrl -notmatch $StagingRef) 'URL does not reference staging'

    $before = @(Get-ChildItem $EvidenceRoot -Directory -Filter 'production-*' | ForEach-Object FullName)
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'scripts\production\backup-production.ps1') -OutRoot $EvidenceRoot -FingerprintSql (Join-Path $RepoRoot 'scripts\staging\sideworld-v3-2\fingerprints.sql')
    Gate ($LASTEXITCODE -eq 0) 'production backup completed'
    $new = @(Get-ChildItem $EvidenceRoot -Directory -Filter 'production-*' | Where-Object { $before -notcontains $_.FullName })
    Gate ($new.Count -eq 1) 'exactly one new production backup folder'
    $bk = $new[0].FullName

    $vout = powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'scripts\production\verify-production-backup.ps1') -BackupDir $bk 2>&1 | Txt
    $vout | Out-File -Encoding utf8 (Join-Path $Ev 'backup-verification.txt')
    Gate (($LASTEXITCODE -eq 0) -and ($vout -match 'VERIFY: ALL CHECKS PASSED')) 'production backup verification passed'
    $Summary.backup_dir = $bk
    $Summary.backup_full_dump_sha256 = (Get-FileHash -Algorithm SHA256 (Join-Path $bk 'production-full.dump')).Hash.ToLower()

    $o = Invoke-ProdPsql (Join-Path $Here 'preflight-production.sql')
    $o | Out-File -Encoding utf8 (Join-Path $Ev 'preflight.txt')
    Gate ($o -match 'PRODUCTION V3.2 TARGET VERIFIED') 'production baseline verified'

    Export-Fingerprints (Join-Path $Ev 'fingerprints-before')
    Compare-Fingerprints (Join-Path $Ev 'fingerprints-before') $bk

    $api = Test-ApiExposure
    $api | ConvertTo-Json | Out-File -Encoding utf8 (Join-Path $Ev 'api-exposure-before.json')
    foreach($p in $api.Keys){ Gate (($api[$p] -match '^HTTP 406 ') -and ($api[$p] -match 'PGRST106')) "API rejects $p as an unexposed schema (HTTP 406 / PGRST106)" }

    $o = npx @cli migration list --db-url $ProductionDbUrl 2>&1 | Txt
    $o | Out-File -Encoding utf8 (Join-Path $Ev 'migration-list-before.txt')
    Gate ($LASTEXITCODE -eq 0) 'migration list succeeded'

    $o = npx @cli db push --db-url $ProductionDbUrl --dry-run 2>&1 | Txt
    $o | Out-File -Encoding utf8 (Join-Path $Ev 'dry-run.txt')
    Gate ($LASTEXITCODE -eq 0) 'production dry run succeeded'
    $listed = Get-PushListing $o
    Write-Host ('Dry run lists: ' + ($listed -join ', '))
    Gate (($listed -join '|') -eq ($Expected -join '|')) 'dry run lists exactly V3.2 0001..0004 in order'

    $state = 'PREPARED - production read-only checks passed, no production changes'
    $Summary.result = 'PREPARED'
} catch {
    $scriptExitCode = 1
    $Summary.result = 'STOPPED'
    $Summary.stop_reason = $_.Exception.Message
    Write-Host "STOPPED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Production state: $state. No write path exists in this script." -ForegroundColor Red
} finally {
    Close-ProductionSession
    $Summary.state = $state
    $Summary.finished = (Get-Date).ToString('o')
    $Summary.evidence_dir = $Ev
    $Summary | ConvertTo-Json | Out-File -Encoding utf8 (Join-Path $Ev 'summary.json')
    Write-Host "Evidence: $Ev"
    Stop-Transcript | Out-Null
    Get-ChildItem $Ev -Recurse -File | Where-Object Name -ne 'ARCHIVE-SHA256SUMS.txt' | Get-FileHash -Algorithm SHA256 | ForEach-Object { "{0}  {1}" -f $_.Hash.ToLower(), $_.Path.Substring($Ev.Length + 1) } | Set-Content -Encoding ascii (Join-Path $Ev 'ARCHIVE-SHA256SUMS.txt')
}
if ($scriptExitCode -ne 0) { exit $scriptExitCode }