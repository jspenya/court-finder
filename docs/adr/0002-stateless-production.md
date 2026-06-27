# Stateless production on OCI

Court Finder v1 has no domain database — venues live in `config/venues.yml` and availability checks are live HTTP pulls per search. Production runs with in-memory cache, the async Active Job adapter, and the async Action Cable adapter instead of Rails 8's default `solid_*` SQLite backends. That keeps the OCI Always Free deploy simple: one container on the shared Kamal proxy VM, no persistent volume, no `db:prepare` on boot. The trade-off is nothing survives restarts (cache, in-flight jobs), which is acceptable for v1 because the app has no accounts, no background work, and no cable broadcasts.

**Considered options:** Keep `solid_*` with a Kamal storage volume (rejected — unnecessary persistence for v1), managed Postgres (rejected — cost and scope).

**Consequences:** If v1 later needs durable cache, scheduled jobs, or cable broadcasts, revisit this ADR and add storage or a managed service.
