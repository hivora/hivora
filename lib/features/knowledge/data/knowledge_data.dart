import 'knowledge_models.dart';

/// Self-contained seed data for the Knowledge Base — a faithful port of the
/// reference `data.js` (users · projects · issues) and `knowledge_data.js`
/// (spaces · article tree · markdown bodies with `{{…}}` smart-link tokens).

const List<KbUser> kSeedUsers = [
  KbUser(id: 'u1', name: 'Rebar Ahmad', title: 'Maintainer', hue: 248),
  KbUser(id: 'u2', name: 'Lena Vogt', title: 'Product Design', hue: 70),
  KbUser(id: 'u3', name: 'Tomáš Horák', title: 'Backend', hue: 250),
  KbUser(id: 'u4', name: 'Amara Okafor', title: 'Frontend', hue: 300),
  KbUser(id: 'u5', name: 'Jonas Brandt', title: 'QA & Release', hue: 155),
  KbUser(id: 'u6', name: 'Mei Lin', title: 'DevOps', hue: 200),
];

const List<KbProject> kSeedProjects = [
  KbProject(id: 'p1', key: 'HIV', name: 'Hivora Core', hue: 70),
  KbProject(id: 'p2', key: 'API', name: 'Server & API', hue: 250),
  KbProject(id: 'p3', key: 'MOB', name: 'Mobile Apps', hue: 300),
  KbProject(id: 'p4', key: 'INF', name: 'Infra & Deploy', hue: 200),
  KbProject(id: 'p5', key: 'DOC', name: 'Docs & Handbook', hue: 155),
];

const List<KbIssue> kSeedIssues = [
  KbIssue(number: 241, projectId: 'p1', title: 'Redesign the agile board with calmer column rhythm', type: 'STORY', priority: 'HIGH', state: 'IN_PROGRESS', assigneeId: 'u2', tags: ['design', 'board']),
  KbIssue(number: 238, projectId: 'p1', title: 'Card drag introduces 120ms jank on large sprints', type: 'BUG', priority: 'URGENT', state: 'IN_PROGRESS', assigneeId: 'u4', tags: ['perf', 'board']),
  KbIssue(number: 230, projectId: 'p2', title: 'Token refresh races on parallel requests', type: 'BUG', priority: 'HIGH', state: 'IN_REVIEW', assigneeId: 'u3', tags: ['auth', 'api']),
  KbIssue(number: 226, projectId: 'p1', title: 'Issue detail: inline edit for estimate & spent', type: 'TASK', priority: 'NORMAL', state: 'TODO', assigneeId: 'u2', tags: ['issues']),
  KbIssue(number: 222, projectId: 'p3', title: 'Adaptive icon clips on Android 13 themed mode', type: 'BUG', priority: 'NORMAL', state: 'TODO', assigneeId: 'u5', tags: ['android', 'branding']),
  KbIssue(number: 219, projectId: 'p2', title: 'GraphQL pagination for the issues feed', type: 'STORY', priority: 'NORMAL', state: 'BACKLOG', assigneeId: 'u6', tags: ['api', 'perf']),
  KbIssue(number: 215, projectId: 'p1', title: 'Keyboard navigation across board columns', type: 'STORY', priority: 'NORMAL', state: 'BACKLOG', assigneeId: 'u4', tags: ['a11y', 'board']),
  KbIssue(number: 212, projectId: 'p4', title: 'Blue-green deploy script for the self-host bundle', type: 'TASK', priority: 'HIGH', state: 'IN_PROGRESS', assigneeId: 'u6', tags: ['infra', 'deploy']),
  KbIssue(number: 208, projectId: 'p1', title: 'Honey-amber accent tokens for status & priority', type: 'TASK', priority: 'NORMAL', state: 'IN_REVIEW', assigneeId: 'u2', tags: ['design', 'tokens']),
  KbIssue(number: 201, projectId: 'p3', title: 'Splash animation parity: iOS CoreAnimation layer', type: 'TASK', priority: 'NORMAL', state: 'DONE', assigneeId: 'u4', tags: ['ios', 'branding']),
  KbIssue(number: 198, projectId: 'p2', title: 'Rate-limit the /meta version-gate endpoint', type: 'TASK', priority: 'LOW', state: 'DONE', assigneeId: 'u3', tags: ['api', 'security']),
  KbIssue(number: 194, projectId: 'p1', title: 'Empty states with subtle honeycomb texture', type: 'TASK', priority: 'LOW', state: 'DONE', assigneeId: 'u2', tags: ['design']),
  KbIssue(number: 190, projectId: 'p5', title: 'Self-hosting guide: reverse proxy + TLS', type: 'STORY', priority: 'NORMAL', state: 'TODO', assigneeId: 'u1', tags: ['docs']),
  KbIssue(number: 187, projectId: 'p1', title: 'Command palette (⌘K) for quick issue jump', type: 'STORY', priority: 'HIGH', state: 'BACKLOG', assigneeId: 'u1', tags: ['ux', 'navigation']),
  KbIssue(number: 181, projectId: 'p4', title: 'Prometheus metrics for issue-service latency', type: 'TASK', priority: 'LOW', state: 'BACKLOG', assigneeId: 'u6', tags: ['infra', 'observability']),
];

const List<KbSpace> kSeedSpaces = [
  KbSpace(id: 'sp_eng', key: 'ENG', name: 'Engineering', hue: 250, icon: 'code-xml', desc: 'Architecture, services, release & on-call runbooks.'),
  KbSpace(id: 'sp_prod', key: 'PRD', name: 'Product', hue: 155, icon: 'compass', desc: 'Specs, workflow rules, decision records.'),
  KbSpace(id: 'sp_design', key: 'DSG', name: 'Design', hue: 300, icon: 'palette', desc: 'Brand, motion and the Hive design system.'),
  KbSpace(id: 'sp_ops', key: 'OPS', name: 'Operations', hue: 200, icon: 'server-cog', desc: 'Self-hosting, infra, backups and TLS.'),
];

// ─────────────────────────── article bodies ───────────────────────────

const String _k1 = r'''Hivora ships as a small set of stateless containers behind a single reverse proxy. This guide gets a production-grade instance running with **Docker Compose** in about fifteen minutes.

:::info
This is the supported path for teams up to ~200 seats. Beyond that, see {{doc:k6}} for the Kubernetes Helm chart.
:::

## Prerequisites

- A Linux host with **4 vCPU / 8 GB RAM** and Docker Engine 24+
- A DNS record pointing at the host (e.g. `hivora.acme.dev`)
- Ports **80** and **443** reachable from the outside

## The compose file

Create a `docker-compose.yml` next to a `.env`:

```yaml
services:
  app:
    image: ghcr.io/hivora/server:1.6
    env_file: .env
    depends_on: [db, cache]
  db:
    image: postgres:16
    volumes: ["pg:/var/lib/postgresql/data"]
  cache:
    image: redis:7
volumes: { pg: {} }
```

## Bring it up

| Step | Command | Notes |
| --- | --- | --- |
| Pull | `docker compose pull` | grabs pinned tags |
| Start | `docker compose up -d` | detached |
| Migrate | `docker compose exec app hivora migrate` | idempotent |

> Once the stack is healthy, finish hardening in {{doc:k5}} — TLS and the reverse proxy are **not** optional in production.

The self-host work is tracked under {{issue:INF-212}}; ping {{user:u6}} if a migration step hangs.

## Next steps

- [x] Containers healthy
- [x] First admin created
- [ ] TLS terminated at the proxy → {{doc:k5}}
- [ ] Nightly backups scheduled → {{doc:k6}}''';

const String _k5 = r'''Hivora speaks plain HTTP inside the compose network; **TLS terminates at the proxy**. We recommend Caddy for its automatic certificate management.

## Caddyfile

```
hivora.acme.dev {
  encode zstd gzip
  reverse_proxy app:8080
}
```

That single block provisions a certificate from Let's Encrypt, renews it, and forwards traffic to the `app` service.

:::warn
If you sit behind a corporate load balancer that already terminates TLS, set `HIVORA_TRUST_PROXY=1` so the original scheme is honoured — otherwise OAuth redirects break.
:::

## Verify

- `curl -I https://hivora.acme.dev` returns `200`
- The padlock shows a valid chain
- HTTP redirects to HTTPS

Parent guide: {{doc:k1}}. Token-refresh edge cases over TLS are covered in {{doc:k9}}.''';

const String _k6 = r'''A backup you have never restored is a rumour. This runbook covers both halves.

## What to back up

1. The **Postgres** volume — the source of truth
2. Uploaded **attachments** (object storage or the `uploads` volume)
3. Your `.env` — secrets, kept out of the repo

## Nightly dump

```bash
docker compose exec -T db \
  pg_dump -U hivora hivora | zstd > backup-$(date +%F).sql.zst
```

Ship the artifact off-box (S3, Backblaze, borg) — same-host backups die with the host.

## Restore drill

> Schedule a restore drill **quarterly**. Owner: {{user:u5}}.

| Phase | Target |
| --- | --- |
| Detect | < 5 min |
| Restore DB | < 30 min |
| Full service | < 1 h |

Related: {{doc:k1}} · release safety in {{doc:k4}}.''';

const String _k9 = r'''Access tokens are short-lived (15 min); refresh tokens rotate on every use. This keeps blast radius small but introduces a **race** when a client fires parallel requests with an expired access token.

## The race

When two requests refresh at once, the second presents an already-rotated refresh token and is rejected — logging the user out. This is the bug behind {{issue:API-230}}.

```
req A ──▶ refresh ──▶ new pair ✅
req B ──▶ refresh ──▶ (stale token) ❌ 401
```

## The fix: single-flight

Collapse concurrent refreshes into one in-flight promise; queued callers await the same result.

```ts
let inflight: Promise<Tokens> | null = null;
function refresh() {
  inflight ??= doRefresh().finally(() => { inflight = null; });
  return inflight;
}
```

:::info
Server-side, allow a **10-second grace window** where the previous refresh token still validates. Belt and braces.
:::

Owner {{user:u3}}. Sign-off gate lives in {{doc:k4}}.''';

const String _k3 = r'''Every issue in Hivora lives in exactly one of five workflow states. This page is the canonical mapping — the board, reports and the API all derive from it.

## The five states

| State | Means | Counts as resolved? |
| --- | --- | --- |
| **Backlog** | Captured, not committed | No |
| **To Do** | Committed to the sprint | No |
| **In Progress** | Actively worked | No |
| **In Review** | Awaiting review/QA | No |
| **Done** | Shipped & verified | **Yes** |

> "Resolved" is **not** a state — it is the *Done* bucket. Reports count an issue as resolved the moment it lands in Done.

## Transitions

```
Backlog → To Do → In Progress → In Review → Done
                      ▲             │
                      └─────────────┘  (review bounce)
```

The calmer board rhythm that surfaces these states is {{issue:HIV-241}}; keyboard moves between columns are {{issue:HIV-215}}.

:::warn
Skipping **In Review** is allowed only for `type: TASK` with `priority: LOW`. Everything else must pass review.
:::

Release gating that depends on this mapping: {{doc:k4}}. Owner: {{user:u1}}.''';

const String _k4 = r'''No release ships without walking this list. It is intentionally boring.

## Pre-flight

- [ ] All sprint issues are **Done** (see {{doc:k3}})
- [ ] `main` is green on CI
- [ ] Version bumped & changelog written
- [ ] The `/meta` version gate is updated → relates to {{issue:API-198}}

## Cut & tag

```bash
hivora release --version 1.6.0 --tag
```

## Gate

| Gate | Owner | Blocking |
| --- | --- | --- |
| Smoke tests | {{user:u5}} | yes |
| Migration rehearsal | {{user:u6}} | yes |
| Design QA | {{user:u2}} | no |

:::info
Hotfixes branch from the release tag, never from `main`. The full procedure is {{doc:k7}}.
:::

Depends on a healthy deploy path: {{doc:k1}}.''';

const String _k7 = r'''A hotfix is a surgical change to a *released* version. Speed matters; discipline matters more.

## Branch

```bash
git checkout -b hotfix/1.6.1 v1.6.0
```

Never branch a hotfix from `main` — you'll drag in unshipped work.

## Steps

1. Reproduce, write a failing test
2. Smallest possible fix
3. Cherry-pick the same commit back to `main`
4. Tag `v1.6.1`, run the {{doc:k4}} gate (smoke + migration only)

> Target: **under two hours** from report to deploy. Escalation owner {{user:u5}}.

Recent example: the token race {{issue:API-230}} shipped this way.''';

const String _k2 = r'''The Hivora mark is a honeycomb cell with a single horizontal bar — a hive, a hub, a connection. This page governs how it moves and breathes.

## The splash

On cold start the hex draws itself, the bar sweeps in, then the workspace fades up.

| Phase | Duration | Curve |
| --- | --- | --- |
| Hex stroke | 480 ms | `ease-out` |
| Bar sweep | 240 ms | spring |
| Workspace fade | 280 ms | `ease` |

:::info
Always honour `prefers-reduced-motion`: cross-fade only, no drawing. Parity work for iOS is {{issue:HIV-201}}.
:::

## Colour

The signature is honey-amber, `oklch(0.74 0.135 70)`. Status and priority hues share the same chroma and lightness — only the hue rotates. The token work landed in {{issue:HIV-208}}.

> Never invent a new accent. Rotate the hue, keep chroma and lightness fixed.

Owner: {{user:u2}}. Empty-state texture rationale: {{issue:HIV-194}}.''';

const String _k8 = r'''Welcome to Hivora engineering. This is your first day, distilled.

## Day one

- [ ] Clone the monorepo, run `make up` (it wraps {{doc:k1}})
- [ ] Get added to the on-call rotation by {{user:u6}}
- [ ] Read the workflow model: {{doc:k3}}
- [ ] Skim the release ritual: {{doc:k4}}

## How we work

We plan in two-week sprints. Issues carry a **type**, **priority** and **state**; the board is the single source of truth. Pick something small and **In Progress** to warm up — {{issue:HIV-226}} is a friendly first task.

:::info
Stuck for more than 30 minutes? Ask. The honeycomb only works because the cells touch.
:::

Auth internals you'll meet early: {{doc:k9}}.''';

final List<KbArticle> kSeedArticles = [
  KbArticle(id: 'k1', spaceId: 'sp_ops', parentId: null, title: 'Self-hosting Hivora with Docker Compose', icon: 'container', authorId: 'u6', contributorIds: const ['u6', 'u3', 'u1'], updated: '2d', created: 'Mar 4', reads: 128, labels: const ['self-host', 'docker'], status: 'published', body: _k1),
  KbArticle(id: 'k5', spaceId: 'sp_ops', parentId: 'k1', title: 'Reverse proxy & TLS', icon: 'lock', authorId: 'u6', contributorIds: const ['u6', 'u3'], updated: '2d', created: 'Mar 5', reads: 74, labels: const ['tls', 'caddy'], status: 'published', body: _k5),
  KbArticle(id: 'k6', spaceId: 'sp_ops', parentId: 'k1', title: 'Backups & restore drills', icon: 'database-backup', authorId: 'u5', contributorIds: const ['u5', 'u6'], updated: '6d', created: 'Mar 8', reads: 61, labels: const ['backup', 'postgres'], status: 'published', body: _k6),
  KbArticle(id: 'k9', spaceId: 'sp_eng', parentId: null, title: 'API authentication & token refresh', icon: 'key-round', authorId: 'u3', contributorIds: const ['u3', 'u6'], updated: '5h', created: 'Apr 1', reads: 142, labels: const ['auth', 'api'], status: 'published', body: _k9),
  KbArticle(id: 'k4', spaceId: 'sp_eng', parentId: null, title: 'Release checklist & version gating', icon: 'rocket', authorId: 'u5', contributorIds: const ['u5', 'u6', 'u2'], updated: '3d', created: 'Feb 18', reads: 96, labels: const ['release', 'ci'], status: 'published', body: _k4),
  KbArticle(id: 'k7', spaceId: 'sp_eng', parentId: 'k4', title: 'Hotfix process', icon: 'flame', authorId: 'u5', contributorIds: const ['u5'], updated: '3d', created: 'Feb 20', reads: 38, labels: const ['hotfix'], status: 'published', body: _k7),
  KbArticle(id: 'k8', spaceId: 'sp_eng', parentId: null, title: 'Engineering onboarding', icon: 'graduation-cap', authorId: 'u1', contributorIds: const ['u1', 'u3'], updated: '1d', created: 'Jan 9', reads: 187, labels: const ['onboarding'], status: 'published', body: _k8),
  KbArticle(id: 'k3', spaceId: 'sp_prod', parentId: null, title: 'Workflow states & resolved mapping', icon: 'git-branch', authorId: 'u1', contributorIds: const ['u1', 'u2'], updated: '1w', created: 'Jan 22', reads: 201, labels: const ['workflow', 'process'], status: 'published', body: _k3),
  KbArticle(id: 'k2', spaceId: 'sp_design', parentId: null, title: 'Brand & splash animation guidelines', icon: 'sparkles', authorId: 'u2', contributorIds: const ['u2'], updated: '4h', created: 'Feb 2', reads: 54, labels: const ['brand', 'motion'], status: 'published', body: _k2),
];
