# ai-app

Static nginx app (`app/`, `nginx/`, `Dockerfile`) deployed to EKS namespace `ai-app` by Harness.
Version lives in `VERSION` (bump it for every release; it becomes the image tag).

## Connected systems (MCP, see .mcp.json)

- **Kosli** (`kosli` server): org `SDL-Sandbox`. Pass `org: "SDL-Sandbox"` on every call.
  - Flow `ai-app`, environment `ai-app-prod` (namespace `ai-app`), policy `ai-app-policy`.
  - The cluster reporter (`kosli-reporter-k8s-reporter` CronJob, every 5 min) pushes snapshots; Harness attests builds.
- **Harness** (`harness` server, read-only): pipeline `ai_app` in project `foodtrucksre`, stored in this repo at `.harness/ai-app-pipeline.yaml`. Use it to trace a Kosli artifact back to the pipeline execution that produced it.
- **Grafana** (`grafana` server, read-only): dashboards, metrics/logs queries, alerts. Use it to check runtime health around a deployment.
- **Jira** (`atlassian` server): OAuth via `/mcp`.

## Rules

- Commits are authored by Sonia BOUSSABEH only. Do not add Claude co-author or "Generated with Claude" lines.
- Pipeline changes go in `.harness/*.yaml` via a commit, never pasted into the Harness UI.
- Kosli write actions (create/attest/attach policy) change real compliance records. Show the action and params and wait for confirmation.
- When a Kosli environment goes NON-COMPLIANT, find the offending artifact (by image digest), then propose a Jira issue that links the Kosli snapshot/trail URL.
