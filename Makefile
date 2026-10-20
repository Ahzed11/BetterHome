# BetterHome developer commands. See AGENTS.md §6.1.
SHELL := /bin/bash
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
BACKEND := $(ROOT)/backend
# The stack's identity (project name, host ports) comes from the slot in tooling/stack-env.sh, so several
# stacks can run side by side (E2E_SLOT=1 make up); exported here for Compose and the deploy scripts.
$(foreach kv,$(shell bash -c '. $(ROOT)/tooling/stack-env.sh && for v in $$STACK_VARS; do echo "$$v:=$${!v}"; done'),$(eval export $(kv)))
COMPOSE := podman compose -p $(COMPOSE_PROJECT_NAME) -f $(ROOT)/deploy/podman-compose.yml
# Tool locations match tooling/dev-env.sh (installed by tooling/install-dev-tools.sh)
DEV_TOOLS_DIR ?= $(HOME)/dev-tools
export ANDROID_SDK_ROOT ?= $(HOME)/Android/Sdk
export PATH := $(HOME)/.jbang/bin:$(DEV_TOOLS_DIR)/flutter/bin:$(ANDROID_SDK_ROOT)/cmdline-tools/latest/bin:$(ANDROID_SDK_ROOT)/platform-tools:$(ANDROID_SDK_ROOT)/emulator:$(PATH)
JAVA_HOME ?= $(shell jbang jdk home 21 2>/dev/null)
export JAVA_HOME
export PATH := $(JAVA_HOME)/bin:$(PATH)
# Quarkus Dev Services / Testcontainers against rootless Podman
export DOCKER_HOST ?= unix://$(XDG_RUNTIME_DIR)/podman/podman.sock
export TESTCONTAINERS_RYUK_DISABLED ?= true

.PHONY: mutation client doctor up down migrate seed smoke openapi test-backend test-app test-docs test-policy test-guard e2e check update-goldens run-app

doctor: ## Check the pinned toolchain (JDK, Podman, Flutter, Android) is installed
	@bash $(ROOT)/tooling/doctor.sh

up: ## (E2E_SLOT=n: another stack beside this one) Build the services and start Postgres, Keycloak, migrations and the five services (SKIP_PACKAGE=1: jars already built)
	$(if $(SKIP_PACKAGE),@echo "up: using the jars already built",cd $(BACKEND) && ./mvnw -B -q -DskipTests package)
	@bash $(ROOT)/deploy/render-realm.sh
	$(COMPOSE) up -d postgres keycloak
	@$(MAKE) --no-print-directory migrate
	$(COMPOSE) up -d --build
	@bash $(ROOT)/deploy/smoke.sh
	@echo "Stack $(COMPOSE_PROJECT_NAME): Postgres :$(POSTGRES_PORT)  Keycloak :$(KEYCLOAK_PORT) (admin/admin)  services :$(HOUSEHOLDS_PORT) $(TASKS_PORT) $(SCORING_PORT) $(LISTS_PORT) $(NOTIFICATIONS_PORT)"

down: ## Stop and remove the local Compose stack, its volumes and built images
	$(COMPOSE) down -v --rmi local
	rm -rf $(STACK_DIR)

migrate: ## Apply Flyway migrations to every service database (one-shot containers)
	@bash $(ROOT)/deploy/migrate.sh

seed: ## Load a demo household with two members and sample templates through the public APIs
	@bash $(ROOT)/deploy/seed.sh

smoke: ## Wait for all services to be ready and make one authenticated call
	@bash $(ROOT)/deploy/smoke.sh

openapi: ## Regenerate documentation/api/*-openapi.yaml from the annotated code, then openapi.yaml from those
	cd $(BACKEND) && ./mvnw -B verify -Dtest=OpenApiContractTest -Dopenapi.update=true -Dsurefire.failIfNoSpecifiedTests=false -Djacoco.skip=true -Denforcer.skip=true
	cd $(BACKEND) && ./mvnw -B verify -pl common-domain -Dtest=OpenApiAggregateTest -Dopenapi.update=true -Djacoco.skip=true -Denforcer.skip=true

test-backend: ## Spotless, Checkstyle, Quarkus tests and coverage floor; SERVICE=tasks-service limits it to one service (dependency audit: T-0005)
	cd $(BACKEND) && ./mvnw -B verify $(if $(SERVICE),-pl services/$(SERVICE) -am)

client: ## Generate the Dart client from documentation/api/openapi.yaml into generated/ (gitignored)
	@bash $(ROOT)/tooling/generate-client.sh

mutation: ## Mutation testing (Pitest) of the pure domain code of tasks and scoring; HTML reports in backend/services/*/target/pit-reports
	cd $(BACKEND) && ./mvnw -B test-compile org.pitest:pitest-maven:mutationCoverage -Ppitest -pl services/tasks-service,services/scoring-service -am -Djacoco.skip=true -Denforcer.skip=true

test-app: client ## Flutter analyze and tests
	cd $(ROOT)/app && flutter pub get && dart format --set-exit-if-changed . && flutter analyze && flutter test

update-goldens: ## Regenerate Flutter golden images (Linux)
	cd $(ROOT)/app && flutter test --update-goldens

test-docs: ## Resolve documentation relative links
	@bash $(ROOT)/documentation/tools/check-doc-links.sh

test-policy: ## Dependency policy checks (Phase 0 stub)
	@echo "test-policy: OWASP dependency-check wiring deferred; backend tests still run"

test-guard: ## Prove the generated client breaks on a broken document or a drifted contract
	@bash $(ROOT)/tooling/test-guard.sh

e2e: client ## Journeys against the real stack; E2E_TARGET=web (default) or android, E2E_STACK=running to reuse `make up`
	@bash $(ROOT)/tooling/e2e.sh

run-app: ## Try the app by hand: stack, demo users, web app on http://localhost:8090 (alice / demo; RUN_APP_SEED=1 adds the demo household)
	@bash $(ROOT)/tooling/run-app.sh

check: test-docs test-backend ## CI entrypoint (app/e2e when present)
	@if [[ -d $(ROOT)/app ]]; then $(MAKE) test-app test-guard; fi
	@echo "check: backend + docs OK (e2e not yet required for Phase 0)"
