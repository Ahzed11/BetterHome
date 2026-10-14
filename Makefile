# BetterHome developer commands. See AGENTS.md §6.1.
SHELL := /bin/bash
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
BACKEND := $(ROOT)/backend
COMPOSE := podman compose -f $(ROOT)/deploy/podman-compose.yml
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

.PHONY: doctor up down migrate seed smoke openapi test-backend test-app test-docs test-policy test-guard e2e check update-goldens

doctor: ## Check the pinned toolchain (JDK, Podman, Flutter, Android) is installed
	@bash $(ROOT)/tooling/doctor.sh

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

test-backend: ## Spotless, Checkstyle, Quarkus tests and coverage floor; SERVICE=tasks-service limits it to one service (dependency audit: T-0005)
	cd $(BACKEND) && ./mvnw -B verify $(if $(SERVICE),-pl services/$(SERVICE) -am)

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

e2e: ## Journeys against the real stack; E2E_TARGET=web (default) or android, E2E_STACK=running to reuse `make up`
	@bash $(ROOT)/tooling/e2e.sh

check: test-docs test-backend ## CI entrypoint (app/e2e when present)
	@if [[ -d $(ROOT)/app ]]; then $(MAKE) test-app; fi
	@echo "check: backend + docs OK (e2e not yet required for Phase 0)"
