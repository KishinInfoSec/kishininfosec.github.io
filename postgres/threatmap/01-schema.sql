-- Threat-map schema. Runs once, on first init of an empty threatmap_postgres volume.
-- Writers: n8n workflows in automations/n8n/threatmap-feeds.

-- Attack arcs from Fortinet's outbreak threat map. No IPs, only city-level geo.
create table attack_events (
    event_key     text primary key,          -- md5 of the raw event; dedupes overlapping polls
    source        text not null,             -- 'fortinet'
    event_at      timestamptz not null,
    kind          text,                      -- ips | virus
    signature     text,
    category      text,
    severity      text,
    outbreak_id   text,
    outbreak_tags text[],
    src_country   text,
    src_city      text,
    src_lat       double precision,
    src_lon       double precision,
    dst_country   text,
    dst_city      text,
    dst_lat       double precision,
    dst_lon       double precision,
    hits          integer not null default 1,
    raw           jsonb not null,
    ingested_at   timestamptz not null default now()
);
create index attack_events_event_at on attack_events (event_at);

-- One row per IP per feed per day it was listed.
create table ip_sightings (
    source           text not null,          -- dshield | feodo | blocklistde | abuseipdb | otx
    ip               inet not null,
    seen_on          date not null default current_date,
    details          jsonb not null default '{}',
    first_ingested_at timestamptz not null default now(),
    last_ingested_at  timestamptz not null default now(),
    primary key (source, ip, seen_on)
);
create index ip_sightings_ip on ip_sightings (ip);
create index ip_sightings_seen_on on ip_sightings (seen_on);

-- Cached lookups, one row per IP per provider. expires_at drives re-lookup.
create table enrichment (
    ip         inet not null,
    provider   text not null,                -- ipapi | internetdb | greynoise | abuseipdb | otx
    status     text not null,                -- ok | not_found
    data       jsonb not null,
    fetched_at timestamptz not null default now(),
    expires_at timestamptz not null,
    primary key (ip, provider)
);
create index enrichment_provider_expires on enrichment (provider, expires_at);

-- One row per IP: feeds it appeared in plus whatever enrichment exists.
create or replace view ip_profile as
select s.ip,
       min(s.seen_on)                         as first_seen,
       max(s.seen_on)                         as last_seen,
       array_agg(distinct s.source)           as sources,
       geo.data ->> 'countryCode'             as country,
       geo.data ->> 'city'                    as city,
       (geo.data ->> 'lat')::double precision as lat,
       (geo.data ->> 'lon')::double precision as lon,
       geo.data ->> 'as'                      as asn,
       idb.data -> 'ports'                    as ports,
       idb.data -> 'vulns'                    as vulns,
       idb.data -> 'tags'                     as tags,
       gn.data ->> 'classification'           as greynoise_class,
       (ab.data ->> 'abuseConfidenceScore')::int as abuse_score,
       (ab.data ->> 'totalReports')::int      as abuse_reports,
       (otx.data ->> 'pulse_count')::int      as otx_pulses
from ip_sightings s
left join enrichment geo on geo.ip = s.ip and geo.provider = 'ipapi'
left join enrichment idb on idb.ip = s.ip and idb.provider = 'internetdb'
left join enrichment gn  on gn.ip  = s.ip and gn.provider  = 'greynoise'
left join enrichment ab  on ab.ip  = s.ip and ab.provider  = 'abuseipdb'
left join enrichment otx on otx.ip = s.ip and otx.provider = 'otx'
group by s.ip, geo.data, idb.data, gn.data, ab.data, otx.data;

-- Is data still arriving? One row per source.
create view ingest_health as
select 'fortinet' as source, max(ingested_at) as last_ingested,
       count(*) filter (where ingested_at > now() - interval '1 hour') as rows_last_hour,
       count(*) as rows_total
from attack_events
union all
select source, max(last_ingested_at),
       count(*) filter (where last_ingested_at > now() - interval '1 hour'),
       count(*)
from ip_sightings group by source
union all
select 'enrich:' || provider, max(fetched_at),
       count(*) filter (where fetched_at > now() - interval '1 hour'),
       count(*)
from enrichment group by provider;
