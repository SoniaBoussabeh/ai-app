# Publishes every dashboard in grafana/dashboards/ to Grafana Cloud, overwriting the
# copy there: the JSON in Git is the source of truth, UI edits are lost on next publish.
#
#   .\grafana\publish-dashboards.ps1
#
# Needs $env:GRAFANA_URL and $env:GRAFANA_SERVICE_ACCOUNT_TOKEN (dashboards:write).
$ErrorActionPreference = "Stop"
$base = $env:GRAFANA_URL.TrimEnd('/')
$headers = @{ Authorization = "Bearer $env:GRAFANA_SERVICE_ACCOUNT_TOKEN"; "Content-Type" = "application/json" }

Get-ChildItem (Join-Path $PSScriptRoot "dashboards") -Filter *.json | ForEach-Object {
  $dash = Get-Content $_.FullName -Raw | ConvertFrom-Json
  $body = @{ dashboard = $dash; overwrite = $true; message = "Published from Git: $($_.Name)" } | ConvertTo-Json -Depth 50
  $r = Invoke-RestMethod -Method Post -Uri "$base/api/dashboards/db" -Headers $headers -Body $body
  Write-Host "published $($_.Name) -> $base$($r.url)"
}
