# Security notes

The database migration uses owner-scoped RLS for every client-facing table and user-ID-prefixed storage paths. Public share links are random, expire after seven days, are checked server-side, and produce one-minute signed downloads. Server keys never enter browser code. Atlas blocks DDL, DML, extension loading, attachment, copying, and stacked statements in its user and pipeline consoles. These controls are prototype guardrails, not a penetration test.
