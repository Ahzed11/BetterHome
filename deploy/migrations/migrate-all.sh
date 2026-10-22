#!/bin/sh
# Applies the Flyway migrations of every service to its own database, in order. Safe to rerun.
# DB_HOST (default postgres), DB_USER and DB_PASSWORD come from the Compose file.
set -eu

for service in households tasks scoring lists notifications; do
  echo "Migrating betterhome_${service}..."
  # Flyway retries the connection once a second, because Postgres may still be starting.
  flyway \
    -url="jdbc:postgresql://${DB_HOST:-postgres}:5432/betterhome_${service}" \
    -user="${DB_USER}" -password="${DB_PASSWORD}" \
    -locations="filesystem:/migrations/${service}" \
    -connectRetries=60 \
    migrate
done
echo "All databases migrated."
