# Publishes the ai-app alerting from Git to Grafana Cloud: folder, contact point, alert
# rule (SCRUM-10, checklist CM-11). Provisioned through the API, so the rule is locked
# in the Grafana UI: change it here and publish again.
#
#   .\grafana\publish-alerting.ps1
#
# Needs $env:GRAFANA_URL and $env:GRAFANA_SERVICE_ACCOUNT_TOKEN (alert.rules:write,
# alert.notifications.receivers:create, folders:create).
$ErrorActionPreference = "Stop"
$base = $env:GRAFANA_URL.TrimEnd('/')
$h = @{ Authorization = "Bearer $env:GRAFANA_SERVICE_ACCOUNT_TOKEN"; "Content-Type" = "application/json" }
$dir = Join-Path $PSScriptRoot "alerting"

function Upsert($getUri, $postUri, $putUri, $body) {
  try { Invoke-RestMethod -Method Get -Uri $getUri -Headers $h | Out-Null; Invoke-RestMethod -Method Put -Uri $putUri -Headers $h -Body $body | Out-Null; "updated" }
  catch { if ($_.Exception.Response.StatusCode.value__ -ne 404) { throw }; Invoke-RestMethod -Method Post -Uri $postUri -Headers $h -Body $body | Out-Null; "created" }
}

# folder
try { Invoke-RestMethod -Method Get -Uri "$base/api/folders/ai-app" -Headers $h | Out-Null; Write-Host "folder ai-app exists" }
catch { Invoke-RestMethod -Method Post -Uri "$base/api/folders" -Headers $h -Body '{"uid":"ai-app","title":"ai-app"}' | Out-Null; Write-Host "folder ai-app created" }

# contact point (no GET by uid in the API: look it up in the list)
$cp = Get-Content (Join-Path $dir "contact-point.json") -Raw
$exists = (Invoke-RestMethod -Method Get -Uri "$base/api/v1/provisioning/contact-points" -Headers $h) | Where-Object uid -eq "ai-app-compliance"
if ($exists) { Invoke-RestMethod -Method Put -Uri "$base/api/v1/provisioning/contact-points/ai-app-compliance" -Headers $h -Body $cp | Out-Null; Write-Host "contact point updated" }
else { Invoke-RestMethod -Method Post -Uri "$base/api/v1/provisioning/contact-points" -Headers $h -Body $cp | Out-Null; Write-Host "contact point created" }

# alert rules
Get-ChildItem $dir -Filter "*.json" | Where-Object Name -ne "contact-point.json" | ForEach-Object {
  $body = Get-Content $_.FullName -Raw
  $uid = ($body | ConvertFrom-Json).uid
  $r = Upsert "$base/api/v1/provisioning/alert-rules/$uid" "$base/api/v1/provisioning/alert-rules" "$base/api/v1/provisioning/alert-rules/$uid" $body
  Write-Host "alert rule $uid $r"
}

# evaluate the group every 5 minutes, like the Kosli reporter
$group = Invoke-RestMethod -Method Get -Uri "$base/api/v1/provisioning/folder/ai-app/rule-groups/ai-app-compliance" -Headers $h
$group.interval = 300
Invoke-RestMethod -Method Put -Uri "$base/api/v1/provisioning/folder/ai-app/rule-groups/ai-app-compliance" -Headers $h -Body ($group | ConvertTo-Json -Depth 50) | Out-Null
Write-Host "rule group ai-app-compliance: every 5 minutes"
