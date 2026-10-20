# BetterHome on OpenShift

Kustomize manifests for the five services (T-0004, [ADR 0003](../../documentation/decisions/0003-openshift-local-podman.md)).
**Status: rendered and schema-checked offline only. Never applied to a cluster.**

```
base/   per service: Deployment, Service, Route, Flyway migration Job; ConfigMaps (shared, per service, SQL)
crc/    overlay for OpenShift Local: namespace betterhome, 1 replica, Keycloak URL, secrets.example.yaml
```

Ports are each service's `quarkus.http.port` (8081 households, 8082 tasks, 8083 scoring, 8084 lists, 8085 notifications).
Probes use SmallRye Health: `/q/health/live` (startup, liveness) and `/q/health/ready` (readiness).
Images are `ghcr.io/ahzed11/betterhome-<service>:latest` (published by `.github/workflows/publish-images.yml`); pin a tag with an `images:` entry in an overlay.

## Prerequisites (not created here, T-0104)

- Namespace: `oc new-project betterhome`.
- PostgreSQL reachable as Service `postgres` in the namespace (an ExternalName Service works for a managed database), with the five databases of [init-databases.sql](../postgres/init-databases.sql).
- Keycloak with the realm of [deploy/keycloak](../keycloak); set its URL in `crc/kustomization.yaml` (`OIDC_AUTH_SERVER_URL`) and the web origin in `QUARKUS_HTTP_CORS_ORIGINS`.
- Secrets `betterhome-db` and `betterhome-oidc`, created from the template [crc/secrets.example.yaml](crc/secrets.example.yaml). Never commit real values. Pods stay in `CreateContainerConfigError` until they exist.

## Deploy

```bash
oc kustomize --load-restrictor=LoadRestrictionsNone deploy/openshift/crc | oc apply -f -
oc wait --for=condition=complete job -l app.kubernetes.io/component=migration --timeout=300s
```

`--load-restrictor=LoadRestrictionsNone` is needed because the migration ConfigMaps are generated from `backend/services/*/src/main/resources/db/migration`.
The Jobs and the Deployments start together; the services become ready once the schema exists. Migrations never run at service startup.
A Job's spec is immutable and its SQL ConfigMap has no hash suffix, so to re-run migrations after adding a migration file:
`oc delete job -l app.kubernetes.io/component=migration` and apply again.

## Validate without a cluster

```bash
make test-openshift-ports   # in make check: ports, probe paths, image and Job names against application.properties
make test-openshift         # optional: needs kustomize, oc or kubectl; uses kubeconform when installed (Routes are skipped)
```
