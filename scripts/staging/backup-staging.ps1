# Read-only backup of OUTLAND staging (clgpxvyflycudzhdzjlv) via the Session Pooler.
# Run in your own PowerShell window (needs an interactive password prompt):
#   powershell -ExecutionPolicy Bypass -File scripts\staging\backup-staging.ps1 [-OutRoot <dir outside any Git repo>]
# Only pg_dump / supabase db dump / READ ONLY psql are used. Nothing is written to staging.
# The password is only ever held in PGPASSWORD (process env) - never in a URL or on a command line.
# Optional (used by scripts/staging/sideworld-v3-2): if PGPASSWORD is already set by a guarded staging session
# it is reused instead of prompting again, and -FingerprintSql runs one more READ ONLY psql file (writing to
# /out) before the checksums, so its CSVs are covered by SHA256SUMS.txt.
param(
    [string]$Ref        = 'clgpxvyflycudzhdzjlv',
    [string]$PoolerHost = 'aws-1-eu-west-1.pooler.supabase.com',
    [int]   $Port       = 5432,
    [string]$DbUser     = '',
    [string]$SslMode    = 'require',
    [string]$OutRoot    = (Join-Path $HOME 'outland-backups'),
    [string]$FingerprintSql = ''
)
$ErrorActionPreference = 'Stop'
if (-not $DbUser) { $DbUser = "postgres.$Ref" }
$PgImage    = 'postgres:17'
$SupabaseCli = 'supabase@2.119.0'
New-Item -ItemType Directory -Force -Path $OutRoot | Out-Null
# Backups contain data: never write them inside a Git work tree.
$insideGit = $null
try { $insideGit = & git -C $OutRoot rev-parse --is-inside-work-tree 2>$null } catch { }
if ($insideGit -eq 'true') { throw "Refusing to write backups inside a Git work tree: $OutRoot" }
$Out        = Join-Path $OutRoot ("staging-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))

# Hard guard: never point this at production.
$ProductionRef = 'huzcukdovavejejwohey'
if ("$Ref $PoolerHost $DbUser" -match $ProductionRef) { throw "Refusing to run: target references the PRODUCTION project ($ProductionRef)." }

docker info --format '{{.ServerVersion}}' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Docker is not running.' }

New-Item -ItemType Directory -Path $Out | Out-Null
# Restrict the backup folder to the current user only (by SID, so no name ambiguity).
$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
icacls $Out /inheritance:r /grant:r "*${sid}:(OI)(CI)F" | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Failed to restrict backup folder ACL.' }

Write-Host "Target: $DbUser @ ${PoolerHost}:$Port (ref $Ref) - READ ONLY"
$ownPassword = -not $env:PGPASSWORD
$bstr = [IntPtr]::Zero
if ($ownPassword) {
    $sec = Read-Host 'Staging database password' -AsSecureString
    if ($sec.Length -eq 0) { throw 'Empty password - aborting.' }
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
}
$inventoryOk = $false
try {
    if ($ownPassword) { $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    # No password in the URL: the Supabase CLI and libpq both read PGPASSWORD from the environment.
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

    # PGPASSWORD is passed to the container by name only, never on the command line.
    $dockerArgs = @('run','--rm','-e','PGPASSWORD','-e',"PGSSLMODE=$SslMode",'-v',"${Out}:/out",'-v',"${PSScriptRoot}:/scripts:ro",$PgImage)
    Write-Host '[4/5] Full pg_dump (custom format, incl. supabase_migrations history)'
    docker @dockerArgs pg_dump -h $PoolerHost -p $Port -U $DbUser -d postgres -Fc -f /out/staging-full.dump
    if ($LASTEXITCODE -ne 0) {
        # Never leave a partial dump that looks valid.
        if (Test-Path "$Out\staging-full.dump") { Rename-Item "$Out\staging-full.dump" 'staging-full.dump.FAILED' }
        Write-Warning 'Full pg_dump reported errors (partial file renamed *.FAILED); Supabase-format dumps above remain the primary backup.'
    }
    Write-Host '[5/5] Read-only inventory'
    docker @dockerArgs psql -X -h $PoolerHost -p $Port -U $DbUser -d postgres -f /scripts/inventory.sql
    if ($LASTEXITCODE -eq 0) { $inventoryOk = $true } else { Write-Warning 'Inventory failed; dumps are still valid. Report the error above.' }
    if ($FingerprintSql) {
        Write-Host '[+] Read-only fingerprints'
        $fpDir = Split-Path (Resolve-Path $FingerprintSql) -Parent
        $fpName = Split-Path $FingerprintSql -Leaf
        docker run --rm -e PGPASSWORD -e "PGSSLMODE=$SslMode" -v "${Out}:/out" -v "${fpDir}:/fp:ro" $PgImage psql -X -q -h $PoolerHost -p $Port -U $DbUser -d postgres -f "/fp/$fpName"
        if ($LASTEXITCODE -ne 0) { $inventoryOk = $false; Write-Warning 'Fingerprints failed. Report the error above.' }
    }
}
finally {
    if ($ownPassword) {
        if ($bstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
        Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
    }
    $dbUrl = $null
}

Get-ChildItem $Out -File | Where-Object Name -ne 'SHA256SUMS.txt' | Get-FileHash -Algorithm SHA256 |
    ForEach-Object { "{0}  {1}" -f $_.Hash.ToLower(), (Split-Path $_.Path -Leaf) } |
    Set-Content -Encoding ascii "$Out\SHA256SUMS.txt"
Get-ChildItem $Out -File | Format-Table Name, Length -AutoSize
Write-Host "Backup complete: $Out (inventory ok: $inventoryOk)"
