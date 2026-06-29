# Twenty CRM — Post-Setup Configuration

Settings that must be configured via the admin panel (not available as env vars).

Access: **https://crm.home.lan** (LAN, no Authelia required after Caddy bypass)

## Settings

### 1. Time Format → 24h

**Path:** Settings → Profile

Set time format to **24-hour**. Stored as `WorkspaceMemberTimeFormatEnum.HOUR_24` in the database. Per-user preference.

### 2. Soft Delete Retention → 365 days

**Path:** Settings → Workspace → Data

Set soft delete records retention to **365 days**. Workspace-level setting stored in PostgreSQL.

### 3. Approved Domain → larsartmann.cloud

**Path:** Settings → Domains → Add approved domain

Add `larsartmann.cloud` as an approved access domain. This allows users with `@larsartmann.cloud` email addresses to automatically join the workspace.

## Why Not Env Vars?

Twenty uses `IS_CONFIG_VARIABLES_IN_DB_ENABLED=true` by default. Runtime settings (time format, soft delete, domains) live in PostgreSQL, not in environment variables. These settings persist in the database and survive container restarts — only need to be configured once.
