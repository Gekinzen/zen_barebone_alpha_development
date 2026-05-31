# v7.0.0-beta.1-hf82p — User Management (pkexec, useradd/userdel/wheel toggle)

**Channel:** beta (hotfix on hf82o)
**Released:** 2026-05-25
**Scope:** 2 new files + 2 modified

---

## User request

> "now pre pa add pala ng new feature yun pwd na mag add ng new user and pwd gawin admin sudo and delete din siyempre bawal delete kung sino yun current naka login"

Plus from elicitation answers:
- **Sudo backend**: pkexec (GUI password prompt — no terminal popup needed)
- **Phasing**: User Management gets its own focused drop (most dangerous feature, needs care)

The avatar upload was already in `UserProfilePage.qml` (since v6.16.4), so hf82p is purely the system-user CRUD layer.

---

## SAFETY-CRITICAL DROP — read this first

User management is the most dangerous feature in the shell. One bad `userdel -r` = unrecoverable account loss + home directory wipe. This drop is built with **defense in depth**:

### Triple-check current user detection

The "is this the current user?" check runs through **three independent sources** that must all agree the deletion target is NOT current:

1. `$USER` environment variable (set by login shell / display manager)
2. `id -un` output (kernel-truth, captured at startup)
3. Final shell-level `[ "$NAME" = "$SUDO_USER" ]` guard inside the pkexec command

Any single check saying "this IS the current user" blocks the action with `exit 99`.

### Hard-coded refusals (cannot be bypassed)

- Cannot delete the current user (see triple-check above)
- Cannot delete `root` (explicit name check)
- Cannot delete any user with uid < 1000 (system accounts hidden from list entirely)
- Cannot remove your OWN admin privilege (sudo-lockout prevention)
- Username validation: posix portable chars only, 1-32 chars, lowercase

### Audit trail

Every action writes to `~/.cache/zen-shell/user-mgmt.log` with ISO timestamp + the sanitized command (passwords masked to `[name:REDACTED-PASSWORD]`). UI has a "View log" button that opens the file in foot/kitty/xterm fallback.

### UI safety

- Delete button on current user's row is **disabled + grayed out + forbidden-cursor**
- Admin toggle on current user (when ON) is **disabled** so demoting yourself is impossible via UI
- Every destructive action shows a **confirmation dialog** explaining exactly what will happen
- Status banner shows `lastError` in red and `lastAction` in green — silent failure is impossible

---

## What ships

### 2 new files

| File | Lines | Purpose |
|---|---:|---|
| `UserManagementService.qml` | 365 | Singleton wrapping useradd/userdel/gpasswd/chpasswd via pkexec, with triple-check safety + audit log |
| `UserManagementPage.qml` | 405 | Settings UI: user list with per-row admin toggle + delete + set-password, plus add-user form |

### 2 modified files

| File | Δ | What |
|---|---:|---|
| `ZenSettings.qml` | +5 | Sidebar entry "User Management" (利用者管理 Riyōsha Kanri) under SYSTEM section, after User Profile + case 29 + page instantiation |
| `ZenVersion.qml` | +0 | hf82o → hf82p |

Total: 2 NEW + 2 MODIFIED = ~775 net new lines.

---

## How it works

### List users
- Reads `/etc/passwd`, filters to `uid >= 1000` and excludes `nobody`
- Reads `/etc/group` to find wheel members → marks users as admin
- Stores in `users` array: `{ name, uid, gid, gecos, home, shell, isAdmin, isCurrent }`
- Auto-refreshes after every successful action

### Create user
- Form: username + full name + initial password + admin toggle
- Validates username (posix chars, 1-32 chars, starts with letter/_)
- Validates password (≥ 4 chars)
- Refuses if username already exists
- Runs `useradd -m -s /bin/bash [-G wheel] -c "<gecos>" <name>` then `chpasswd` heredoc
- Single pkexec prompt covers both commands

### Delete user
- Triple-check safety
- Confirmation dialog showing exact effects (account, home dir, mailbox)
- Runs `userdel -r <name>`
- Final shell-level guard re-checks SUDO_USER + root before delete fires

### Admin toggle
- Promote: `gpasswd -a <name> wheel`
- Demote: `gpasswd -d <name> wheel`
- Demote of current user blocked at FOUR layers (UI disabled, switch revert, service refuse, shell guard)

### Set password (for OTHER users)
- Admin can reset another user's password via the key icon next to their row
- Confirmation dialog with new-password input
- Runs `chpasswd` heredoc
- For changing YOUR OWN password, use `passwd` in terminal — that's a self-service action that doesn't need admin privilege and feels wrong to wrap

---

## Install

```fish
tar -xzf zen-shell-v7_0_0-beta_1-hf82p.tgz
cd zen-shell-v7.0.0-beta.1-hf82p
./install.sh

pkill -f quickshell; and sleep 1
quickshell -p ~/.config/quickshell/zen-shell &
```

---

## Verify

After install:

1. **Sidebar** → SYSTEM section → "User Management" (利用者管理 Riyōsha Kanri) after User Profile
2. Open it — should see safety notice (yellow banner) + your username listed with "(YOU)" badge
3. Your row's Delete button is grayed out with forbidden cursor on hover
4. Try creating a test user:
   - Username: `testuser`
   - Full name: `Test User`
   - Password: `testpass`
   - Admin: off
   - Click Create → pkexec prompt appears → enter your sudo password → user appears in list
5. Verify: `getent passwd testuser` shows the new account
6. Toggle admin ON for testuser → another pkexec → check `groups testuser` shows wheel
7. Click the key icon → set a new password → pkexec → done
8. Click trash icon → confirmation dialog → confirm → pkexec → user removed
9. Verify: `getent passwd testuser` returns nothing
10. View audit log: `tail ~/.cache/zen-shell/user-mgmt.log`
11. **Settings → System Info** → `v7.0.0-beta.1-hf82p · released 2026-05-25`

### Try to break it

These should ALL refuse safely:

- Try to delete your own user (Paul) → button disabled, can't click
- Try to demote your own admin → switch disabled when ON
- Manually edit dialog state via dev tools to set target to `root` → service refuses with "cannot delete the root account"
- Disconnect during pkexec → status shows "pkexec auth canceled or unauthorized"
- Create user with invalid name (`UPPER`, `1starts-with-digit`, contains `/`) → form rejects with clear error

---

## Wala tayong babawasan

Zero removals. Existing `UserProfilePage.qml` (avatar upload + system info) untouched — the new `UserManagementPage` is a separate sibling page for system-user CRUD. The two pages live in the SYSTEM section as adjacent entries.

---

## Open threads (still active)

- Quickshell C++ crash dump capture
- Multi-monitor flameshot screen targeting
- Build-time version auto-derivation
- `Component.onCompleted` race audit
- Panel-position-aware (`isTop`) audit
- `Switch` → `HMSwitch` audit
- Hyprland minor-version compat (sanitizer for 0.56+)
- **Profile setup popup position bug** — still needs screenshot to identify
- **NEW from hf82p**: rename-user / change-home-dir / change-shell — could be a Phase 2 of user mgmt if you want. usermod handles all of these and the same pkexec wrapper applies cleanly. Estimated +150 lines.
- **NEW from hf82p**: lock/unlock user (`usermod -L` / `-U`) — quick toggle without deleting. Estimated +50 lines.
- Dock Phase 2 (ZenControlCenter popup + drag-list UI)
- Dock Phase 3 (auto-hide / per-app badges)
