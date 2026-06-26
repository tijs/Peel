# Releasing Peel

Peel is distributed outside the Mac App Store as a Developer ID signed and
notarized disk image attached to a GitHub release.

## One-time setup

1. Create or export a Developer ID Application certificate for your Apple
   Developer team.
2. Convert the `.p12` to base64:

   ```sh
   base64 -i DeveloperIDApplication.p12 | pbcopy
   ```

3. Add these GitHub repository secrets:

   - `BUILD_CERTIFICATE_BASE64`: base64 encoded Developer ID `.p12`
   - `P12_PASSWORD`: password for the exported `.p12`
   - `KEYCHAIN_PASSWORD`: temporary CI keychain password
   - `APPLE_API_KEY_ID`: App Store Connect API key ID
   - `APPLE_API_ISSUER_ID`: App Store Connect issuer ID
   - `APPLE_API_PRIVATE_KEY_BASE64`: base64 encoded App Store Connect `.p8` key
   - `APPLE_TEAM_ID`: Apple Developer Team ID

## Local release build

```sh
VERSION=1.0 scripts/release/release.sh
```

Set `SKIP_NOTARIZATION=1` for a local packaging dry run that skips the Apple
notary upload. This still requires a Developer ID Application certificate,
because the exported app must use Developer ID signing.

```sh
VERSION=1.0 SKIP_NOTARIZATION=1 scripts/release/release.sh
```

If Apple timestamping is unavailable or a newly created certificate has not
propagated through the timestamp service yet, use:

```sh
VERSION=1.0 SKIP_NOTARIZATION=1 SIGNING_TIMESTAMP=none scripts/release/release.sh
```

Do not use `SIGNING_TIMESTAMP=none` for a public release unless notarization
accepts the artifact.

The release artifact is written to `dist/Peel-<version>.dmg` with a matching
`.sha256` checksum.

## GitHub release

1. Update `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`, and `CHANGELOG.md`.
2. Commit the release changes.
3. Tag the commit:

   ```sh
   git tag v1.0
   git push origin v1.0
   ```

The `Release` workflow builds, notarizes, staples, and uploads the `.dmg` and
checksum to the GitHub release.

You can also run the workflow manually from GitHub Actions by providing a
version such as `1.0`. The workflow publishes or updates the matching `v1.0`
GitHub release.

## Verification

After downloading the artifact from GitHub:

```sh
shasum -a 256 -c Peel-1.0.dmg.sha256
spctl --assess --type open --context context:primary-signature --verbose Peel-1.0.dmg
xcrun stapler validate Peel-1.0.dmg
```

Then mount the disk image, drag Peel to Applications, and test first launch on a
machine or user account without a cached model.
