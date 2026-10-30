#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateCount(2, 2)]
    [string[]] $PlanPaths
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
foreach ($path in $PlanPaths) {
    $plan = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    $changes = @($plan.resource_changes)
    $hostResources = @($changes | Where-Object {
        $_.mode -eq 'managed' -and $_.address -match 'azapi_resource\.bastion\[0\]$'
    })
    $ownedIpResources = @($changes | Where-Object {
        $_.mode -eq 'managed' -and $_.address -match 'module\.public_ip_address\[0\]\.azapi_resource\.this$'
    })
    if ($hostResources.Count -ne 1 -or $ownedIpResources.Count -ne 1) {
        throw "${path}: expected one Bastion host and one owned Public IP create writer."
    }
    $pending = @($changes | Where-Object {
        ($_.change.actions | ConvertTo-Json -Compress -AsArray) -ne '["no-op"]'
    })
    if ($pending.Count -gt 0) {
        $details = $pending | ForEach-Object { "$($_.address): $($_.change.actions -join ',')" }
        throw "${path}: refreshed deployment does not converge. $($details -join '; ')"
    }
    foreach ($output in $plan.output_changes.PSObject.Properties) {
        if (($output.Value.actions | ConvertTo-Json -Compress -AsArray) -ne '["no-op"]') {
            throw "${path}: output '$($output.Name)' still changes after refresh."
        }
    }
}
Write-Output 'Bastion convergence: both refreshed plans contain only no-op resource and output actions.'
