#Requires -Version 7.4
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Push-Location $root
try {
    # AzAPI omits this write-only value from both plan and state JSON.
    $source = Get-Content -LiteralPath 'main.tf' -Raw
    $module = [regex]::Match($source, '(?ms)^module "public_ip_address" \{\r?\n(.*?)^\}')
    if (-not $module.Success -or
        $module.Groups[1].Value -notmatch '(?m)^\s*ignore_body_changes\s*=\s*var\.ignore_body_changes\.public_ip_address\s*$') {
        throw 'The owned public IP must receive its nested ignore_body_changes unchanged.'
    }

    $lines = @(& terraform test -test-directory=tests/unit -verbose -json)
    if ($LASTEXITCODE -ne 0) {
        $lines | Write-Output
        throw "Terraform mocked tests failed with exit code $LASTEXITCODE."
    }
    $events = @($lines | ForEach-Object { $_ | ConvertFrom-Json })
    $states = @($events | Where-Object type -EQ 'test_state')
    $checked = 0
    foreach ($event in $states) {
        $run = $event.'@testrun'
        if ($run -notin @('created_ip_defaults', 'created_ip_null_controls', 'apply_child_controls')) {
            continue
        }
        $children = @($event.test_state.root_module.child_modules |
            Where-Object address -EQ 'module.public_ip_address[0]')
        if ($children.Count -ne 1) {
            throw "${run}: expected exactly one owned public IP child."
        }
        $resources = @($children[0].resources |
            Where-Object address -EQ 'module.public_ip_address[0].azapi_resource.this')
        if ($resources.Count -ne 1) {
            throw "${run}: missing the child's public IP create writer."
        }
        $ip = $resources[0].values
        $overridden = $run -eq 'apply_child_controls'
        $expectedType = if ($overridden) { 'Microsoft.Network/publicIPAddresses@2024-05-01' } else { 'Microsoft.Network/publicIPAddresses@2025-07-01' }
        if ($ip.type -ne $expectedType) {
            throw "${run}: child type '$($ip.type)' differs from '$expectedType'."
        }
        if ($overridden) {
            if ($ip.retry.interval_seconds -ne 7 -or $ip.retry.max_interval_seconds -ne 70 -or
                ($ip.retry.error_message_regex | ConvertTo-Json -Compress -AsArray) -ne '["ExampleTransientError"]') {
                throw "${run}: retry override did not reach the child create writer."
            }
            $expectedTimeouts = @{ create = '41m'; read = '6m'; update = '42m'; delete = '43m' }
            foreach ($key in $expectedTimeouts.Keys) {
                if ($ip.timeouts.$key -ne $expectedTimeouts[$key]) {
                    throw "${run}: $key timeout override did not reach the child create writer."
                }
            }
        }
        $checked++
    }
    if ($checked -ne 3) {
        throw "Expected three rendered child-control states; inspected $checked."
    }
    Write-Output 'Public IP propagation: three rendered child states and write-only ignore-path binding passed.'
}
finally {
    Pop-Location
}
