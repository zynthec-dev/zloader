# Continuous Settings and tab order, zLoader 0.8.8

User request of 3 November 2026: one continuous native Settings list, starting
with User Customizations, without the text blocks between groups. Only Advanced,
Diagnostics and Credits remain separate expandable departments, all initially
collapsed. This supersedes the earlier request to keep Credits permanently open.
No new palette, custom card style or product-wide design exception is introduced.

The main list contains User Customizations; sign-in or the existing account
values; one Certificates entry; the paid-account Portal entry when applicable;
Appearance; refresh/idle options; storage/cache actions; and the existing help
entry. Appearance now contains appearance mode, language and the original app-icon
picker. Former display/refresh/storage categories are fixed rows in the same
native inset-grouped table section. Their old explanatory footer strings are not
rendered; no localization data or preference values were deleted.

Certificates is present once in the main list with or without an Apple login.
The duplicate Advanced entry is omitted. It uses the same neutral native label
color and fixed mint symbol tint as the other entries. Its local/offline signing
flow is unchanged. Sign Out is a native red text bar item at the top of Settings
when an account is active, rather than a button inside the account header. The
existing confirmation and sign-out implementation are retained.

Original storyboard cells keep their objects, segues, labels and control targets.
The visible content is rebuilt using UIListContentConfiguration and standard
system image dimensions. Former custom storyboard margins and separators are
reset from a native UITableViewCell. This supplies native row margins, text styles, wrapping,
colors and symbol columns. Existing switches are reparented as native accessories;
their outlets/actions and stored values remain intact. The shared SwiftUI entry
label now uses native Label instead of a manually sized symbol canvas. Expanded
account values still read the original account labels; no account fixture or
fake authenticated session is used.

A one-time version-2 section-preference migration sets Advanced, Diagnostics and
Credits to collapsed. Only those three sections are collapsible; subsequent user
choices persist. The custom headers use native text styles/margins and measured
fitting heights so captions do not overlap rows. The main list has no captions or
explanatory footers.

Tab order is News, Sources, Apps, Browse, Settings. News and Apps are literal
names in every locale; Sources/Browse/Settings use the existing translations.
News and Apps landing-page titles match. The native tab controller enum and both
storyboard relationship orders are updated together, preserving existing source,
app/container, import and diagnostic routing. No data or running operation is
reset by changing the order.

Validation includes the README local regression suite, simulator interaction for
appearance/icon navigation, certificate access without login, section defaults
and persistence, switch persistence with restoration, localized tab order and
existing signing/navigation flows. Screenshots are inspected in light/dark mode
and at large accessibility text size. A dedicated simulator avoids focus changes
from other projects' tests. Actual Apple login/logout, authorized signing and
physical-device launch/installation/refresh remain separate hardware validation.
The existing pinned binary-runtime minimum of iOS 26.5 is unchanged.

All 33 README regression scripts and eight focused simulator UI tests passed.
The navigation test explicitly waits for the native push transition before
counting back buttons. A final two-test recheck passed after resetting legacy
row margins; switch values were restored after testing. The iPhoneOS Release
build succeeded. Existing compiler/runtime warnings were retained, including
PipelineRunner Sendable captures, an app-icon list API deprecation and the
simulator audio-session warning; warning categories were not suppressed.
