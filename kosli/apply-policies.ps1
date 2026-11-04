# Creates (or versions) the ai-app environment policies and attaches them to ai-app-prod.
# Requires Docker Desktop and a Kosli Member token in $env:USERPROFILE\.kosli-member-token.
#
#   .\kosli\apply-policies.ps1                      # provenance only (phase 1)
#   .\kosli\apply-policies.ps1 -All                 # all six policies (after the first PR-based release)
#   .\kosli\apply-policies.ps1 -All -Comment "why"  # record why a policy changed (policies are versioned)
param([switch]$All, [string]$Comment = "")

$ErrorActionPreference = "Stop"
$env:KOSLI_ORG = "SDL-Sandbox"
$env:KOSLI_API_TOKEN = (Get-Content "$env:USERPROFILE\.kosli-member-token" -Raw).Trim()
$repo = Split-Path $PSScriptRoot -Parent
function kosli { docker run --rm --tmpfs /tmp -e KOSLI_API_TOKEN -e KOSLI_ORG -v "${repo}:/src" -w /src ghcr.io/kosli-dev/cli:v2.36.1 @args; if ($LASTEXITCODE) { throw "kosli $args failed" } }

$envName = "ai-app-prod"
$existing = kosli list environments --output json | ConvertFrom-Json
if (-not ($existing | Where-Object name -eq $envName)) {
  kosli create environment $envName --type K8S --description "ai-app production namespace"
}

$policies = [ordered]@{
  "ai-app-provenance"       = "Running artifacts were built and attested by the ai-app pipeline"
  "ai-app-pull-request"     = "Change reached main through a GitHub pull request"
  "ai-app-code-review"      = "PR approved by a second developer (RCTL-043-test)"
  "ai-app-smoke-tests"      = "Smoke tests passed on the deployed image"
  "ai-app-jira"             = "Change linked to a Jira SCRUM issue"
  "ai-app-trail-compliance" = "Trail satisfies kosli/flow-template.yml"
}
if (-not $All) { $policies = [ordered]@{ "ai-app-provenance" = $policies["ai-app-provenance"] } }

foreach ($name in $policies.Keys) {
  $create = @("create", "policy", $name, "kosli/policies/$name.yaml", "--description", $policies[$name], "--type", "env")
  if ($Comment) { $create += @("--comment", $Comment) }
  kosli @create
  # Re-attaching an already attached policy is harmless; do not stop the loop on it.
  try { kosli attach-policy $name --environment $envName } catch { Write-Warning $_ }
}
kosli get environment $envName
