# BetterHome developer commands. See AGENTS.md §6.1.
SHELL := /bin/bash
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
BACKEND := $(ROOT)/backend
COMPOSE := podman compose -f $(ROOT)/deploy/podman-compose.yml
JAVA_HOME ?= $(shell jbang jdk home 21 2>/dev/null)
export JAVA_HOME
export PATH := $(JAVA_HOME)/bin:$(PATH)
# Quarkus Dev Services / Testcontainers against rootless Podman
export DOCKER_HOST ?= unix://$(XDG_RUNTIME_DIR)/podman/podman.sock
export TESTCONTAINERS_RYUK_DISABLED ?= true

.PHONY: up down migrate seed smoke openapi test-backend test-app test-docs test-policy test-guard e2e check update-goldens

up: ## Build the services and start Postgres, Keycloak, migrations and the five services
	cd $(BACKEND) && ./mvnw -B -q -DskipTests package
	$(COMPOSE) up -d postgres keycloak
	@$(MAKE) --no-print-directory migrate
	$(COMPOSE) up -d --build
	@bash $(ROOT)/deploy/smoke.sh
	@echo "Postgres :5432  Keycloak :8180 (admin/admin)  services :8081-:8085"

down: ## Stop and remove the local Compose stack, its volumes and built images
	$(COMPOSE) down -v --rmi local

migrate: ## Apply Flyway migrations to every service database (one-shot containers)
	@bash $(ROOT)/deploy/migrate.sh

seed: ## Load a demo household with two members and sample templates through the public APIs
	@bash $(ROOT)/deploy/seed.sh

smoke: ## Wait for all services to be ready and make one authenticated call
	@bash $(ROOT)/deploy/smoke.sh

openapi: ## Regenerate documentation/api/*-openapi.yaml from the annotated code
	cd $(BACKEND) && ./mvnw -B verify -Dtest=OpenApiContractTest -Dopenapi.update=true -Dsurefire.failIfNoSpecifiedTests=false -Djacoco.skip=true -Denforcer.skip=true

test-backend: ## Spotless, Checkstyle, Quarkus tests and coverage floor (dependency audit: T-0005)
	cd $(BACKEND) && ./mvnw -B verify

test-app: ## Flutter analyze and tests
	cd $(ROOT)/app && dart format --set-exit-if-changed . && flutter analyze && flutter test

update-goldens: ## Regenerate Flutter golden images (Linux)
	cd $(ROOT)/app && flutter test --update-goldens

test-docs: ## Resolve documentation relative links
	@bash $(ROOT)/documentation/tools/check-doc-links.sh

test-policy: ## Dependency policy checks (Phase 0 stub)
	@echo "test-policy: OWASP dependency-check wiring deferred; backend tests still run"

test-guard: ## Generated-client drift guard (Phase 0 stub)
	@echo "test-guard: OpenAPI client guard deferred until client generation is wired"

e2e: ## Full stack e2e (requires emulator; Phase 0 stub)
	@echo "e2e: deferred until Phase 1 journeys exist"
	@exit 1

check: test-docs test-backend ## CI entrypoint (app/e2e when present)
	@if [[ -d $(ROOT)/app ]]; then $(MAKE) test-app; fi
	@echo "check: backend + docs OK (e2e not yet required for Phase 0)"
