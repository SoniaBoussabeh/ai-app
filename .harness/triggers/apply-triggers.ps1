# Creates or updates the ai-app Harness triggers from the YAML files next to this script.
# Harness does not store triggers in Git, so these files are the source of truth.
#
#   .\.harness\triggers\apply-triggers.ps1
#
# Needs $env:HARNESS_API_KEY with permission to create/edit pipelines (a Viewer key is not enough).
$ErrorActionPreference = "Stop"
if (-not $env:HARNESS_API_KEY) { throw "HARNESS_API_KEY is not set" }

$account = "RvD5ClfsQsKNsEOEwhb8Mw"
$scope   = "accountIdentifier=$account&orgIdentifier=default&projectIdentifier=foodtrucksre&targetIdentifier=aiapp"
$base    = "https://app.harness.io/pipeline/api/triggers"
$headers = @{ "x-api-key" = $env:HARNESS_API_KEY; "Content-Type" = "application/yaml" }

Get-ChildItem $PSScriptRoot -Filter *.yaml | ForEach-Object {
  $yaml = Get-Content $_.FullName -Raw
  $id   = ($yaml | Select-String -Pattern '(?m)^  identifier:\s*(\S+)').Matches[0].Groups[1].Value
  try {
    Invoke-RestMethod -Method Get -Headers $headers -Uri "$base/$id`?$scope" | Out-Null
    Invoke-RestMethod -Method Put -Headers $headers -Uri "$base/$id`?$scope" -Body $yaml | Out-Null
    Write-Host "updated trigger $id"
  } catch {
    if ($_.Exception.Response.StatusCode.value__ -ne 404 -and $_.Exception.Response.StatusCode.value__ -ne 400) { throw }
    Invoke-RestMethod -Method Post -Headers $headers -Uri "$base`?$scope" -Body $yaml | Out-Null
    Write-Host "created trigger $id"
  }
}
