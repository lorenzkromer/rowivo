# Rowivo project settings

Lorenz edits Signing & Capabilities and General directly in Xcode. Preserve those
edits. The existing `Rowivo.xcodeproj` is usable without regenerating it for every
build or source edit.

Before running XcodeGen in this workspace:

1. Inspect the current `Rowivo.xcodeproj/project.pbxproj`, `Rowivo/Info.plist`,
   entitlements and shared schemes. Reconcile any user edits into `project.yml`
   before generation. Do not replace user settings with old template values.
2. Run `python3 scripts/check-project-settings.py`. It generates only in a temporary
   copy and fails if existing build settings would change or disappear. Resolve
   differences by preserving the user's settings, then rerun the check. Do not
   weaken the check to make an unintended change pass.
3. Back up the existing project bundle and any plist/entitlement files before an
   actual regeneration. Review the resulting diff, including shared schemes and
   capabilities, before building. The automated check covers build settings and
   plist/entitlement contents; it does not replace that review.

`Rowivo/Info.plist` is a maintained source file, referenced by `INFOPLIST_FILE`.
Do not add an XcodeGen `info` block that rewrites it. Preserve Bluetooth background
mode and the exported `.rowivo` document type.

Settings reconciled on 2026-09-03: Rowivo app team `AYPXYQ7R9Z`, bundle identifier
`at.kromerlorenz.rowivo`, iPhone only, iOS 18+, Mac Catalyst / Designed for Mac /
Designed for Vision disabled, version `0.1.0`, build `1`. Future explicit user
changes take precedence; update both the project and its template accordingly.
