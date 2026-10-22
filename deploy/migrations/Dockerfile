# One-shot Flyway image for the self-hosted stack (deploy/nas, T-0108). The NAS has no checkout of the
# repository, so the SQL of every service travels in this image, tagged like the service images.
# Build from the repository root: podman build -f deploy/migrations/Dockerfile .
FROM docker.io/flyway/flyway:11-alpine
COPY backend/services/households-service/src/main/resources/db/migration /migrations/households/
COPY backend/services/tasks-service/src/main/resources/db/migration /migrations/tasks/
COPY backend/services/scoring-service/src/main/resources/db/migration /migrations/scoring/
COPY backend/services/lists-service/src/main/resources/db/migration /migrations/lists/
COPY backend/services/notifications-service/src/main/resources/db/migration /migrations/notifications/
COPY deploy/migrations/migrate-all.sh /usr/local/bin/migrate-all
ENTRYPOINT ["/usr/local/bin/migrate-all"]
