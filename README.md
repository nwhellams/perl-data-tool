# perl-data-tool

A tiny demo stack:

- **Postgres** stores example customer + payment data (seeded on first run)
- **Perl (DBI)** extracts data and exports it to **Excel (`.xlsx`)**
- **Log::Log4perl** provides app + DB debug logging

---

## Requirements

- Docker + Docker Compose

---

## Quick start

# Makefile

Get started
~~~bash
make up
~~~

Simple export
~~~bash
make export
~~~

Simple export with debug
~~~bash
make export DEBUG=1
~~~

Run tests
~~~bash
make test
~~~

Make help
~~~bash
make
~~~

# Run manually

Start Postgres and the long-running exporter container:

~~~bash
docker compose up -d
~~~

Run an export on demand (exporter container stays up, you exec into it):

~~~bash
docker exec -ti demo_exporter /app/export_data_to_excel.pl --out /app/out/payments.xlsx
~~~

Your file will appear on the host here:

- `./out/payments.xlsx`

---

## Filters

Export only captured payments in a date range:

~~~bash
docker exec -ti demo_exporter /app/export_data_to_excel.pl \
  --out /app/out/captured.xlsx \
  --status captured \
  --from 2025-12-16 \
  --to 2025-12-30
~~~

Flags supported:

- `--out <path>` output filename (inside container, typically `/app/out/...`)
- `--status <value>` e.g. `captured`, `failed`, `refunded`, `authorised`
- `--from YYYY-MM-DD` inclusive
- `--to YYYY-MM-DD` inclusive (implemented as `< to + 1 day`)

---

## Logs

By default the repo writes logs to `./logs/`:

- Main log: `./logs/data-loader.log`
- DB debug log: `./logs/database_debug.log`

---

## Connecting to Postgres (optional)

From your host:

~~~bash
psql "postgresql://demo:demo@127.0.0.1:5432/demo"
~~~

From inside the Postgres container:

~~~bash
docker exec -ti demo_postgres psql -U demo -d demo
~~~

---

## Configuration

Postgres defaults (from `docker-compose.yml`):

- DB: `demo`
- User: `demo`
- Password: `demo`
- Port: `5432`

Exporter uses standard env vars:

- `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD`

Compose sets these so the exporter talks to Postgres over the Docker network.

---

## Project layout

~~~text
conf/        Log4perl configs
logs/        Log output (mounted into exporter)
modules/     Reusable Perl modules (mounted into exporter)
out/         Excel output directory (mounted into exporter)
sql/         Schema + seed SQL (auto-run on first Postgres init)
export_data_to_excel.pl
docker-compose.yml
Dockerfile
cpanfile
Makefile
~~~

---

## Troubleshooting

### Postgres not ready yet
If you export immediately after `docker compose up -d`, Postgres may still be starting. Retry the export

---

## Clean up

Stop containers:

~~~bash
make down
# or
docker compose down
~~~

Remove volumes (wipes Postgres data):

~~~bash
docker compose down -v
~~~

# Further Improvements

This is a simple demo to show potential knowledge and skill. 

The example database is rudimentary. I would look at creating tables for provider and status to cut down on data duplication.

You could also tighten up for a valid status, or dates which make sense rather than fit a reg ex. Also, moving more code to reusable modules (with tests).

The main point of this demo is to show knowledge and approach, not to be a production deployment.