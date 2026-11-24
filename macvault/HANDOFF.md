# Continue MacVault on the Mac (copy-paste prompt)

Paste everything below the line into a new Claude Code session started in the
cloned `karaoke` folder on the Mac.

---

I'm continuing a build that started in a cloud session. Please pick it up from here on my Mac Mini (Apple silicon, macOS).

## What this is
MacVault is a personal menu bar password manager for macOS: a minimal take on 1Password's core. It lives in the repo `clydealegro/karaoke`, on branch `ccr-d426838a-wb9vu0`, in the folder `macvault/`. The rest of the repo is an unrelated karaoke project; don't touch it.

Read these first:
- `docs/superpowers/specs/2026-11-24-macvault-design.md`: the approved design
- `docs/superpowers/plans/2026-11-24-macvault.md`: the implementation plan. The "Post-review fixes" section at the end lists changes made after the plan.
- `macvault/README.md`: build, install and the manual test checklist

## Decisions already made (don't revisit)
- No master password. Logins are stored only in the macOS login Keychain, one generic-password item each, service `MacVault`. Copying or revealing a password asks for Touch ID or my Mac password, then not again for 5 minutes.
- Features: save/edit/delete logins (name, username, password, website). A menu bar popover with search, and Return copies the top match's password. Copy username and copy password buttons. The ⌥⌘P global hotkey. A password generator. Copied passwords clear from the clipboard after 30 s.
- Swift package (tools 5.9, macOS 13+): the `MacVaultCore` library has 39 XCTest tests; the `MacVault` app uses AppKit `NSStatusItem` + `NSPopover` + SwiftUI and a Carbon hotkey. `build.sh` makes an ad-hoc signed `build/MacVault.app`.
- Out of scope: sync, iPhone, browser autofill, notes, import/export.

## Where it stands
All the code is written, committed and pushed. It has NEVER been compiled: the cloud session had no Swift compiler. An independent code review found no compile errors and fixed several runtime issues. Your job is to make it build, pass its tests and work.

## What to do
1. `git fetch origin && git checkout ccr-d426838a-wb9vu0 && git pull`, then `cd macvault`.
2. Check the toolchain: `xcode-select -p` and `swift --version`. `swift test` needs full Xcode (not just the Command Line Tools). If only the CLT are installed, say so, and do the build steps before the test steps.
3. `swift build`. Fix any compile errors with the smallest change that keeps to the design, and rebuild until it's clean. Warnings about `onChange(of:perform:)` and `activate(ignoringOtherApps:)` being deprecated are expected; leave them.
4. `swift test`. All 39 tests should pass. The Keychain tests use the real login keychain under a throwaway service name. If macOS shows a keychain dialog, tell me to click Allow. If a test fails, find the root cause before changing anything; don't weaken a test to make it pass.
5. `./build.sh`, then `cp -R build/MacVault.app /Applications/ && open /Applications/MacVault.app`. A key icon should appear in the menu bar, with no Dock icon.
6. Walk me through the "Manual test checklist" in `macvault/README.md` one item at a time, and fix anything that fails. The review flagged these as most likely to need attention:
   - After ⌥⌘P from another app, can I type into the search field straight away? (macOS 14+ activation rules)
   - After copying a password, does ⌘V paste in the previous app immediately?
   - Does the popover stay usable around the Touch ID/password prompt and the Delete confirmation? If it keeps closing, consider `popover.behavior = .semitransient` while an authentication is in progress.
7. Commit each fix with a clear message on branch `ccr-d426838a-wb9vu0` and push. Don't commit `.build/` or `build/`, and never commit any real passwords.

When it's done, tell me plainly: does it build, do the tests pass (with counts), and which checklist items passed or failed.
