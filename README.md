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

### 1. GitHub

```shell
gh auth login
gh repo create SoniaBoussabeh/ai-app --private --source . --push
gh api repos/SoniaBoussabeh/ai-app --jq .id      # -> put in githubRepoId (step 3)
```

The `account.githubsonia` connector and `account.github_token` secret must be able to read
this new repo (check the token's repository access if it is a fine-grained token).

### 2. Kosli

```shell
kosli create environment ai-app-prod --type K8S --description "ai-app production namespace" --org SDL-Sandbox
kosli create policy ai-app-policy kosli/policy-ai-app.yaml --description "ai-app runtime requirements" --type env --org SDL-Sandbox
kosli attach-policy ai-app-policy --environment ai-app-prod --org SDL-Sandbox
```

The flow `ai-app` is created by the pipeline itself (`kosli create flow` in Kosli Begin Trail).

Then add the environment to the cluster reporter. In simpleapp's `kosli/reporter-values.yaml`
under `reporterConfig.environments`, add:

```yaml
    - name: "ai-app-prod"
      namespaces: [ai-app]
```

and run `helm upgrade --install kosli-reporter kosli/k8s-reporter -f kosli/reporter-values.yaml`.

### 3. Harness (import from Git, in project `foodtrucksre`)

Import in this order. Each uses connector `account.githubsonia`, repo `ai-app`, branch `main`:

1. **Service:** Services → New Service → Import from Git → `.harness/service-ai-app.yaml`
2. **Infrastructure:** Environments → `prod_Env` → Infrastructure Definitions → Import from Git → `.harness/infra-ai-app.yaml`
3. **Pipeline:** Pipelines → Create → Import from Git → `.harness/ai-app-pipeline.yaml`
4. Set `githubRepoId` in `.harness/ai-app-pipeline.yaml` to the id from step 1, commit and push.
5. **Trigger:** Pipeline → Triggers → New Trigger → GitHub → event **Push**, branch `main`.
   Harness registers the webhook if the connector's token has `admin:repo_hook`; otherwise add
   the webhook URL Harness shows in GitHub → Settings → Webhooks.

From then on: change code or pipeline → commit → push. Nothing is pasted into Harness.

## Release

Bump `VERSION`, commit, push. The pipeline tags the image with that version.
