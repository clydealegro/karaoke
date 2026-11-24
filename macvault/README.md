# MacVault

A small menu bar password manager for macOS. Logins are stored in your
macOS login Keychain; copying a password asks for Touch ID or your Mac
password (then not again for 5 minutes), and copied passwords are wiped
from the clipboard after 30 seconds.

## Requirements

- macOS 13 Ventura or later (Apple silicon or Intel).
- Xcode from the App Store (recommended), or at least the Command Line
  Tools: `xcode-select --install`. Running the tests needs full Xcode.

## Build and install

```bash
cd macvault
./build.sh
cp -R build/MacVault.app /Applications/
open /Applications/MacVault.app
```

A key icon appears in the menu bar. There's no Dock icon.

**Start at login:** System Settings → General → Login Items → **+** → choose
MacVault in Applications.

**First launch:** macOS may say the app is from an unidentified developer.
Right-click MacVault in Applications → **Open** → **Open**. You only do this
once.

## Using it

| Action | How |
| --- | --- |
| Open | Click the key icon, or press **⌥⌘P** anywhere |
| Find | Start typing; matches name, username and website |
| Copy password | Key button on a row, or **Return** for the top match |
| Copy username | Person button on a row |
| Add | **+** next to the search field |
| Edit / delete | Pencil button on a row |
| Generate password | In the add/edit form: pick length, digits, symbols, then **Generate** |

### Keychain prompts after rebuilding

The app is signed ad-hoc, so each rebuild looks like a "new" app to the
Keychain. The first time a rebuilt MacVault reads a password, macOS asks
"MacVault wants to use your confidential information stored in … keychain".
Enter your Mac password and click **Always Allow**.

### Where the data lives

Keychain Access → login keychain → items named `MacVault: <name>` (kind
"MacVault login"). Back them up with the rest of your Mac (Time Machine
includes the login keychain). Deleting an item there deletes it from MacVault.

## Tests

```bash
cd macvault
swift test
```

## Manual test checklist

- [ ] Key icon appears in the menu bar; no Dock icon.
- [ ] Click icon → popover opens with the search field focused.
- [ ] ⌥⌘P from another app opens it; ⌥⌘P again closes it.
- [ ] **+** → enter name, username, website, **Generate** → password shows → **Save** → row appears.
- [ ] Save is disabled with an empty name, or an empty password for a new login.
- [ ] Copy username → paste in TextEdit shows the username; footer says "Username copied".
- [ ] Copy password → Touch ID / password prompt → paste shows the password; popover closes.
- [ ] Copy another password within 5 minutes → no prompt.
- [ ] Wait 30 s after copying a password → clipboard is empty.
- [ ] Copy a password, then copy other text within 30 s → that other text is still there after 30 s.
- [ ] Type part of a name and press Return → top match's password is copied.
- [ ] Edit → password shows "Unchanged" → change only the name → Save → password still copies correctly.
- [ ] Edit → eye button → prompt (if outside 5 min) → password shown.
- [ ] Edit → Delete Login → confirm → row gone; it's gone from Keychain Access too.
- [ ] Quit, reopen → logins are still there.
