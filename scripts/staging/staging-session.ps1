# Dot-source in an interactive PowerShell to open a guarded outland-staging session:
#   . .\scripts\staging\staging-session.ps1
# Defines $StagingDbUrl (NO password inside) and Invoke-StagingSql. The password is read once as a
# SecureString into $env:PGPASSWORD (process env only, never on a command line, URL or log).
# End the session with: Close-StagingSession
param(
    [string]$Ref        = 'clgpxvyflycudzhdzjlv',
    [string]$PoolerHost = 'aws-1-eu-west-1.pooler.supabase.com',
    [int]   $Port       = 5432,
    [string]$DbUser     = '',
    [string]$SslMode    = 'require'
)
$ProductionRef = 'huzcukdovavejejwohey'
if (-not $DbUser) { $DbUser = "postgres.$Ref" }
if ("$Ref $PoolerHost $DbUser" -match $ProductionRef) { throw "Refusing: target references the PRODUCTION project ($ProductionRef)." }

$sec = Read-Host "Password for $DbUser (outland-staging)" -AsSecureString
if ($sec.Length -eq 0) { throw 'Empty password - aborting.' }
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
try { $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }

$global:StagingDbUrl = "postgresql://${DbUser}@${PoolerHost}:${Port}/postgres?sslmode=$SslMode"
$global:StagingConn  = @{ Host = $PoolerHost; Port = $Port; User = $DbUser; SslMode = $SslMode }
Write-Host "Staging session open: $global:StagingDbUrl (password held in PGPASSWORD only)"

function global:Invoke-StagingSql {
    # Runs a SQL file against staging with psql 17 in Docker. -PreSql statements run first in the
    # same session (e.g. "set outland.world_canon = legacy_compatible"); this works through the
    # Supabase pooler, unlike PGOPTIONS startup parameters.
    param([Parameter(Mandatory)][string]$File, [string[]]$PreSql = @())
    $dir  = Split-Path (Resolve-Path $File) -Parent
    $name = Split-Path $File -Leaf
    $c = $global:StagingConn
    $pre = @(); foreach ($s in $PreSql) { $pre += @('-c', $s) }
    # psql NOTICEs go to stderr; Windows PowerShell would turn them into errors under 'Stop'.
    # Treat native output as text and decide success solely by psql's exit code.
    $ErrorActionPreference = 'Continue'
    docker run --rm -i -e PGPASSWORD -e "PGSSLMODE=$($c.SslMode)" -v "${dir}:/s:ro" postgres:17 `
        psql -X -v ON_ERROR_STOP=1 -h $c.Host -p $c.Port -U $c.User -d postgres @pre -f "/s/$name" 2>&1 |
        ForEach-Object { "$_" }
    if ($LASTEXITCODE -ne 0) { throw "SQL failed: $name - STOP and follow the runbook failure section." }
}

function global:Close-StagingSession {
    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
    Remove-Variable -Scope Global -Name StagingDbUrl, StagingConn -ErrorAction SilentlyContinue
    Write-Host 'Staging session closed (PGPASSWORD cleared).'
}
