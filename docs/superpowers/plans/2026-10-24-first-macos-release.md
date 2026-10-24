# First macOS Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver reviewable first-release tooling and documentation without claiming production signing or validation.

**Architecture:** Reuse Swift Package and AppKit. Build each architecture, merge executable, assemble app; separately gate distribution on Developer ID and notarytool credentials.

**Tech Stack:** Swift, Bash, Apple command line tools.

- [x] Add packaging/version.env and Info.plist metadata.
- [x] Add scripts/build-release.sh and package-release.sh with fail-fast behavior and isolated staging.
- [x] Correct saved key-code zero handling in ReminderWindowController.swift.
- [x] Update README, release/v0.1.0.md and release/README.md.
- [ ] Run bash syntax validation, plist validation, Universal 2 build, signature and ZIP/DMG structure checks; record limitations.
- [ ] Maintainer signs/notarizes and performs cross-machine/download checks before publication.
