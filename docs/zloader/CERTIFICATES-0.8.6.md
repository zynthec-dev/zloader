# Certificate overview, zLoader 0.8.6

Settings and the signing screen now lead to one Certificates overview. It lists
local certificates once, with their name, expiry and status. A visible Use/Active
action activates or deactivates the certificate directly; successful toggles no
longer show a modal confirmation. Missing-key and expired states remain explicit.
Details, P12/public export, adding or removing a private key and local deletion
are grouped in the row's secondary menu. Local deletion never revokes the
certificate on Apple's portal.

The single plus menu offers Request Certificate, Create Apple Certificate,
Import from File and Import from Apple Portal. The user clarified that creation
means an Apple Developer certificate. The existing authenticated Apple issuance
flow and account inventory/revocation remain in place. Requests use the existing
local RSA/SHA-256 CSR generator; private material stays in the protected Keychain.
Saved requests appear with direct export, and deletion has a confirmation. A
cancelled deletion preserves the request. CSR export sends no request to a CA
automatically.

Signing/profile configuration remains reachable from the overview. Its duplicate
active-certificate card, certificate/key menus and creation/import toolbar were
removed. Existing certificates, keys, imported identities, profile associations
and operation selections are retained. Advanced key management remains available
inside signing/profile configuration.

The new shared ZynthecSettingsStyle components give these surfaces compact
12-point cards, neutral text and the fixed #40B5AD action accent with #102C2A
foreground. Light/dark colors follow the supplied zynthec. palette. Certificate
actions reflow vertically at accessibility text sizes; native navigation and
keyboard/focus controls remain available. New copy is translated through
CertificatesUI.xcstrings; the user's existing Localizable.xcstrings edits are
preserved separately from the implementation commit.

Xcode 27.2 exposed obsolete synchronized-group metadata for 92 layout paths that
had already moved from zLoader/App to zLoader/Localization. The stale membership
exceptions and their 23 obsolete platform-filter entries were removed. The
explicit localized variant groups, build-file platform filters and actual
iOS/tvOS layout resources are unchanged. Project, storyboard and real build
checks validate the correction.

All 33 README regression scripts and three simulator UI regressions passed for
the German menu, request creation/cancellation, file import, direct activation,
persistence, deactivation, details, local deletion and light/dark screenshots.
Native alert dismissal defers model-owned presentation writes until the next
main-queue turn, and the password field owns its temporary input in view state.
A targeted repeat of import/activation passed without the earlier SwiftUI
publishing-during-view-update warning. The iPhoneOS Release build, bootstrap
package verification and normalized IPA file/permission/signature checks passed.
The import fixture is generated locally, contains no Apple credentials and is
excluded from the app and corresponding-source archive. Actual Apple portal
issuance, CA response, physical-device signing, installation, refresh and cellular
lifecycle remain separate device/account validation work. Public asset/feed
verification is recorded in the release receipt.
