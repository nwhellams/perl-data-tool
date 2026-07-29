# perl-data-tool Makefile
# Examples:
#   make up
#   make export OUT=payments.xlsx
#   make export STATUS=captured FROM=2025-12-16 TO=2025-12-30 OUT=captured.xlsx
#   make test
#   make psql

COMPOSE ?= docker compose
EXPORTER_SERVICE ?= exporter
POSTGRES_SERVICE ?= postgres

OUT ?= payments.xlsx
STATUS ?=
FROM ?=
TO ?=
DEBUG ?=

.PHONY: help up down restart ps logs logs-postgres logs-exporter wait-db export test psql clean-old-files

help:
	@echo "Targets:"
	@echo "  up, down, restart, ps, logs"
	@echo "  export (OUT=, STATUS=, FROM=, TO=, DEBUG=)"
	@echo "  test, psql, clean-old-files"
	@echo ""
	@echo "Examples:"
	@echo "  make export OUT=payments.xlsx"
	@echo "  make export STATUS=captured FROM=2025-12-16 TO=2025-12-30 OUT=captured.xlsx"

up:
	$(COMPOSE) up -d $(POSTGRES_SERVICE)

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) restart

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f

logs-postgres:
	$(COMPOSE) logs -f $(POSTGRES_SERVICE)

logs-exporter:
	tail -f logs/data-loader.log

wait-db:
	@echo "Waiting for Postgres..."
	@until $(COMPOSE) exec -T $(POSTGRES_SERVICE) pg_isready -U demo -d demo >/dev/null 2>&1; do \
		sleep 1; \
	done
	@echo "Postgres is ready."

export: up wait-db
	@echo "Exporting -> ./out/$(OUT)"
	$(COMPOSE) run --rm $(EXPORTER_SERVICE) \
		--out /app/out/$(OUT) \
		$(if $(STATUS),--status $(STATUS),) \
		$(if $(FROM),--from $(FROM),) \
		$(if $(TO),--to $(TO),) \
		$(if $(DEBUG),--debug,)

test: up wait-db
	$(COMPOSE) run --rm --entrypoint prove $(EXPORTER_SERVICE) -lv modules/t

psql: up wait-db
	$(COMPOSE) exec $(POSTGRES_SERVICE) psql -U demo -d demo

clean-old-files:
	rm -f out/*.xlsx
