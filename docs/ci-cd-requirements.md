# CI/CD Requirements — Godot iOS Export

This document describes the environment, secrets, and configuration required to
run the GitHub Actions iOS build pipeline defined in
`.github/workflows/ios-export.yml`.

---

## 1. macOS Runner Requirements

| Requirement | Value | Notes |
|---|---|---|
| **Runner image** | `macos-14` (Apple Silicon) | Use `macos-13` for Intel x86_64 |
| **Xcode** | ≥ 15.x (latest-stable) | Pinned via `maxim-lobanov/setup-xcode` action |
| **Ruby** | 3.3.x | Managed by `ruby/setup-ruby` action |
| **Bundler** | bundled with Ruby | `bundler-cache: true` caches gems |
| **Godot** | 4.3-stable binary + export templates | Downloaded & cached by workflow |
| **Git LFS** | Optional | Enable in workflow if assets use LFS |

### Why macOS?

iOS IPA signing requires `codesign` and `xcodebuild`, which are only available
on macOS. Linux runners cannot produce a signed iOS build. The Godot headless
validation step runs on `ubuntu-latest` to keep cost low; the full iOS export
runs on `macos-14`.

### Runner Cost Notes

GitHub-hosted macOS runners are ~10× more expensive per minute than Linux.
- **Validation job** (`ubuntu-latest`): cheap, fast (~3–5 min)
- **iOS build job** (`macos-14`): ~20–40 min per build
- Cache Godot binary and export templates to reduce download time (~350 MB saved per build)

---

## 2. Required GitHub Actions Secrets

Set these in **Settings → Secrets and variables → Actions** for the repository.

### App Store Connect API Key

| Secret | Description |
|---|---|
| `APP_STORE_CONNECT_API_KEY_ID` | Key ID (10-char string from App Store Connect) |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer UUID from App Store Connect → Keys page |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | Full content of the `.p8` private key file |

**How to create:** App Store Connect → Users & Access → Integrations → App Store Connect API → Generate key with **Developer** role minimum (Admin preferred for full automation).

### match (Code Signing)

| Secret | Description |
|---|---|
| `MATCH_GIT_URL` | HTTPS URL of the private git repo storing encrypted certs (e.g. `https://github.com/org/match-repo.git`) |
| `MATCH_PASSWORD` | Passphrase used to encrypt/decrypt certs in the match repo |
| `MATCH_GIT_BASIC_AUTHORIZATION` | Base64-encoded `username:personal_access_token` for match git repo auth |

**How to create the match repo:**
```bash
# One-time local setup (developer machine, not CI)
cd /path/to/your/app
bundle exec fastlane match init   # sets MATCH_GIT_URL
bundle exec fastlane match appstore  # run WITHOUT --readonly to generate first time
```

### App Identity

| Secret / Variable | Description |
|---|---|
| `APP_IDENTIFIER` | Bundle ID, e.g. `com.yourcompany.yourgame` — can be a variable |
| `APPLE_TEAM_ID` | 10-character Developer Portal team ID |
| `ITC_TEAM_ID` | Numeric App Store Connect team ID (only needed for multiple teams) |

---

## 3. Godot Export Preset Configuration

The workflow expects `export_presets.cfg` to exist in the Godot project root
with an iOS preset named **"iOS"**.

Minimum required preset fields (`export_presets.cfg`):

```ini
[preset.0]
name="iOS"
platform="iOS"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="build/ios/game.xcodeproj"

[preset.0.options]
custom_template/debug=""
custom_template/release=""
architectures/arm64=true
```

**Key fields to set in Godot Editor before committing:**
- Bundle Identifier → must match `APP_IDENTIFIER` secret
- App Version and Build Number (build number is overridden by Fastlane in CI)
- Required icons (all sizes): Godot will error on export if missing

---

## 4. Fastlane Setup Checklist (First Time)

Run these steps once from a developer machine before the first CI run:

```bash
# 1. Install dependencies
cd fastlane
bundle install

# 2. Create a new App in App Store Connect (if not done already)
#    https://appstoreconnect.apple.com/apps

# 3. Set up match repo — creates & encrypts first certificates
MATCH_GIT_URL=https://github.com/org/match-repo.git \
MATCH_PASSWORD=your-strong-passphrase \
APP_IDENTIFIER=com.yourcompany.yourgame \
APPLE_TEAM_ID=XXXXXXXXXX \
  bundle exec fastlane match appstore

# 4. Verify match read-only works (simulates CI)
bundle exec fastlane match appstore --readonly
```

---

## 5. Testing the Pipeline with an Empty Godot Project

To validate the pipeline end-to-end before integrating real game content:

```bash
# 1. Create a minimal Godot 4 project
mkdir empty-godot-test && cd empty-godot-test
# Open Godot Editor → New Project → Create

# 2. Add the iOS export preset in Godot Editor
#    Project → Export → Add → iOS
#    Set bundle ID, team, icons

# 3. Export manually first to verify templates work
godot --headless --export-release "iOS" "build/ios/game.xcodeproj"

# 4. Confirm .xcodeproj is generated
ls -la build/ios/

# 5. Push to a branch and observe the GitHub Actions run
git add . && git commit -m "test: empty godot project for CI validation"
git push origin feature/ci-test
```

Expected outcomes:
- `validate` job: green in ~5 min (Linux, project import only)
- `ios-export` job: green in ~25-35 min (macOS, full Xcode build)
- IPA artifact uploaded and visible in Actions run summary
- If on `main` or `release/**`: build appears in TestFlight within ~30 min

---

## 6. Dependency & Version Pinning

| Tool | Version Strategy |
|---|---|
| Godot | Pinned via `GODOT_VERSION` env var in workflow |
| Xcode | Latest-stable via `setup-xcode` action |
| Ruby | `3.3` via `setup-ruby` |
| Fastlane | Latest via `Gemfile`; pin with `gem "fastlane", "~> 2.x"` for stability |
| GitHub Actions | All action versions pinned with `@v4` tags |

**Recommendation:** Lock Fastlane to a minor version (`~> 2.220`) once the first
successful build is confirmed to prevent unexpected breakage from upstream releases.

---

## 7. Failure & Recovery

| Failure | Likely Cause | Fix |
|---|---|---|
| Godot export exits non-zero | Missing export preset, missing icons, wrong Godot version | Check `godot-export.log` artifact |
| `match` fails with 401 | `MATCH_GIT_BASIC_AUTHORIZATION` expired or wrong | Regenerate PAT, re-encode base64, update secret |
| `gym` fails: "No signing certificate" | match did not install cert to keychain | Check Matchfile `keychain_name` / run `match appstore` locally |
| `pilot` fails: "app not found" | App not created in ASC, or wrong bundle ID | Create app in ASC, verify `APP_IDENTIFIER` |
| Build number conflict | Existing build with same number in TestFlight | `GITHUB_RUN_NUMBER` should be monotonically increasing; ensure no manual uploads |
