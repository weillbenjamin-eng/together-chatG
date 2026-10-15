# Together — architecture and Phase 0–1 plan

Repository inspection: empty public repository. Product source of truth: TOGETHER_CODEX_PRODUCT_BRIEF.md v1.0, read in full before implementation.

## Architecture
Next.js App Router, strict TypeScript, Tailwind; Supabase magic-link auth and PostgreSQL. Cookie-based server authentication, Zod validation, RLS and atomic database authorization functions. User accounts are distinct from immutable group-scoped person IDs. Optional contacts use server-side AES-256-GCM and keyed hashes and stay out of directory reads. Ordinary invitations create new account-linked persons and never claim placeholders.

## Implementation map
Phase 0: stack/configuration; environment example; supabase/config.toml, migrations and seed.sql; Vitest, Playwright, database integration tests; CI; loading/error states and setup/deployment documentation.
Phase 1: login/callback/signout, profile, group list/create/detail/rename, owner/member permissions, name-only and optional-contact placeholders, hashed expiring/revocable group invites with atomic throttled redemption, member removal and ownership transfer. src/lib contains validation/auth/database helpers; src/app contains responsive UI/actions. No service-role application requests.

## Validation gates
GitHub Actions runs format, lint, typecheck, unit tests, disposable Supabase reset/migrate/seed, database isolation/integration tests, production build and browser tests. Group creation is atomic with one owner. Outsiders cannot read group data; members cannot gain owner powers; contacts remain private; duplicate names do not merge; invites do not claim placeholders; revocation and removal take effect immediately. Test three name-only placeholders and reload persistence.

No local application checkout. No production deployment or external secrets assumed. Stop after Phase 1 for review. Events, tasks, claims, expenses and photos and their seed fixtures remain deferred.
