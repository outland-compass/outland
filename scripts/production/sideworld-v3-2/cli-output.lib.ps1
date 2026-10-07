# Output parsing for deploy-sideworld-1b.ps1. Independent of the CLI output mode:
#  - interactive console: human-readable list (" • <file>.sql" lines, no JSON summary)
#  - agent environments (CLAUDECODE / AI_AGENT set): the same list plus a JSON summary line
# and of the console code page (the bullet may arrive mangled, e.g. "ΓÇó" under code page 437).

$script:MigrationLine = '^\s*\S{1,3}\s+(\d{12,14}_[a-z0-9_]+\.sql)\s*$'

function Get-PushListing([string[]]$Out) {
    # Returns the ordered file list the CLI says it would push, or throws if the output is not understood.
    $lines = @($Out | ForEach-Object { "$_" -replace "`r", '' })
    $header = [array]::FindIndex([string[]]$lines, [Predicate[string]]{ param($l) $l -match '^\s*Would push these migrations:\s*$' })
    $text = @()
    if ($header -ge 0) {
        for ($i = $header + 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match $script:MigrationLine) { $text += $Matches[1] } else { break }
        }
    }
    $json = $lines | Where-Object { $_ -match '^\{.*"dryRun":true' } | Select-Object -Last 1
    $fromJson = $null
    if ($json) { $fromJson = @(($json | ConvertFrom-Json).migrations) }
    if ($header -lt 0 -and -not $json) { throw 'Dry-run output not understood (no "Would push these migrations:" header and no JSON summary)' }
    if ($null -ne $fromJson -and $header -ge 0 -and (($fromJson -join '|') -ne ($text -join '|'))) {
        throw 'Dry-run text listing and JSON summary disagree'
    }
    # Every migration filename mentioned anywhere must be part of the listing (nothing unexpected hidden elsewhere).
    $mentioned = @($lines | Select-String -Pattern '\d{12,14}_[a-z0-9_]+\.sql' -AllMatches | ForEach-Object { $_.Matches.Value } | Select-Object -Unique)
    $listing = if ($header -ge 0) { $text } else { $fromJson }
    foreach ($m in $mentioned) { if ($listing -notcontains $m) { throw "Dry-run output mentions an unlisted migration: $m" } }
    return ,$listing
}

function Test-NoSeedPushed([string[]]$Out) {
    # True only if the push output shows no seeding and (when a JSON summary exists) an empty seeds list.
    $lines = @($Out | ForEach-Object { "$_" })
    if ($lines | Where-Object { $_ -match '(?i)seeding|seed\.sql' -and $_ -notmatch '"seeds":\[\]' }) { return $false }
    $json = $lines | Where-Object { $_ -match '^\{.*"dryRun":false' } | Select-Object -Last 1
    if ($json) { return ($json -match '"seeds":\[\]') }
    return [bool]($lines | Where-Object { $_ -match '^\s*Finished supabase db push\.\s*$' })
}
