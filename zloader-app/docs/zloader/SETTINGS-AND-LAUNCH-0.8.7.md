# Settings and installed-app launch, zLoader 0.8.7

The My Apps launcher previously stopped after an internal LaunchServices denial,
including the reported LSApplicationWorkspaceErrorDomain code 115. Native bundle
launch remains first. On failure, a supplied URL is accepted only if its scheme
exactly matches `zloader-<actual resigned bundle ID>` and it contains no host, path,
query or fragment. This scheme is registered by the existing signing operation.
The fallback uses UIApplication's public URL-opening API on the main queue.
Arbitrary third-party URL schemes and web URLs are not used. Completion fires
once and preserves the native error if the fallback also fails. Selecting the
current host is a no-op before automatic JIT; zLoader is already in front.
No signing entitlement or iOS authorization is bypassed. Apps lacking the
registered scheme can still fail to open; the reported physical-device StarPocket
launch is not verified by the controlled API or simulator checks.

Settings retain their storyboard objects, outlets and connected destinations.
A separate presentation order maps rows to their original storyboard identities:

- Display contains the app-icon entry and the appearance/language screen.
- Advanced starts with User Customizations, Container Settings, Developer Options.
  The remaining installation, connection, pairing, signing and backup settings
  follow, with Shortcuts and debug-only experimental controls.
- Diagnostics contains Health Check, Error Log, Refresh Attempts and Feedback.
- Storage contains the explorer and cache clearing. Credits is the final section.

Tappable native section-header buttons collapse display, refresh, storage,
advanced, diagnostics and credits groups. The state is saved using stable section
identities, survives relaunch, respects reduced motion and does not reset values.
Account sign-in/sign-out actions remain independent of collapsing sections.

The affected settings surfaces now use native grouped tables/lists, semantic
system backgrounds, separators, typography and standard navigation accessories.
Legacy decorative row cards, texture and color-theme selection are removed.
The fixed accent is #40B5AD. Light, Dark and Automatic preserve their stored
appearance keys; language selection remains separate and persistent. The app-icon
picker retains the original alternate-icon behavior. This is not a claim that
all other app screens or the full Icon Composer asset pipeline were migrated.
The existing pinned runtime dependencies still require iOS 26.5; lowering their
minimum requires a separately validated rebuild of those binary dependencies.

Local regression scripts cover native launcher success/denial, legacy/unavailable
paths, invalid identifiers, validated URL fallback success/failure, and rejection
of arbitrary URLs. Simulator tests check order, single-back navigation, removed
appearance entry in User Customizations, native appearance modes, persisted
collapse state, diagnostics placement, Credits last and existing signing flows.
Actual physical-device launch, Apple login/signing, installation/refresh and
cellular/lifecycle behavior remain separate hardware checks.

Two existing regression scripts and Rust executable lookup now support the
monorepo path containing a colon. Xcode/SwiftPM and Rust's test library-path
handling cannot use that path directly, so those tests use the same existing
colon-free build cache as the canonical app build. It contains working-file
copies and no second project Git repository. Test-only runs do not copy stale
app products back. Original authors, licenses, pinned gitlinks, user localization
edits, stored identities and profile associations remain preserved.

Validation completed: all 33 local regression scripts, five unique simulator UI
tests and the targeted native-accessory recheck passed. The final iPhoneOS Release
build, external-only bootstrap/package check and normalized IPA byte/permission/
version/strict-signature checks passed. Light/dark screenshots were inspected.
Public-download and live-feed verification are recorded separately in the release
receipt. Existing compiler warnings were not suppressed.
