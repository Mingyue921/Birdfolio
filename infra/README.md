# Birdfolio deployment foundation

This directory contains deployable configuration examples only. It does not provision or purchase Huawei Cloud resources.

## ICT competition deployment

Build `web/` first, copy `competition.env.example` to an untracked `competition.env`, and inject every real value through CodeArts Secret or an equivalent protected environment. `docker-compose.competition.yml` runs the private API and Caddy HTTPS entry; RDS, DCS, OBS and MaaS remain managed Huawei Cloud services and are never published by this Compose file.

Use `DEPLOYMENT_PROFILE=competition` only for the temporary competition demo. A commercial release must switch to `commercial`, disable `COMPETITION_DEMO_LOGIN`, use a filed domain and restore the production email login requirements. The exact human cloud procedure and rollback checklist are in `docs/competition/cloud-deployment-runbook.md`.

## Local PostgreSQL contract test

```powershell
docker compose -f infra/docker-compose.postgres.yml up -d
$env:TEST_DATABASE_URL='postgresql://birdfolio:local-birdfolio-password@127.0.0.1:54329/birdfolio'
npm --prefix server test
docker compose -f infra/docker-compose.postgres.yml down
```

The PostgreSQL test creates an isolated schema and removes it after the run. Without `TEST_DATABASE_URL`, it is reported as skipped rather than silently simulated.

## Production topology

```text
Huawei Cloud HTTPS ingress / load balancer
  -> private Node.js container
     -> RDS for PostgreSQL
     -> DCS Redis
     -> OBS private bucket
     -> mail provider
     -> HTTPS vision provider
```

1. Copy `infra/production.env.example` into the deployment secret manager. Never commit the populated file.
2. Restrict RDS, OBS and the container to private networking and least-privilege service credentials.
3. Terminate public TLS at the ingress and expose only that endpoint. The application port must remain private.
4. Run `npm run check:release` and `npm run db:migrate` before starting the new container.
5. Verify `/health/live` for process liveness and `/health/ready` for database and object-storage readiness.
6. Schedule `npm run db:backup` and `npm run cleanup:media`; copy backups to a separate protected retention location.
7. Perform a restore drill with a non-production database before launch. Restore requires `CONFIRM_RESTORE=RESTORE_BIRDFOLIO` and `--from=<backup>`.

OBS must use a private bucket. Clients fetch media through authenticated Birdfolio routes; bucket credentials and direct object URLs are never returned. Configure lifecycle rules only after confirming they do not conflict with application media retention.
