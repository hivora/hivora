# Fastlane — iOS & macOS release automation

Signing and store delivery for the Apple apps are fully automated with
[fastlane](https://fastlane.tools) + [match](https://docs.fastlane.tools/actions/match/).
Android already has its own lanes and is intentionally left untouched here.

- **Auth:** an App Store Connect **API key** (no Apple ID, no 2FA).
- **Signing assets:** certificates + provisioning profiles live in the private
  match repo **`hinata-platform/hinata-certificates`** (encrypted), shared by iOS
  and macOS (profiles are namespaced by platform).
- **Build numbers:** derived automatically from the latest TestFlight build.

Bundle id for both platforms: **`com.ahmadre.hinata`**.

```
ios/fastlane/   → platform :ios   (lanes: bootstrap · signing · build · beta · release)
macos/fastlane/ → platform :mac   (same lanes, Mac App Store .pkg)
```

## One-time prerequisites

1. **Apple Developer Program** membership (the team that owns the bundle id).
2. **App Store Connect API key** (Users & Access → Integrations → App Store Connect API,
   role *App Manager* or *Admin*). You get a Key ID, an Issuer ID and a `.p8` file.
3. **Certificates repo:** create the **private** GitHub repo
   `hinata-platform/hinata-certificates` (empty). match populates it on first run.
4. **Ruby 3.x + Bundler** (the system Ruby 2.6 is too old). e.g. `brew install ruby`
   or `rbenv install 3.3`, then `gem install bundler`.

Install the tooling per platform:

```bash
cd ios   && bundle install
cd macos && bundle install
```

## Environment variables / CI secrets

Set these locally (e.g. an un-committed `ios/.env.fastlane`, auto-loaded by fastlane)
and as GitHub Actions **secrets** for the release workflow:

| Variable | What |
| --- | --- |
| `APP_STORE_CONNECT_API_KEY_ID` | API Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | API Issuer ID |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | the `.p8` contents, **base64-encoded** (`base64 -i AuthKey_XXXX.p8`) |
| `MATCH_GIT_URL` | `https://github.com/hinata-platform/hinata-certificates` (optional — it's the default) |
| `MATCH_PASSWORD` | passphrase that encrypts the match repo |
| `MATCH_GIT_BASIC_AUTHORIZATION` | base64 of `user:personal-access-token` for cloning the private repo on CI |
| `FASTLANE_TEAM_ID` / `FASTLANE_ITC_TEAM_ID` | optional — only if your key spans multiple teams |

## Bootstrap (run once, on a maintainer's Mac)

This registers the App ID in the Developer Portal + App Store Connect and creates
the development & distribution certs/profiles, pushing them (encrypted) to the
match repo. **Only this step writes** — CI is always read-only.

```bash
cd ios   && bundle exec fastlane ios bootstrap
cd macos && bundle exec fastlane mac bootstrap
```

> If the certs already exist for the team, match reuses them. Distribution certs
> are limited (2–3 per type) per account — match shares one across the team, which
> is the whole point of the shared repo.

## Day-to-day lanes

| Command | Result |
| --- | --- |
| `fastlane ios signing` / `fastlane mac signing` | fetch certs/profiles into the keychain (read-only) |
| `fastlane ios beta` / `fastlane mac beta` | build a signed artifact and upload to **TestFlight** |
| `fastlane ios release` / `fastlane mac release` | build and submit to the **App Store** (not auto-published) |

Run from the matching platform directory (`cd ios` / `cd macos`).

## CI

`.github/workflows/release.yml` runs on `v*` tags: it builds & ships **iOS** and
**macOS** to TestFlight via `fastlane beta` (Android keeps its existing job). Add
the secrets above to the repo before tagging a release. The store submission
(`release` lane) is run manually when you're ready to ship.

## Notes

- The macOS app is sandboxed; `com.apple.security.network.client` was added to the
  entitlements so the release build can reach the API. Review the sandbox
  entitlements before submitting (e.g. add file/attachment scopes if needed).
- `flutter build ipa`/`build macos` run pod install and bake the resolved build
  number in; gym then archives, signs and exports using the match profile
  `match AppStore com.ahmadre.hinata`.
- Secrets (`*.p8`, `*.p12`, `*.mobileprovision`, …) are git-ignored. Never commit them.
