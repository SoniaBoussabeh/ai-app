# ai-app

Static nginx app, built and deployed by Harness, with Kosli compliance tracking.

```
GitHub (push to main) ──webhook──► Harness pipeline aiapp (YAML read from .harness/)
                                     Build → Kosli attest → Test → Deploy
                                                                  │
                         EKS namespace ai-app ◄───────────────────┘
                         kosli-reporter (*/5) ──► Kosli env ai-app-prod
```

| Thing | Name |
|---|---|
| GitHub repo | `SoniaBoussabeh/ai-app` |
| Docker image | `docker.io/soniabou/ai-app:<VERSION>` |
| Harness pipeline / service / infra | `aiapp` / `aiapp` / `aiappinfra` (project `foodtrucksre`, env `prod_Env`) |
| k8s namespace | `ai-app` |
| Kosli flow / environment / policies | `ai-app` / `ai-app-prod` / `ai-app-*` (see §2) |

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

One policy per concern, each attached to `ai-app-prod` (files in `kosli/policies/`):

| Policy | Requires | Control |
|---|---|---|
| `ai-app-provenance` | artifact built and attested by the pipeline | binary provenance |
| `ai-app-pull-request` | `pull-request` attestation | change via PR |
| `ai-app-code-review` | compliant decision for `RCTL-043-test` | source code review |
| `ai-app-smoke-tests` | `smoke-tests` JUnit attestation | quality assurance |
| `ai-app-jira` | `jira-ticket` attestation | change linked to a ticket |
| `ai-app-trail-compliance` | everything in `kosli/flow-template.yml` | — |

```powershell
.\kosli\apply-policies.ps1        # phase 1: creates ai-app-prod + provenance policy
.\kosli\apply-policies.ps1 -All   # after the first PR-based release is green
```

The flow `ai-app` is created by the pipeline itself (`kosli create flow` in Kosli Begin Trail).

The cluster reporter config lives in [kosli/reporter-values.yaml](kosli/reporter-values.yaml)
(all environments of the cluster, `ai-app-prod` included). After changing it:

```powershell
helm repo update kosli
helm upgrade --install kosli-reporter kosli/k8s-reporter --version 2.6.0 -n default -f kosli/reporter-values.yaml
```

### 3. Harness (import from Git, in project `foodtrucksre`)

Import in this order. Each uses connector `account.githubsonia`, repo `ai-app`, branch `main`:

1. **Service:** Services → New Service → Import from Git → `.harness/orgs/default/projects/foodtrucksre/services/aiapp.yaml`
2. **Infrastructure:** Environments → `prod_Env` → Infrastructure Definitions → Import from Git → `.harness/orgs/default/projects/foodtrucksre/envs/production/prod_Env/infras/aiappinfra.yaml`
3. **Pipeline:** Pipelines → Create → Import from Git → `.harness/orgs/default/projects/foodtrucksre/pipelines/aiapp.yaml`
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

## Vulnerability gate and exceptions (SCRUM-8)

The pipeline fails on any HIGH or CRITICAL Trivy finding, before Deploy. To ship with a
known finding, add it to `.trivyignore.yaml` with a reason (owner, ticket) and an
`expired_at` date, through a pull request: the PR approver accepts the risk, and the file
is attached to the Kosli `vulnerability-scan` attestation. Expired entries stop applying.

## Grafana (SCRUM-7)

Dashboard **ai-app: Kosli compliance** in Grafana Cloud `digitalq`
(https://digitalq.grafana.net/d/ai-app-kosli-compliance): compliance of `ai-app-prod` and
`simple-app-prod`, the version running, all environments, the `ai-app` trails and the
`ai-app-prod` event log, read live from the Kosli API through the Infinity data source
`Kosli SDL-Sandbox` (bearer token kept in Grafana, allowed host `app.kosli.com`).

The JSON in `grafana/dashboards/` is the source of truth; publish it with:

```powershell
.\grafana\publish-dashboards.ps1
```

## Release

Every PR must bump `VERSION` above the one on `main` (e.g. `0.1.1` -> `0.1.2`); the PR build's
**Check Version Bump** step fails otherwise. The merged version becomes the image tag.

Jira: https://dhw-app.atlassian.net/jira/software/projects/SCRUM/boards/
