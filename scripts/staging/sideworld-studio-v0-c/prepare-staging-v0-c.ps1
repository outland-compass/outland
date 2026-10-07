# SIDEWORLD Studio V0-C STAGING PREPARE ONLY.
# READ-ONLY operator script. It never applies migrations or repairs migration history.
param(
  [Parameter(Mandatory)][string]$SourceSha,
  [string]$Repo = 'C:\deploy\outland-sideworld-studio-v0-c',
  [string]$EvidenceRoot = (Join-Path $HOME 'outland-backups')
)

$ErrorActionPreference='Stop'
$Here=$PSScriptRoot
$StagingRef='clgpxvyflycudzhdzjlv'
$ProductionRef='huzcukdovavejejwohey'
$StagingUrl="postgresql://postgres.$StagingRef@aws-1-eu-west-1.pooler.supabase.com:5432/postgres?sslmode=require"
$Migration='202610070001_sideworld_studio_read_boundary.sql'
$MigrationBlob='f3c669ad7028355480b1293494b2b4904de991c4'

if ($StagingUrl -match $ProductionRef) { throw 'Refusing: production reference detected.' }

$Ev=Join-Path $EvidenceRoot ("staging-studio-v0-c-prepare-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $Ev | Out-Null
Start-Transcript -Path (Join-Path $Ev 'transcript.txt') | Out-Null

function Gate($ok,$msg){ if(-not $ok){ throw "GATE FAILED: $msg" }; Write-Host "GATE OK: $msg" -ForegroundColor Green }
function Step($s){ Write-Host ""; Write-Host "===== $s =====" -ForegroundColor Cyan }

try {
  Set-Location $Repo
  Step '1 pinned checkout'
  Gate ((git rev-parse HEAD) -eq $SourceSha) "HEAD is approved source $SourceSha"
  Gate ([string]::IsNullOrEmpty((git status --porcelain) -join '')) 'checkout is clean'
  Gate ((git rev-parse "HEAD:supabase/migrations/$Migration") -eq $MigrationBlob) "$Migration blob pinned"

  Step '2 staging session'
  . (Join-Path $Here '..\staging-session.ps1')
  Gate ($StagingDbUrl -eq $StagingUrl) 'target is exact staging project'
  Gate ($StagingDbUrl -notmatch $ProductionRef) 'target is not production'

  Step '3 fresh verified staging backup'
  $before=@(Get-ChildItem $EvidenceRoot -Directory -Filter 'staging-2*' | ForEach-Object FullName)
  powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Here '..\backup-staging.ps1') -OutRoot $EvidenceRoot
  Gate ($LASTEXITCODE -eq 0) 'backup completed'
  $new=@(Get-ChildItem $EvidenceRoot -Directory -Filter 'staging-2*' | Where-Object { $before -notcontains $_.FullName })
  Gate ($new.Count -eq 1) 'exactly one new backup folder'
  $bk=$new[0].FullName
  $verify=powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Here '..\verify-backup.ps1') -BackupDir $bk 2>&1
  $verify | Out-File -Encoding utf8 (Join-Path $Ev 'backup-verification.txt')
  Gate (($LASTEXITCODE -eq 0) -and (($verify -join "`n") -match 'VERIFY: ALL CHECKS PASSED')) 'backup verification passed'

  Step '4 read-only SQL preflight'
  $c=$global:StagingConn
  docker run --rm -e PGPASSWORD -e "PGSSLMODE=$($c.SslMode)" -v "${Here}:/s:ro" postgres:17 `
    psql -X -v ON_ERROR_STOP=1 -h $c.Host -p $c.Port -U $c.User -d postgres -f /s/preflight.sql `
    | Tee-Object -FilePath (Join-Path $Ev 'preflight.txt')
  Gate ($LASTEXITCODE -eq 0) 'preflight passed'

  Step '5 migration list'
  $list=npx --yes supabase@2.119.0 migration list --db-url $StagingDbUrl 2>&1
  $list | Out-File -Encoding utf8 (Join-Path $Ev 'migration-list.txt')
  Gate ($LASTEXITCODE -eq 0) 'migration list succeeded'

  Step '6 exact dry run'
  $dry=npx --yes supabase@2.119.0 db push --db-url $StagingDbUrl --dry-run 2>&1
  $dry | Out-File -Encoding utf8 (Join-Path $Ev 'dry-run.txt')
  Gate ($LASTEXITCODE -eq 0) 'dry run succeeded'
  $joined=$dry -join "`n"
  Gate ($joined -match [regex]::Escape($Migration)) 'dry run includes Studio V0-C migration'
  $applies=@($dry | Select-String -Pattern 'Applying migration')
  Gate ($applies.Count -eq 1) 'dry run contains exactly one applying-migration line'
  Gate ($applies[0].Line -match [regex]::Escape($Migration)) 'the only pending migration is Studio V0-C'

  Step '7 Data API exposure guard'
  $cfg=Get-Content (Join-Path $Repo 'supabase\config.toml') -Raw
  Gate ($cfg -match 'schemas = \["public", "graphql_public", "shared", "land"\]') 'Data API exposure list unchanged'
  Gate ($cfg -notmatch 'schemas = .*"(universe|geo|canon)"') 'private SIDEWORLD schemas absent from Data API list'

  Write-Host ''
  Write-Host '============================================================' -ForegroundColor Green
  Write-Host 'STUDIO V0-C STAGING PREPARE = PREPARED' -ForegroundColor Green
  Write-Host 'READ-ONLY GATES PASSED' -ForegroundColor Green
  Write-Host 'NO STAGING EXECUTE PERFORMED' -ForegroundColor Green
  Write-Host "Evidence: $Ev" -ForegroundColor Green
  Write-Host '============================================================' -ForegroundColor Green
}
finally {
  if (Get-Command Close-StagingSession -ErrorAction SilentlyContinue) { Close-StagingSession }
  Stop-Transcript | Out-Null
}
