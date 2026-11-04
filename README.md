# ai-app

Static nginx app, built and deployed by Harness, with Kosli compliance tracking.

```
GitHub (push to main) ──webhook──► Harness pipeline ai_app (YAML read from .harness/)
                                     Build → Kosli attest → Test → Deploy
                                                                  │
                         EKS namespace ai-app ◄───────────────────┘
                         kosli-reporter (*/5) ──► Kosli env ai-app-prod
```

| Thing | Name |
|---|---|
| GitHub repo | `SoniaBoussabeh/ai-app` |
| Docker image | `docker.io/soniabou/ai-app:<VERSION>` |
| Harness pipeline / service / infra | `ai_app` / `aiapp` / `aiappinfra` (project `foodtrucksre`, env `prod_Env`) |
| k8s namespace | `ai-app` |
| Kosli flow / environment / policy | `ai-app` / `ai-app-prod` / `ai-app-policy` |

## One-time setup

All commands are PowerShell, run from `C:\Users\lenovo\Desktop\App-test`.

### 1. GitHub

```powershell
gh auth login
gh repo create SoniaBoussabeh/ai-app --private --source . --push   # done: repo id 1445561751
```

The `account.githubsonia` connector and `account.github_token` secret must be able to read
this new repo (check the token's repository access if it is a fine-grained token).

### 2. Kosli

No local CLI needed: run it in Docker with the Member token (same pattern as simpleapp's
KOSLI-SETUP.md §3). `--tmpfs /tmp` is mandatory, the image has no `/tmp`.

```powershell
$env:KOSLI_ORG = "SDL-Sandbox"
$env:KOSLI_API_TOKEN = (Get-Content "$env:USERPROFILE\.kosli-member-token" -Raw).Trim()
function kosli { docker run --rm --tmpfs /tmp -e KOSLI_API_TOKEN -e KOSLI_ORG -v "${PWD}:/src" -w /src ghcr.io/kosli-dev/cli:v2.34.0 @args }

kosli create environment ai-app-prod --type K8S --description "ai-app production namespace"
kosli create policy ai-app-policy kosli/policy-ai-app.yaml --description "ai-app runtime requirements" --type env
kosli attach-policy ai-app-policy --environment ai-app-prod
```

The flow `ai-app` is created by the pipeline itself (`kosli create flow` in Kosli Begin Trail).

Then add the environment to the cluster reporter. In simpleapp's `kosli/reporter-values.yaml`
under `reporterConfig.environments`, add:

```yaml
    - name: "ai-app-prod"
      namespaces: [ai-app]
```

and run:

```powershell
cd C:\Users\lenovo\Downloads\appDHWGovernance\simpleapp
helm upgrade --install kosli-reporter kosli/k8s-reporter -f kosli/reporter-values.yaml
cd C:\Users\lenovo\Desktop\App-test
```

### 3. Harness (import from Git, in project `foodtrucksre`)

Import in this order. Each uses connector `account.githubsonia`, repo `ai-app`, branch `main`:

1. **Service:** Services → New Service → Import from Git → `.harness/orgs/default/projects/foodtrucksre/services/aiapp.yaml`
2. **Infrastructure:** Environments → `prod_Env` → Infrastructure Definitions → Import from Git → `.harness/infra-ai-app.yaml`
3. **Pipeline:** Pipelines → Create → Import from Git → `.harness/ai-app-pipeline.yaml`
4. **Jira secret:** create an Atlassian API token for the user in pipeline variable `jiraUsername`
   (https://id.atlassian.com/manage-profile/security/api-tokens) and store it as account-level
   secret `account.jira_api_token` (Project/Account Settings → Secrets → New Secret → Text).
5. **Trigger:** Pipeline → Triggers → New Trigger → GitHub → event **Push**, branch `main`.
   Harness registers the webhook if the connector's token has `admin:repo_hook`; otherwise add
   the webhook URL Harness shows in GitHub → Settings → Webhooks.

From then on: change code or pipeline → commit → push. Nothing is pasted into Harness.

## Change workflow: one Jira ticket = one branch = one PR

```
Jira SCRUM-12 ─► branch SCRUM-12-add-status-page ─► PR to main ─► review/approve ─► merge
                         │                              │                            │
                         └── PR trigger ────────────────┘                            └── push trigger
                             Build + Test only (isRelease=false)                         Build + Test + Deploy (isRelease=true)
                             image VERSION-<sha7>                                        image VERSION
                             Kosli: artifact, jira-ticket, smoke-tests                   Kosli: + pull-request, RCTL-043 decision
```

```powershell
git switch -c SCRUM-12-add-status-page
# ...change code, bump VERSION...
git commit -am "SCRUM-12: add status page"
git push -u origin SCRUM-12-add-status-page
gh pr create --title "SCRUM-12: add status page" --fill
```

Keep the ticket key in the **branch name** and the **PR title**: Kosli's `jira-ticket` attestation
reads it from the branch on PR builds and from the merge/squash commit message on main.

### Harness triggers (Pipeline → Triggers → + New Trigger → GitHub)

| Trigger | Event | Condition | Pipeline inputs |
|---|---|---|---|
| `ai-app-pr` | Pull Request: Open, Reopen, Edit, Synchronize | target branch `main` | `gitBranch` = `<+trigger.sourceBranch>`, `isRelease` = `false` |
| `ai-app-main` | Push | branch `main` | `gitBranch` = `main`, `isRelease` = `true` |

### GitHub branch protection (Settings → Branches → Add rule for `main`)

Require a pull request, 1 approval, and the Harness PR check to pass. Without it, a direct
push to main still deploys; Kosli then records it as non-compliant (RCTL-043), but does not
stop it.

## Release

Bump `VERSION`, commit, push. The pipeline tags the image with that version.
