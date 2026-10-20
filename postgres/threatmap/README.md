---
layout: template
title: Threat map database
kind: postgres
summary: Schema for the threat map feeds and dashboards, plus a read-only role for Grafana.
tags: [threat-intel, postgres]
tested: PostgreSQL 18
permalink: /postgres/threatmap/
---

# Threat map database

The schema used by the [threat map feeds](../../n8n/threatmap-feeds) and [dashboards](../../grafana/threatmap).

- `01-schema.sql` creates the tables (`attack_events`, `ip_sightings`, `enrichment`) and the `ingest_health` and `ip_profile` views.
- `02-grafana-ro.sh` creates a `grafana_ro` login with read-only access. It runs only if a password is mounted at `/run/secrets/grafana_ro_password`.

## Setup

Run Postgres with `POSTGRES_DB=threatmap` and `POSTGRES_USER=threatmap`, and mount this folder at `/docker-entrypoint-initdb.d/`. Both scripts run once, on first init of an empty volume.
