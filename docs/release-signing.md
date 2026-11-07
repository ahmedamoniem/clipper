# Persistent release signing without a paid membership

macOS identifies apps for privacy permissions using their code-signing designated
requirement. An ad hoc signature is tied to one build, so updating Clipper can
invalidate its Accessibility authorization. Reusing one self-signed code-signing
certificate and the bundle identifier `io.github.ahmedamoniem.clipper` gives
successive releases a stable identity.

This addresses signing identity continuity. It does not provide Developer ID,
Apple notarization, or Gatekeeper approval. Do not change system trust settings or
disable Gatekeeper to set up release signing. End-to-end Accessibility retention
still needs verification across two installed releases on the target macOS.

## One-time maintainer setup

Create the certificate once on a Mac. Choose a private directory outside the
repository; the command refuses to overwrite an existing directory:

```sh
bash scripts/create-signing-identity.sh /absolute/private/path/clipper-signing
```

The directory contains an encrypted PKCS#12 signing identity, its password, its
Base64 representation, the public certificate, and its SHA-1 fingerprint. Keep an
encrypted private backup of the whole directory. The fingerprint identifies the
certificate; it is not a password. Never commit the PKCS#12, password, or Base64
file, and never generate a new identity for each build.

An alternative is Keychain Access > Certificate Assistant > Create a Certificate:
use Self Signed Root and Code Signing, choose an appropriate validity period,
and export the identity including its private key as a password-protected `.p12`.
The helper script automates the equivalent creation without changing Keychain
trust settings.

Store the generated values in this repository's GitHub Actions configuration:

| Type | Name | File |
| --- | --- | --- |
| Secret | `RELEASE_CERTIFICATE_BASE64` | `certificate-base64.txt` |
| Secret | `RELEASE_CERTIFICATE_PASSWORD` | `password.txt` |
| Variable | `RELEASE_CERTIFICATE_SHA1` | `certificate-sha1.txt` |

For example, after setting `signing_directory` to the private directory above:

```sh
gh secret set RELEASE_CERTIFICATE_BASE64 --repo ahmedamoniem/clipper < "$signing_directory/certificate-base64.txt"
gh secret set RELEASE_CERTIFICATE_PASSWORD --repo ahmedamoniem/clipper < "$signing_directory/password.txt"
gh variable set RELEASE_CERTIFICATE_SHA1 --repo ahmedamoniem/clipper < "$signing_directory/certificate-sha1.txt"
```

Configure these before merging the workflow change. Only the release job on a
push to `main` receives these secrets. The runner imports the identity into a
temporary keychain, signs the completed universal app, verifies both architectures
against the configured certificate fingerprint and bundle ID, and removes the
keychain and decoded identity on exit. During signing it adds the keychain to the
user search list and restores the original list on exit. A missing or incorrect
identity stops publication. The signing script currently assumes Clipper's single-executable
bundle; adding embedded code requires signing it inside-out as well.

Pull requests also run `bash scripts/test-release-signing.sh` on the hosted macOS
runner. It creates a disposable identity, signs two different universal app
fixtures, checks cross-version identity, and rejects missing or incorrect signing
configuration. This test does not use the permanent release secrets.

## Update behavior and verification

Quit Clipper before replacing `/Applications/Clipper.app`. The first transition
from an ad hoc release to the persistent identity requires one fresh Accessibility
grant. Future builds signed with that same identity should satisfy the saved
requirement. Keep the same bundle ID, certificate, private key, and installation
location. Changing the identity requires users to authorize the app again.

Before publishing, compare two different builds signed with the same certificate:

```sh
codesign --display -r /tmp/clipper-old.req /path/to/old/Clipper.app
sed 's/^designated => //' /tmp/clipper-old.req > /tmp/clipper-old-designated.req
codesign --verify --deep --strict --all-architectures -R /tmp/clipper-old-designated.req /path/to/new/Clipper.app
codesign --verify --deep --strict --all-architectures /path/to/new/Clipper.app
```

Also test installation of the first certificate-signed version, manually grant
Accessibility, then quit and replace it with a second signed version. Confirm
Auto-Paste still works without removing and re-adding the app. A signature check
proves identity continuity; it does not prove every macOS privacy subsystem's
behavior or Gatekeeper acceptance.

References: [Apple on requirements and privacy permissions](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements),
[Apple on self-signed identities](https://developer.apple.com/library/archive/technotes/tn2206/),
and [GitHub on importing signing identities on runners](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications).
