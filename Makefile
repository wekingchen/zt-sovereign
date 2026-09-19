SHELL := /bin/bash

.PHONY: init build up down logs ps status verify backup unit-test sync-versions

init:
	./scripts/init.sh

build:
	./scripts/build-local.sh

up:
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f --tail=200

ps:
	docker compose ps

status:
	./scripts/status.sh

verify:
	./scripts/verify.sh

backup:
	./scripts/backup.sh

unit-test:
	./tests/unit/run.sh

sync-versions:
	./scripts/sync-version-files.sh
