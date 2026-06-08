# Handoff: RBAC System Implemented (Roles, Users, PIN Auth) — 06/04/2026 22:00

## Goal
Implement a complete Role-Based Access Control (RBAC) system on top of the existing offline-first Flutter ERP, including:
- PIN-based authentication (4–6 digit numpad)
- User management (admin-only CRUD)
- Role + permission model with system-defined roles
- Forced onboarding on first install
- Forced logout on cash register close
- Permission-gated UI in the main menu

This completes the **Phase 1: Authentication & User Management** of the RBAC roadmap documented in `HANDOFF_CURRENCY_DB_ROLES_06_04_19_30.md`.

---

## Architecture Overview

```
[ OnboardingScreen ]  (only if no users exist)
        ↓
[ LoginScreen ]       (PIN entry for selected user)
        ↓
[ MainScreen ]        (gated by canView checks)
        ↓
[ UserManagementScreen ]  (admin-only, via menu)
```

State machine: `AuthProvider.state` ∈ {`initial`, `requiresOnboarding`, `requiresLogin`, `authenticated`}.

---

## Database (V22 Migration)

### New tables
- **`roles`** — `id, name (UNIQUE), display_name, description, is_system`
- **`users`** — `id, username (UNIQUE), display_name, pin_hash, salt, is_active, created_at, last_login`
- **`user_roles`** — M:N pivot, `user_id, role_id` (FK CASCADE)
- **`role_permissions`** — `id, role_id, module, can_view, can_create, can_edit, can_delete` (UNIQUE role+module)
- **`active_session`** — single-row table (id=1 CHECK), `user_id, logged_in_at, last_activity_at`

### Modified tables
- **`transactions`** — added `performed_by_user_id INTEGER` (audit trail; not yet populated)

### Seeded default roles
| name | display_name | default perms |
|---|---|---|
| `admin` | Administrador | full access to all 10 modules |
| `gerente` | Gerente | all modules except config (view+edit only) |
| `cajero` | Cajero | all modules, delete only for ventas+gastos |
| `vendedor` | Vendedor | only ventas + clientes (view+create+edit) |

### Modules (10)
`ventas`, `compras`, `pedidos`, `clientes`, `proveedores`, `inventario`, `reportes`, `gastos`, `caja`, `configuracion`

### Migration safety
- V22 block uses `try/catch` per table (matches V20/V21 pattern)
- `_seedDefaultRolePermissions()` only seeds if no permissions exist (idempotent)
- Export includes new V22 tables

---

## Security

- **PIN storage**: SHA-256(salt + pin) per `crypto` package; salt = 16 random bytes (base64url)
- **Storage format**: `salt:hash` (currently stored in 2 columns for query-ability, but the format is the same as `createPinHash()` produces)
- **No default PIN** — onboarding requires user to create admin PIN (no `0000` fallback)
- **PIN validation**: 4–6 digits, regex `^\d+$`
- **Admin guard**: Cannot delete/deactivate the last admin (DB count check)
- **Build-time safety**: `lib/services/auth_service.dart` does not log PIN values

### Future hardening (NOT done in this phase)
- Constant-time compare (currently `==` on hex digests; not vulnerable to timing in practice for ~256-bit SHA-256 with local-only auth, but PBKDF2/Argon2 would be better)
- Session timeout (15/30/60 min) — `active_session.last_activity_at` is tracked but no enforcement yet
- Failed-attempt lockout
- PIN rotation policy
- Audit log of permission changes

---

## Files Created

| File | Purpose |
|---|---|
| `lib/models/role.dart` | Role model (toMap/fromMap/copyWith) |
| `lib/models/role_permission.dart` | RolePermission model (module-level CRUD perms) |
| `lib/models/user.dart` | User model (PIN auth) |
| `lib/models/active_session.dart` | ActiveSession model (single-row) |
| `lib/services/database/users_db_mixin.dart` | All RBAC DB operations + seedDefaultRoles |
| `lib/services/auth_service.dart` | SHA-256 + salt hash, login/changePin/createAdmin |
| `lib/providers/auth_provider.dart` | State machine + canView/canCreate/canEdit/canDelete |
| `lib/widgets/pin_pad.dart` | Reusable numpad for PIN entry |
| `lib/screens/auth/onboarding_screen.dart` | First-run admin setup (username + PIN confirm) |
| `lib/screens/auth/login_screen.dart` | User list + PIN entry |
| `lib/screens/settings/user_management_screen.dart` | Admin-only user CRUD with role checkboxes |

## Files Modified

| File | Change |
|---|---|
| `lib/services/database_service.dart` | Registered `UsersDb` mixin; imported new models |
| `lib/services/database/core_db_mixin.dart` | DB version 21→22; export V22 tables |
| `lib/services/database/schema_db_mixin.dart` | V22 migration block + fresh-install tables |
| `lib/services/database/cash_register_db_mixin.dart` | `openRegister(balance, {int? userId})` |
| `lib/providers/cash_register_provider.dart` | `openSession(balance, {int? userId})` |
| `lib/screens/menu_screen.dart` | Added `module` field to `_MenuItemData`; filtered by `canView`; admin-only "Gestión de Usuarios" item |
| `lib/screens/cash_register/cash_register_screen.dart` | Pass `auth.currentUser.id` to `openSession`; force `logout()` on close |
| `lib/screens/settings/settings_screen.dart` | New "Sesión" section with user info + logout |
| `lib/main.dart` | Added `AuthProvider` to providers; `_AuthGate` widget routes by state |
| `pubspec.yaml` | Added `crypto: ^3.0.3` |

---

## UX Flow

### First run (no users exist)
1. App starts → `AuthProvider.initialize()` detects `isBootstrapRequired()` → `requiresOnboarding`
2. `_AuthGate` shows `OnboardingScreen`
3. User enters username (≥3 chars) + display name
4. User enters PIN twice (4–6 digits)
5. `completeOnboarding()` creates admin user with `admin` role
6. → `authenticated` → `MainScreen`

### Subsequent runs
1. App starts → checks `active_session` table
2. If session exists + user is active → resume to `authenticated`
3. Else → `requiresLogin` → `LoginScreen`
4. User selects themselves from dropdown (or auto-selected if 1 user) → enters PIN
5. `login()` verifies, sets `active_session`, loads roles + aggregated permissions
6. → `authenticated` → `MainScreen`

### Logout
- Manual: Settings → Sesión → Cerrar Sesión (confirmation dialog)
- Forced: After "Cerrar Caja" in `cash_register_screen` (arqueo)

### Admin protection
- `user_management_screen` `_confirmDelete` and `_toggleActive` both check `countAdmins()` before allowing delete/deactivate of an admin
- If admin count ≤ 1, the action is blocked with a SnackBar

---

## Permission model

`AuthProvider.canView/canCreate/canEdit/canDelete(module)` returns `true` if **any** of the user's assigned roles has the permission. Aggregated with `MAX()` in SQL to handle multi-role users.

Example:
```dart
if (auth.canDelete('ventas')) {
  // show delete button
}
```

UI integration done so far:
- `menu_screen.dart` — items hidden when `!canView(module)`
- `menu_screen.dart` — "Gestión de Usuarios" item only shown when `auth.isAdmin`

UI integration TODO (Phase 2):
- Gate individual action buttons in:
  - `transaction_history_screen.dart` (edit/delete sale)
  - `product_list_screen.dart` (edit/delete product)
  - `customer_list_screen.dart`, `supplier_list_screen.dart`
  - `expense_form_screen.dart`
  - `cash_register_screen.dart` (arqueo requires admin or gerente)
- Hide entire sections for users with no perms (currently a vendor with `ventas` view-only can see the section but no action buttons)

---

## Quick Start for Future Agent

```bash
# After cloning/cleaning
flutter pub get
flutter run -d windows
```

On first launch:
1. Onboarding screen appears (no users in DB)
2. Create admin: username `admin`, name `Admin`, PIN `1234` (or any 4–6 digit PIN)
3. Logged in as admin → see all menu items
4. Settings → Sesión → "Cerrar Sesión" to test login flow
5. To create more users, log in as admin and go to "Gestión de Usuarios" in the menu

To wipe and re-test the onboarding flow:
- Delete `dulces_pierre.db` (and `-wal`, `-shm`) in the app's data directory, OR
- Use the in-app `Utilities` screen if there's a "Reset Database" option, OR
- Bump DB version to 23 to force re-creation (NOT recommended for prod)

---

## Known Limitations / Future Work

1. **No session timeout enforcement** — `active_session.last_activity_at` is updated on login but never checked. Add a `WidgetsBindingObserver` or a periodic timer to call `logout()` after N minutes idle. (Phase 2)
2. **`performed_by_user_id` not yet populated** — column exists in V22, but `transactions_db_mixin` insert sites don't pass it. Refactor `sale.toMap()` / purchase / expense creation to include `performedByUserId`. (Phase 2)
3. **No granular row-level visibility** — A `vendedor` sees ALL sales, not just their own. Handoff specified hierarchical visibility (vendor sees own sales, admin/gerente sees all). This requires passing `currentUser.id` as a filter to `getTransactions()` and `getReports()`. (Phase 3)
4. **No role editing UI** — The 4 default roles are seeded and their permissions are fixed in code. Editing a role's permissions requires SQL or a future "Role Editor" screen. (Phase 3)
5. **No password recovery** — Admin can reset a user's PIN via "Editar" → "Nuevo PIN", but if the only admin forgets the PIN, the DB must be wiped. (Consider a master recovery code in Phase 3)
6. **No SaaS bridge** — See `docs/SAAS_MIGRATION_CONSIDERATIONS.md` for questions on cloud sync of users/roles
7. **No two-factor auth** — PIN is the only factor. (Out of scope for v1)

---

## Testing checklist (manual)

- [ ] First install → onboarding appears
- [ ] Create admin with 4-digit PIN → lands on MainScreen
- [ ] Restart app → auto-resumes admin (active_session)
- [ ] Settings → Cerrar Sesión → returns to LoginScreen
- [ ] Login as admin → see all 10 modules in "MI NEGOCIO"
- [ ] Open "Gestión de Usuarios" → create a `vendedor` user
- [ ] Cerrar Sesión → log in as vendedor
- [ ] Verify vendedor sees ONLY `ventas` and `clientes` modules
- [ ] Verify "Gestión de Usuarios" item is hidden for vendedor
- [ ] Log in as admin → try to delete the admin user → blocked
- [ ] Log in as admin → delete the vendedor user → success
- [ ] Open cash register → close it (arqueo) → forced logout
- [ ] Log in again → cash register session is gone (CLOSED status preserved)

---

## Pre-existing Issues (NOT introduced by this PR)

- `lib/screens/cash_register/cash_register_screen.dart:676:40` — `use_build_context_synchronously` (info, present in `main` before this PR). Do NOT fix per handoff convention.

---

## Related Documents

- `docs/handoffs/HANDOFF_CURRENCY_DB_ROLES_06_04_19_30.md` — full RBAC roadmap & decisions
- `docs/SAAS_MIGRATION_CONSIDERATIONS.md` — open questions for future cloud sync
