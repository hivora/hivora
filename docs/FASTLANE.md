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

## Status — bootstrap is DONE ✅

The signing assets already exist (encrypted) in the **`master`** branch of
`hinata-platform/hinata-certificates`, for both platforms:

| Type | Cert | Used by |
| --- | --- | --- |
| Apple Development | `VTSTMPDT39` | iOS + macOS dev profiles |
| Apple Distribution | `79XK58YXLP` | iOS + macOS App Store |
| Mac Installer Distribution | `DJRG643AG5` | signs the macOS `.pkg` |

You don't need to bootstrap again. Day-to-day, just run the `beta`/`release`
lanes — they fetch these read-only.

## One-time prerequisites

1. **Apple Developer Program** membership (team that owns `com.ahmadre.hinata`).
2. **App Store Connect API key** — already created: Key ID `8KTB2B9CUP`, the `.p8`
   lives at `ios/AuthKey_8KTB2B9CUP.p8` (git-ignored).
3. **Certificates repo** `hinata-platform/hinata-certificates` (private) — exists & populated.
4. **fastlane** — installed via Homebrew (`brew install fastlane`, bundles its own
   Ruby). Run lanes directly (`fastlane …`); `bundle exec` only if you `bundle install`.
5. **Xcode selected:** `sudo xcode-select -s /Applications/Xcode.app` (or export
   `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`) — match/gym need full Xcode.
6. **git identity** (match commits to the repo): `git config --global user.name "…"`
   and `git config --global user.email "…"`.

## Environment variables

**Local** — already wired in the git-ignored `ios/fastlane/.env` and
`macos/fastlane/.env` (auto-loaded by fastlane): the API key id/issuer, the path
to the `.p8` (`HINATA_ASC_KEY_PATH`) and the `MATCH_PASSWORD`. Nothing to do.

**CI** — add these as GitHub Actions **secrets** before tagging a release:

| Secret | What |
| --- | --- |
| `APP_STORE_CONNECT_API_KEY_ID` | `8KTB2B9CUP` |
| `APP_STORE_CONNECT_ISSUER_ID` | `230ae00d-8f11-4f3a-bdd5-5216ce492386` |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | the `.p8` contents, **base64** (`base64 -i ios/AuthKey_8KTB2B9CUP.p8`) |
| `MATCH_PASSWORD` | the passphrase that encrypts the match repo (in your `.env`; store it in a password manager too) |
| `MATCH_GIT_BASIC_AUTHORIZATION` | base64 of `user:personal-access-token` so CI can clone the private repo |
| `MATCH_GIT_URL` | optional — defaults to the certificates repo |

> ⚠️ **Keep the `MATCH_PASSWORD` safe.** Without it the encrypted repo — and every
> cert/profile in it — is unrecoverable. It's currently stored only in your local
> `.env` files.

## Re-bootstrap (only if you ever need to recreate signing assets)

Already done. You'd only re-run this to recreate certs (e.g. after a `match nuke`):

```bash
cd ios   && fastlane ios bootstrap
cd macos && fastlane mac bootstrap
```

> Distribution / development certs are limited (~2–3 per type per account) — match
> shares one across the team via the repo, which is the whole point. Don't create
> certs outside match or you'll exhaust the quota.

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
- `flutter build ios/macos` runs pod install and bakes the resolved build number
  in; gym then archives, signs and exports using the exact profile match
  installed (the build lanes read `MATCH_PROVISIONING_PROFILE_MAPPING`, so any
  profile-name suffix is handled automatically).
- The match repo uses the **`master`** branch (the repo's default branch `main`
  only holds the LICENSE). match always uses `master`, so this is fine.
- A couple of orphaned iOS profiles (`match … com.ahmadre.hinata` without a
  suffix) may linger on the portal from the initial bootstrap; they reference
  revoked certs and are harmless — delete them in the Developer Portal if you like.
- Secrets (`*.p8`, `*.p12`, `*.mobileprovision`, …) are git-ignored. Never commit them.
