# First macOS release design

User approved the release proposal in chat. Preserve the existing AppKit/Swift Package features. Add version metadata, a Universal 2 app builder and a credential-gated signing/notarization/ZIP/DMG packager. Keep local preview ad-hoc signed; public assets require Developer ID and notarization. Fix key-code zero persistence only. No auto-update, new scheduler or UI redesign. Release publishing remains gated on maintainer credentials and real download validation. See release/README.md for acceptance criteria.
