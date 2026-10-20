#!/bin/sh
# Read-only login for Grafana. Runs once, on first init of an empty volume, and
# only if the grafana_ro_password secret is mounted.
set -e
f=/run/secrets/grafana_ro_password
[ -s "$f" ] || { echo "02-grafana-ro: $f missing, skipping"; exit 0; }
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v pw="$(cat "$f")" <<'SQL'
create role grafana_ro login password :'pw';
alter role grafana_ro set statement_timeout = '30s';
alter role grafana_ro set default_transaction_read_only = on;
grant connect on database threatmap to grafana_ro;
grant usage on schema public to grafana_ro;
grant select on all tables in schema public to grafana_ro;
alter default privileges for role threatmap in schema public grant select on tables to grafana_ro;
SQL
