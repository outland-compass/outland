# Guarded OUTLAND PRODUCTION DB session. Password is held only in PGPASSWORD.
param(
    [string]$Ref        = 'huzcukdovavejejwohey',
    [string]$PoolerHost = 'aws-1-eu-west-1.pooler.supabase.com',
    [int]   $Port       = 5432,
    [string]$DbUser     = '',
    [string]$SslMode    = 'require'
)
$StagingRef = 'clgpxvyflycudzhdzjlv'
if (-not $DbUser) { $DbUser = "postgres.$Ref" }
if ($Ref -ne 'huzcukdovavejejwohey') { throw "Refusing: unexpected production project ref: $Ref" }
if ("$Ref $DbUser" -match $StagingRef) { throw "Refusing: staging reference detected in production session." }

$sec = Read-Host "Password for $DbUser (OUTLAND production)" -AsSecureString
if ($sec.Length -eq 0) { throw 'Empty password - aborting.' }
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
try { $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }

$global:ProductionDbUrl = "postgresql://${DbUser}@${PoolerHost}:${Port}/postgres?sslmode=$SslMode"
$global:ProductionConn  = @{ Host = $PoolerHost; Port = $Port; User = $DbUser; SslMode = $SslMode }
Write-Host "Production session open: $global:ProductionDbUrl (password held in PGPASSWORD only)"

function global:Close-ProductionSession {
    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
    Remove-Variable -Scope Global -Name ProductionDbUrl, ProductionConn -ErrorAction SilentlyContinue
    Write-Host 'Production session closed (PGPASSWORD cleared).'
}
