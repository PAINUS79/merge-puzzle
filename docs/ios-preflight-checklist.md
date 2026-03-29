# iOS Export Pre-flight Checklist

**Purpose:** Everything the board must provide to activate the iOS build pipeline.  
**Blocks:** [CRI-23](/CRI/issues/CRI-23) — Test iOS export pipeline with Merge Grove vertical slice.

All configuration files are pre-staged in this repo. The CI workflow will
skip the iOS export job automatically until these secrets and resources are in
place (see `.github/workflows/ios-export.yml` -> `check-signing-secrets` job).

---

## Status

| Item | Status | Owner |
|---|---|---|
| Apple Developer account | Pending | Board |
| App created in App Store Connect | Pending | Board |
| App Store Connect API key | Pending | Board |
| match private repo created | Pending | Board |
| Certs generated & pushed to match repo | Pending | Board |
| GitHub Actions secrets set | Pending | Board |
| Bundle ID updated in export_presets.cfg | Pending | Board/Dev |
| App icons added | Pending | Board/Dev |
| macOS GitHub Actions runner | Confirmed (GitHub-hosted macos-14) | — |

---

## Step 1 — Apple Developer Account

- [ ] Sign in to or create account at https://developer.apple.com
- [ ] Ensure membership is **Apple Developer Program** ($99/yr), not free tier
- [ ] Note your **10-character Team ID** from Certificates, IDs & Profiles -> Membership

---

## Step 2 — Create the App in App Store Connect

- [ ] Go to https://appstoreconnect.apple.com -> My Apps -> (+) New App
- [ ] Platform: **iOS**
- [ ] Bundle ID: choose your reverse-domain bundle ID (e.g., `com.yourcompany.mergepuzzle`)
  - Must be unique across the App Store
  - **Update `export_presets.cfg` line `application/bundle_identifier=` to match**
- [ ] SKU: any internal identifier (e.g., `merge-puzzle-001`)
- [ ] Note the **numeric App Store Connect Team ID**

---

## Step 3 — App Store Connect API Key

The workflow uses an API key (not a username/password) for all ASC interactions.

- [ ] Go to App Store Connect -> Users & Access -> Integrations -> App Store Connect API
- [ ] Click (+) to generate a new key
  - Name: `merge-puzzle-ci`
  - Role: **Admin** (or Developer at minimum)
- [ ] Download the `.p8` file — **you can only download it once**
- [ ] Note the **Key ID** (10-character string) and **Issuer ID** (UUID)

---

## Step 4 — match Private Repository

`match` stores encrypted certificates and profiles in a private git repo.

- [ ] Create a **new private GitHub repo** (e.g., `merge-puzzle-match`)
- [ ] Generate a **GitHub Personal Access Token (PAT)** with `repo` scope for CI access
- [ ] Run match locally **once** to generate and push the first certificates:

```bash
cd fastlane
bundle install

export MATCH_GIT_URL="https://github.com/YOURORG/merge-puzzle-match.git"
export MATCH_PASSWORD="your-strong-passphrase"
export APP_IDENTIFIER="com.yourcompany.mergepuzzle"
export APPLE_TEAM_ID="XXXXXXXXXX"

bundle exec fastlane match appstore   # --readonly NOT set here (first-time generation)
```

- [ ] Verify the match repo now has encrypted cert files committed

---

## Step 5 — GitHub Actions Secrets

Add these in **Settings -> Secrets and variables -> Actions** on the `PAINUS79/merge-puzzle` repo.

### Required — unlocks the iOS export job

| Secret Name | Where to find it |
|---|---|
| `APP_STORE_CONNECT_API_KEY_ID` | ASC -> API Keys page (10-char Key ID) |
| `APP_STORE_CONNECT_ISSUER_ID` | ASC -> API Keys page (UUID) |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | Contents of the downloaded `.p8` file |
| `MATCH_GIT_URL` | URL of your match private repo |
| `MATCH_PASSWORD` | Passphrase used when running match |
| `MATCH_GIT_BASIC_AUTHORIZATION` | `base64("github-username:PAT")` — see below |
| `APP_IDENTIFIER` | Bundle ID from Step 2 |
| `APPLE_TEAM_ID` | 10-char Developer Portal Team ID |

**How to generate `MATCH_GIT_BASIC_AUTHORIZATION`:**
```bash
echo -n "github-username:your-personal-access-token" | base64
```

### Optional

| Secret Name | Used for |
|---|---|
| `ITC_TEAM_ID` | App Store Connect team (numeric) — only for multiple ASC teams |
| `KEYCHAIN_PASSWORD` | CI keychain password — defaults to `ci-keychain` if not set |

---

## Step 6 — Bundle ID and Icons in the Repo

- [ ] Update `export_presets.cfg`:
  - `application/bundle_identifier` -> your actual bundle ID from Step 2
- [ ] Add app icons (required — Godot will fail export without them):
  - Create `res://icons/` directory in the project
  - Required PNG sizes: 1024, 180, 120 (iPhone), 167, 152, 76 (iPad), 80, 40 (Spotlight)
  - Update the `icons/` entries in `export_presets.cfg` to point to these files

---

## Step 7 — Verify and Trigger

Once all secrets are set:

- [ ] Push any small change to `main` or open a PR
- [ ] In the GitHub Actions tab, confirm **`check-signing-secrets`** outputs `has_secrets=true`
- [ ] Confirm **`ios-export`** job starts (not skipped)
- [ ] Review the `godot-export.log` artifact if the build fails
- [ ] On success, verify the IPA artifact is uploaded
- [ ] If on `main` or `release/**`, check that TestFlight received the build (~30 min processing)

---

## Minimum Set to Unblock CRI-23

1. `APP_STORE_CONNECT_API_KEY_ID`
2. `APP_STORE_CONNECT_ISSUER_ID`
3. `APP_STORE_CONNECT_API_KEY_CONTENT`
4. `MATCH_GIT_URL`
5. `MATCH_PASSWORD`
6. `MATCH_GIT_BASIC_AUTHORIZATION`
7. `APP_IDENTIFIER`
8. `APPLE_TEAM_ID`

Once these are set, the workflow activates automatically on the next push.

---

## Troubleshooting Quick Reference

| Symptom | Likely cause | Fix |
|---|---|---|
| `ios-export` job shows "skipped" | Secrets not set | Add required secrets (Step 5) |
| Godot export: "preset not found" | Wrong preset name | Verify `name="iOS"` in export_presets.cfg matches `EXPORT_PRESET` env var |
| Godot export: "missing icons" | Icon paths not set | Add icons, update export_presets.cfg |
| match fails: 401 | `MATCH_GIT_BASIC_AUTHORIZATION` wrong/expired | Regenerate PAT, re-encode base64, update secret |
| gym fails: "no signing certificate" | match didn't install cert | Check `keychain_name` in Matchfile |
| TestFlight upload fails: "app not found" | App not created in ASC | Create app in ASC, verify `APP_IDENTIFIER` |

Full CI/CD requirements: [docs/ci-cd-requirements.md](./ci-cd-requirements.md)
