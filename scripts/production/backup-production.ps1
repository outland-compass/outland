# Read-only backup of OUTLAND production via Session Pooler.
param(
    [string]$Ref = 'huzcukdovavejejwohey',
    [string]$PoolerHost = 'aws-1-eu-west-1.pooler.supabase.com',
    [int]$Port = 5432,
    [string]$DbUser = '',
    [string]$SslMode = 'require',
    [string]$OutRoot = (Join-Path $HOME 'outland-backups'),
    [string]$FingerprintSql = ''
)
$ErrorActionPreference = 'Stop'
$StagingRef = 'clgpxvyflycudzhdzjlv'
if (-not $DbUser) { $DbUser = "postgres.$Ref" }
if ($Ref -ne 'huzcukdovavejejwohey') { throw "Refusing: unexpected production project ref: $Ref" }
if ("$Ref $DbUser" -match $StagingRef) { throw "Refusing: staging reference detected" }

$PgImage = 'postgres:17'
$SupabaseCli = 'supabase@2.119.0'
New-Item -ItemType Directory -Force -Path $OutRoot | Out-Null
$insideGit = $null
try { $insideGit = & git -C $OutRoot rev-parse --is-inside-work-tree 2>$null } catch { }
if ($insideGit -eq 'true') { throw "Refusing to write backups inside a Git work tree: $OutRoot" }
$Out = Join-Path $OutRoot ("production-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))

docker info --format '{{.ServerVersion}}' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Docker is not running.' }
New-Item -ItemType Directory -Path $Out | Out-Null
$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
icacls $Out /inheritance:r /grant:r "*${sid}:(OI)(CI)F" | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Failed to restrict backup folder ACL.' }

Write-Host "Target: $DbUser @ ${PoolerHost}:$Port (ref $Ref) - READ ONLY"
$ownPassword = -not $env:PGPASSWORD
$bstr = [IntPtr]::Zero
if ($ownPassword) {
    $sec = Read-Host 'Production database password' -AsSecureString
    if ($sec.Length -eq 0) { throw 'Empty password - aborting.' }
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
}
$inventoryOk = $false
try {
    if ($ownPassword) { $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    $dbUrl = "postgresql://${DbUser}@${PoolerHost}:${Port}/postgres?sslmode=$SslMode"
    Write-Host '[1/5] Supabase roles dump'
    npx --yes $SupabaseCli db dump --db-url $dbUrl -f "$Out\roles.sql" --role-only
    if ($LASTEXITCODE -ne 0) { throw 'roles dump failed' }
    Write-Host '[2/5] Supabase schema dump'
    npx --yes $SupabaseCli db dump --db-url $dbUrl -f "$Out\schema.sql"
    if ($LASTEXITCODE -ne 0) { throw 'schema dump failed' }
    Write-Host '[3/5] Supabase data dump'
    npx --yes $SupabaseCli db dump --db-url $dbUrl -f "$Out\data.sql" --use-copy --data-only
    if ($LASTEXITCODE -ne 0) { throw 'data dump failed' }
    $stagingDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'staging'
    $dockerArgs = @('run','--rm','-e','PGPASSWORD','-e',"PGSSLMODE=$SslMode",'-v',"${Out}:/out",'-v',"${stagingDir}:/scripts:ro",$PgImage)
    Write-Host '[4/5] Full pg_dump (custom format, incl. migration history)'
    docker @dockerArgs pg_dump -h $PoolerHost -p $Port -U $DbUser -d postgres -Fc -f /out/production-full.dump
    if ($LASTEXITCODE -ne 0) {
        if (Test-Path "$Out\production-full.dump") { Rename-Item "$Out\production-full.dump" 'production-full.dump.FAILED' }
        throw 'Full pg_dump failed'
    }
    Write-Host '[5/5] Read-only inventory'
    docker @dockerArgs psql -X -h $PoolerHost -p $Port -U $DbUser -d postgres -f /scripts/inventory.sql
    if ($LASTEXITCODE -eq 0) { $inventoryOk = $true } else { throw 'Inventory failed' }
    if ($FingerprintSql) {
        Write-Host '[+] Read-only fingerprints'
        $fpDir = Split-Path (Resolve-Path $FingerprintSql) -Parent
        $fpName = Split-Path $FingerprintSql -Leaf
        docker run --rm -e PGPASSWORD -e "PGSSLMODE=$SslMode" -v "${Out}:/out" -v "${fpDir}:/fp:ro" $PgImage psql -X -q -h $PoolerHost -p $Port -U $DbUser -d postgres -f "/fp/$fpName"
        if ($LASTEXITCODE -ne 0) { throw 'Fingerprints failed' }
    }
} finally {
    if ($ownPassword) {
        if ($bstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
        Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
    }
    $dbUrl = $null
}
Get-ChildItem $Out -File | Where-Object Name -ne 'SHA256SUMS.txt' | Get-FileHash -Algorithm SHA256 | ForEach-Object { "{0}  {1}" -f $_.Hash.ToLower(), (Split-Path $_.Path -Leaf) } | Set-Content -Encoding ascii "$Out\SHA256SUMS.txt"
Get-ChildItem $Out -File | Format-Table Name, Length -AutoSize
Write-Host "Backup complete: $Out (inventory ok: $inventoryOk)"