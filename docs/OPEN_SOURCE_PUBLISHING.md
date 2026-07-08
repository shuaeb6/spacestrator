# Open-source publishing guide (maintainer)

This document walks you through publishing **Spacestrator** on GitHub as an open-source project, cutting a signed release, and distributing it to end users.

---

## What you already have

| Piece | Location | Purpose |
| ----- | -------- | ------- |
| MIT license | `LICENSE` | Open-source license (update `YOUR NAME`) |
| README | `README.md` | Project overview, build instructions |
| CI workflow | `.github/workflows/ci.yml` | Builds + tests on every push/PR to `main` |
| Release workflow | `.github/workflows/release.yml` | Signs, notarizes, publishes a DMG on `v*` tags |
| Build script | `scripts/build.sh` | Assembles `build/Spacestrator.app` |
| Sign / notarize | `scripts/sign_notarize.sh` | Developer ID sign + Apple notarization |
| Homebrew cask | `packaging/homebrew/spacestrator.rb` | Template for `brew install --cask` |
| Example config | `examples/projectX.json` | Sample project JSON for users |
| End-user guide | `docs/END_USER_GUIDE.md` | What users see after install |

---

## Before you push — replace placeholders

Search the repo and replace these **before** the first public commit:

| Placeholder | Replace with | Files |
| ----------- | ------------ | ----- |
| `YOUR NAME` | Your legal name | `LICENSE` |
| `YOURNAME` | Your GitHub username | `packaging/homebrew/spacestrator.rb`, `README.md` |
| `com.example.spacestrator` | Your bundle id, e.g. `com.yourname.spacestrator` | `Resources/Info.plist.template`, `scripts/build.sh`, `Sources/SpacestratorKit/Support/Log.swift`, Homebrew cask `zap` block |
| `REPLACE_WITH_DMG_SHA256` | Filled in after first release | `packaging/homebrew/spacestrator.rb` |

Quick find:

```bash
grep -r "YOURNAME\|YOUR NAME\|com.example.spacestrator\|REPLACE_WITH" \
  --include='*.md' --include='*.rb' --include='*.swift' --include='*.template' --include='*.sh' .
```

Optional but recommended:

- Replace `Resources/icon-1024.png` and run `scripts/make_icon.sh` for your own icon.
- Remove or keep `patch_v1/` out of git (it is listed in `.gitignore`).

---

## Step 1 — Create the GitHub repository

1. Go to [github.com/new](https://github.com/new).
2. Repository name: `spacestrator` (or `Spacestrator`).
3. Description: *Per-project menu bar launcher for apps, spaces, and IDE projects on macOS.*
4. Visibility: **Public**.
5. Do **not** initialize with a README (you already have one).
6. Click **Create repository**.

---

## Step 2 — Initialize git and push (run these locally)

From the project root (`Spacestrator/`):

```bash
cd /Users/mohammedshoeb/Documents/workspace-orchestrator/spacestrator/Spacestrator

# Initialize repo
git init
git branch -M main

# Stage everything (.gitignore excludes .build/, build/, patch_v1/, etc.)
git add .
git status          # review what will be committed — no secrets, no .p12 files

# First commit
git commit -m "$(cat <<'EOF'
Initial open-source release of Spacestrator.

Native macOS menu bar app for launching per-project app sets onto
Mission Control spaces, with CI and automated signed release workflow.
EOF
)"

# Add your GitHub remote (replace YOURNAME and repo name if different)
git remote add origin git@github.com:YOURNAME/spacestrator.git

# Push
git push -u origin main
```

If you prefer HTTPS:

```bash
git remote add origin https://github.com/YOURNAME/spacestrator.git
git push -u origin main
```

---

## Step 3 — Configure the GitHub repository

On github.com → your repo → **Settings**:

### General
- Add topics: `macos`, `swift`, `menu-bar`, `workspace`, `productivity`, `mission-control`.
- Enable **Issues** and **Discussions** (optional but helpful for open source).

### Actions
- **Settings → Actions → General → Workflow permissions** → *Read and write permissions* (needed for releases).

### Branch protection (recommended after first push)
- **Settings → Branches → Add rule** for `main`:
  - Require pull request before merging
  - Require status checks: `build-test` (from CI)

---

## Step 4 — Verify CI

After pushing to `main`, open **Actions** on GitHub. The **CI** workflow should:

1. `swift build`
2. `swift test`
3. `scripts/build.sh 0.0.0-ci`

If it fails, fix locally with `swift test` and push again.

---

## Step 5 — First signed release (optional but recommended for users)

End users expect a **notarized** `.dmg` they can double-click. That requires:

1. **Apple Developer Program** membership ($99/year).
2. A **Developer ID Application** certificate.
3. GitHub Actions secrets (Settings → Secrets and variables → Actions):

| Secret | Value |
| ------ | ----- |
| `DEVELOPER_ID_CERT_P12` | Base64 of your `.p12`: `base64 -i cert.p12 \| pbcopy` |
| `DEVELOPER_ID_CERT_PASSWORD` | Password used when exporting the `.p12` |
| `KEYCHAIN_PASSWORD` | Any random string for the ephemeral CI keychain |
| `SIGN_IDENTITY` | Full name from `security find-identity -v -p codesigning`, e.g. `Developer ID Application: Jane Doe (ABCDE12345)` |
| `NOTARY_APPLE_ID` | Your Apple ID email |
| `NOTARY_TEAM_ID` | 10-character Team ID |
| `NOTARY_PASSWORD` | App-specific password for notarytool |

### Tag and push a release

```bash
git tag v0.1.0
git push origin v0.1.0
```

The **Release** workflow will build, sign, notarize, staple, create `Spacestrator-0.1.0.dmg`, and publish a GitHub Release.

After it finishes, copy the `version` and `sha256` from the release notes into `packaging/homebrew/spacestrator.rb`, commit, and push.

### Release without Apple signing (dev / early testers only)

You can publish source-only and tell advanced users to build locally:

```bash
scripts/build.sh 0.1.0
open build/Spacestrator.app
```

Unsigned builds may trigger Gatekeeper; users run:

```bash
xattr -dr com.apple.quarantine build/Spacestrator.app
```

---

## Step 6 — Homebrew distribution (optional)

1. Create a tap repo: `github.com/YOURNAME/homebrew-tap`.
2. Copy `packaging/homebrew/spacestrator.rb` into that repo (update `version`, `sha256`, URLs).
3. Users install with:

```bash
brew install --cask YOURNAME/tap/spacestrator
```

---

## Step 7 — Ongoing maintenance

### Day-to-day development

```bash
swift run              # run from source
swift test             # run tests
git checkout -b feat/my-change
# ... edit ...
git add .
git commit -m "Describe the change"
git push -u origin feat/my-change
# Open a PR on GitHub
```

### Cutting a new release

```bash
# Update version strings if needed, merge to main, then:
git checkout main
git pull
git tag v0.2.0
git push origin v0.2.0
# Update Homebrew cask with new sha256 from the Release workflow summary
```

---

## Checklist before going public

- [ ] Placeholders replaced (`YOURNAME`, bundle id, LICENSE name)
- [ ] No secrets in the repo (`.p12`, passwords, personal paths in configs)
- [ ] `patch_v1/` not committed (covered by `.gitignore`)
- [ ] `swift test` passes locally
- [ ] README links to `docs/END_USER_GUIDE.md`
- [ ] CI green on `main`
- [ ] (Optional) First `v0.1.0` release published with signed DMG
- [ ] (Optional) Homebrew cask updated

---

## File layout users will see on GitHub

```
Spacestrator/
├── README.md                 ← landing page
├── LICENSE
├── Package.swift
├── docs/
│   ├── END_USER_GUIDE.md     ← install & daily use
│   └── OPEN_SOURCE_PUBLISHING.md  ← this file
├── Sources/                  ← Swift source
├── Tests/
├── scripts/                  ← build, sign, icon
├── packaging/homebrew/       ← cask template
├── examples/                 ← sample project JSON
└── .github/workflows/        ← CI + Release
```
