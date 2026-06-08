# Handoff: Currency/DB Configurability & Professional Roles Architecture

**Created:** 2026-06-04 19:30
**Branch:** main
**Session Duration:** ~4 hours (combined sessions)
**Build Version:** Flutter 3.38.6 / Dart 3.10.7
**DB Version:** 21

---

## 1. Executive Summary

This multi-session effort completed three major workstreams: (A) critical bug fixes from the original audit, (B) import path normalization across the entire codebase, and (C) full dynamic configurability of currency, locale, and database naming. The application now supports runtime-changeable currency symbols, locale formatting, currency names for receipt word conversion, and safe database file renaming with WAL-mode-aware migration. The system compiles cleanly with zero errors. One pre-existing async-context info warning remains.

Additionally, this handoff proposes a complete **RBAC (Role-Based Access Control) architecture** for a professional-level multi-user system, addressing the fact that the current application is completely open and single-user.

---

## 2. Work Completed

### Session 1: Bug Fixes & Import Normalization
- [x] Fixed `Customer.fromMap()` num cast — `lib/models/customer.dart:65` now uses `(as num?)?.toDouble()` pattern matching `Supplier.fromMap()`.
- [x] Normalized 42 deep relative import paths (`../../../../../../../../../`) to 2-level paths (`../../`) across 34 unique files. Fixed incorrect depth in `pdf_generator_service.dart`.
- [x] Verified Bluetooth disconnect — `PrintBluetoothThermal.disconnect` is a getter, not a method. Existing try-catch is correct.
- [x] Verified `DropdownButtonFormField.initialValue` — Confirmed correct for Flutter 3.38.6. `value` is deprecated since v3.33.

### Session 2: Dynamic Currency & DB Configuration
- [x] Added `currencySymbol`, `currencyCode`, `currencyName`, `locale` fields to `BusinessProfile` model with Bolivian defaults for backward compatibility.
- [x] Refactored `CurrencyHelper` from `static const` to mutable `static` with `updateConfig()` method.
- [x] Integrated `CurrencyHelper.updateConfig()` into `SettingsProvider.loadProfile()` and `updateProfile()`.
- [x] Added `closeDatabase()`, `resetDatabaseInstance()`, `getCurrentDbName()` methods to `CoreDb` mixin.
- [x] Implemented WAL-safe `renameDatabase()` with rollback in `CoreDb` mixin.
- [x] Added "Configuracion Regional & DB" UI section to `BusinessProfileScreen`.
- [x] Replaced all hardcoded `'Bolivianos'` in receipt/PDF services with `profile.currencyName`.
- [x] Replaced all hardcoded `'Bs'` in treasury screens, analytics, validators with `CurrencyHelper.symbol`/`CurrencyHelper.simple()`.
- [x] Replaced all hardcoded `'es_BO'` in DateFormat calls with `CurrencyHelper.locale`.
- [x] Fixed `invalid_constant` errors in `global_payment_screen.dart` and `supplier_payment_screen.dart` (removed `const` from `InputDecoration` that used dynamic `CurrencyHelper.symbol`).

---

## 3. Files Affected (CRITICAL)

### Modified — Currency/DB Config
- `lib/models/business_profile.dart` — Added 4 currency fields, updated constructor/copyWith/toMap/fromMap/clearLogo.
- `lib/utils/currency_helper.dart` — Refactored to mutable statics + `updateConfig()`.
- `lib/providers/settings_provider.dart` — Integrated `CurrencyHelper.updateConfig()` in load/save paths.
- `lib/services/database/core_db_mixin.dart` — Added `closeDatabase()`, `resetDatabaseInstance()`, `getCurrentDbName()`, `renameDatabase()`.
- `lib/screens/settings/business_profile_screen.dart` — Added regional config UI section with DB rename support.

### Modified — Hardcoded Value Removal
- `lib/services/printer/esc_pos_receipt_service.dart` — `profile.currencyName` + `CurrencyHelper.simple()` + `CurrencyHelper.locale`.
- `lib/services/pdf_generator_service.dart` — `profile.currencyName` + `CurrencyHelper.locale`. Fixed import depth.
- `lib/services/analytics_service.dart` — `CurrencyHelper.symbol` via isolate-safe `_ReportPayload`.
- `lib/utils/input_validators.dart` — `CurrencyHelper.simple()`.
- `lib/screens/treasury/global_payment_screen.dart` — `CurrencyHelper.symbol` + removed `const`.
- `lib/screens/treasury/supplier_payment_screen.dart` — `CurrencyHelper.symbol` + removed `const`.
- `lib/services/report_export_service.dart` — `CurrencyHelper.locale`.
- `lib/screens/sales/sale_detail_screen.dart` — `CurrencyHelper.locale`.
- `lib/screens/reports/sales_period_report_screen.dart` — `CurrencyHelper.locale`.
- `lib/screens/cash_register/cash_register_screen.dart` — `CurrencyHelper.locale`.
- `lib/screens/history/transaction_history_screen.dart` — Import normalized.

### Modified — Import Normalization (34 files)
- 21 files: `theme/app_theme.dart` import corrected.
- 21 files: `utils/currency_helper.dart` import corrected.
- (Full list in HANDOFF_BUG_FIXES_06_04_18_45.md)

### Modified — Bug Fixes
- `lib/models/customer.dart` — `fromMap()` num cast.

---

## 4. Technical Context

### Architecture: Currency Configuration Flow
```
BusinessProfileScreen (UI)
  -> SettingsProvider.updateProfile()
    -> SettingsService.saveProfile() [SharedPreferences]
    -> CurrencyHelper.updateConfig() [runtime state]
      -> All 41 files using CurrencyHelper.format()/.simple()/.symbol auto-update
```

### Architecture: Database Rename Flow
```
BusinessProfileScreen (UI, user changes DB name)
  -> DatabaseService().renameDatabase(newName)
    -> closeDatabase() [close SQLite connection]
    -> rename .db file
    -> rename .db-wal file (if exists)
    -> rename .db-shm file (if exists)
    -> save to SharedPreferences
    -> resetDatabaseInstance() [nullify _database]
    -> database [lazy re-init with new name]
    -> ROLLBACK on any failure
```

### Key Design Decisions
| Decision | Rationale |
|----------|-----------|
| `CurrencyHelper` uses mutable statics, not a singleton instance | All 41 consuming files already use `CurrencyHelper.format()` static calls. Changing to instance would require refactoring every call site. |
| DB name stored in SharedPreferences, not in the DB itself | Prevents circular dependency — can't query the DB to find its own name before opening it. |
| WAL-safe rename with rollback | SQLite WAL mode creates .db-wal and .db-shm files. Moving only .db causes data loss. |
| `BusinessProfile` defaults match legacy hardcoded values | Existing users see zero change — `'Bs.'`, `'BOB'`, `'Bolivianos'`, `'es_BO'` are the defaults. |

---

## 5. Current State

### What's Working
- `flutter analyze` reports **1 issue** (pre-existing `use_build_context_synchronously` in `cash_register_screen.dart:666`).
- Currency is fully configurable via Settings -> Business Profile -> "Configuracion Regional & DB".
- Database name is configurable with safe WAL-aware rename.
- All 41 files consuming `CurrencyHelper` automatically reflect config changes.
- Receipts, PDFs, Excel reports, and treasury screens all use dynamic currency.

### What's Not Working / Remaining Tech Debt
- **No user authentication or roles system** — app is single-user, open access.
- 670+ hardcoded `Color(0xFF...)` instances — light theme support broken in many screens.
- `analytics_service.dart` uses `Isolate`/`compute` which doesn't share static state — solved via `_ReportPayload` pattern but other isolates may have the same issue.
- No tests for the new currency/DB rename features.

### Tests
- [x] Flutter Analyzer: Passed (`flutter analyze` completed with 1 pre-existing info warning, 0 errors, 0 new warnings).
- [ ] No new tests added for currency/DB rename features.

---

## 6. Proposed Next Step: RBAC Architecture (Professional Level-Up)

### Context
The application is **completely open, single-user, offline-first**:
- No login screen, no user model, no users table in DB
- No roles or permissions
- No route protection
- The only "user" reference is an orphaned `user_id` column on `cash_registers` (always NULL)

### Proposed Architecture: Local RBAC (SaaS-Ready)

**Arquitectura de Permisos Granulares y Roles**
Pensando en la escalabilidad a SaaS, los roles no son bloques de código rígidos, sino contenedores lógicos configurables:
- **Permisos (Unidad atómica):** Acciones específicas (ej. `ventas.crear`, `caja.arquear`, `productos.eliminar`).
- **Roles (Contenedores):** Agrupaciones de permisos. (Ej. el rol "Cajero" contiene `caja.abrir`, `caja.cerrar`, `ventas.cobrar`).
- **Asignación Múltiple:** Un usuario puede tener **varios roles asignados a la vez**. El sistema realiza un `OR` lógico de sus permisos. Esto soluciona de inmediato el caso donde un empleado es Cajero y Vendedor simultáneamente, preparando el terreno para roles personalizados en el futuro.

#### Database Migration V22 — New Tables

```sql
-- Roles predefinidos del sistema
CREATE TABLE roles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,       -- 'admin', 'gerente', 'vendedor', 'cajero'
  display_name TEXT NOT NULL,      -- 'Administrador', 'Gerente', etc.
  description TEXT,
  is_system INTEGER DEFAULT 1      -- Roles del sistema no se pueden eliminar
);

-- Usuarios del sistema
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  pin_hash TEXT NOT NULL,          -- Hash del PIN (SHA-256 + salt)
  is_active INTEGER DEFAULT 1,
  avatar_color INTEGER,            -- Color del avatar (para UI)
  created_at INTEGER NOT NULL
);

-- Asignacion multiple de roles por usuario (Many-to-Many)
CREATE TABLE user_roles (
  user_id INTEGER NOT NULL,
  role_id INTEGER NOT NULL,
  PRIMARY KEY (user_id, role_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
);

-- Permisos por rol (matriz CRUD por modulo)
CREATE TABLE role_permissions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  role_id INTEGER NOT NULL,
  module TEXT NOT NULL,            -- 'ventas', 'compras', 'inventario', etc.
  can_view INTEGER DEFAULT 0,
  can_create INTEGER DEFAULT 0,
  can_edit INTEGER DEFAULT 0,
  can_delete INTEGER DEFAULT 0,
  FOREIGN KEY (role_id) REFERENCES roles(id),
  UNIQUE(role_id, module)
);

-- Sesion activa (single-row table)
CREATE TABLE active_session (
  id INTEGER PRIMARY KEY CHECK (id = 1),  -- Solo 1 fila
  user_id INTEGER NOT NULL,
  login_at INTEGER NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
);
```

#### System Modules (for permission matrix)

| Module | Description |
|--------|-------------|
| `ventas` | POS, cart, checkout |
| `compras` | Purchase orders to suppliers |
| `inventario` | Product/category/stock management |
| `clientes` | Customer CRUD |
| `proveedores` | Supplier CRUD |
| `caja` | Cash register open/close, arqueo |
| `reportes` | Reports and analytics |
| `gastos` | Expense tracking |
| `configuracion` | Business profile, system settings |
| `usuarios` | User and role management |
| `notas` | Notepad |

#### Predefined Roles — Permission Matrix

| Rol | Ventas | Compras | Inventario | Clientes | Proveedores | Caja | Reportes | Gastos | Config | Usuarios | Notas |
|-----|--------|---------|------------|----------|-------------|------|----------|--------|--------|----------|-------|
| **Admin** | CRUD | CRUD | CRUD | CRUD | CRUD | CRUD | CRUD | CRUD | CRUD | CRUD | CRUD |
| **Gerente** | CRUD | CRUD | CRUD | CRUD | CRUD | CRUD | CRUD | CRUD | CRUD | View | CRUD |
| **Vendedor** | CRUD | View | View | CRUD | View | View | View own | View | No | No | CRUD |
| **Cajero** | View | No | No | View | No | CRUD | View own | View | No | No | No |

#### File Structure (New Files)

```
lib/
  models/
    user.dart                        -- UserModel
    role.dart                        -- RoleModel
    role_permission.dart             -- RolePermissionModel
    active_session.dart              -- ActiveSessionModel
  providers/
    auth_provider.dart               -- Login/logout, session state
    user_management_provider.dart    -- User CRUD (admin only)
  services/
    auth_service.dart                -- PIN hash/verify, session management
    database/
      users_db_mixin.dart            -- User/role CRUD in SQLite
  screens/
    auth/
      login_screen.dart              -- Login screen with user selection
      pin_entry_screen.dart          -- PIN entry for selected user
    settings/
      user_management_screen.dart    -- User CRUD (admin only)
  widgets/
    auth/
      auth_guard.dart                -- Route protection widget
      role_based_widget.dart         -- Show/hide based on permission
```

#### Authentication Flow

```
1. App inicia -> AuthProvider.checkSession()
2. ¿Hay sesion activa en BD? -> Si -> Dashboard (sin login)
3. ¿No hay sesion? -> LoginScreen
4. LoginScreen -> Lista de usuarios (avatars) -> Seleccion -> PIN entry
5. AuthProvider.login(username, pin) -> Verifica hash -> Crea sesion
6. Dashboard con usuario activo
7. Al cerrar app -> Sesion se mantiene (offline-first)
8. Admin puede cerrar sesion de cualquier usuario
```

#### Integration and UI Placement (Configuración de Usuarios)

**Ubicación del Panel Administrativo:**
Para mantener la UI limpia y coherente, la gestión de usuarios y sus múltiples roles residirá en el módulo de configuración:
- **Pantalla:** `lib/screens/settings/user_management_screen.dart`
- **Acceso:** Desde el `MenuScreen`, al entrar al módulo general de **Configuración / Ajustes**, el dueño/administrador verá una tarjeta o panel dedicado a **"Gestión de Usuarios y Accesos"**.
- **Flujo de UI:** Al editar un usuario, el panel presentará _switches_ o _checkboxes_ para asignarle uno o varios roles (Ej: marcar "Cajero" y "Vendedor"). Si un usuario intenta acceder a una ruta sin el permiso, un AuthGuard middleware lo bloqueará.

**menu_screen.dart** — Hide/show modules by permission:
```dart
if (authProvider.canView('ventas'))
  _buildMenuItem('Ventas', ...),
if (authProvider.canView('configuracion'))
  _buildMenuItem('Configuracion', ...),
```

**cash_registers** — `user_id` orphan finally gets populated:
```dart
// Al abrir caja
cashRegisters: {
  'user_id': authProvider.currentUser.id,
  ...
}
```

**transactions** — Audit trail of who made each sale:
```dart
// In transaction_model.dart
final int? performedByUserId;
```

#### Security

- PIN hashed with SHA-256 + salt
- Never store PIN in plain text
- Verification: `hash(pin + salt) == stored_hash`
- Rate limiting: 3 failed attempts -> temporary lock of 30 seconds

#### First-Install Flow

```
1. App detects no 'users' table -> Migracion V22
2. Crea roles predefinidos (admin, gerente, vendedor, cajero)
3. Crea usuario 'admin' con PIN por defecto: 0000
4. LoginScreen muestra solo al admin
5. Admin crea otros usuarios desde Configuracion -> Usuarios
6. Admin cambia su PIN por defecto
```

### Estimated Effort

| Component | Files | Complexity |
|-----------|-------|------------|
| Models (User, Role, Permission, Session) | 4 new | Low |
| DB Mixin (users_db_mixin) | 1 new | Medium |
| Auth Service (hash, verify, session) | 1 new | Medium |
| Auth Provider | 1 new | Medium |
| Login Screen | 2 new | Medium |
| User Management Screen | 1 new | Medium |
| Auth Guard widget | 1 new | Low |
| Integration in menu_screen | 1 modified | Low |
| Integration in cash_register | 1 modified | Low |
| Migration V22 in schema_db_mixin | 1 modified | Medium |
| **Total** | **~14 files** | **Medium** |

### Design Questions for the User

1. **PIN of 4 digits or text password?** — PIN is faster for POS, password is more secure.
2. **First-run behavior?** — Create admin with PIN 0000 automatically, or force user to define PIN?
3. **Vendedor sales visibility?** — Can vendedor only see their own sales, or gerente/admin see all?
4. **Session timeout?** — Manual logout or automatic timeout after 30 min of inactivity?
5. **Can admin see other users' PINs?** — Or only reset them?

---

## 7. Immediate Next Steps (Start Here)

1. **Decide on RBAC design questions** above (PIN vs password, first-run, visibility, timeout).
2. **Implement V22 migration** with users/roles/permissions/session tables.
3. **Build AuthProvider + AuthService** for login/logout/session.
4. **Create LoginScreen** with user selection and PIN entry.
5. **Integrate auth checks** in menu_screen.dart.
6. **Add user management screen** for admin to CRUD users.

### Subsequent
- Add unit tests for `CurrencyHelper.updateConfig()`, `DatabaseService.renameDatabase()`, and `BusinessProfile` serialization.
- Add unit tests for auth flow (PIN hash, verification, session).
- Address hardcoded `Color(0xFF...)` instances for light theme support.
- Consider package imports (`package:proyecto_app_movil_control_de_negocio/...`) for robustness.

---

## 8. Related Resources & Commands

### Commands to Run
```bash
# Verify static code analysis is clean
flutter analyze

# Search for remaining hardcoded currency strings
grep -r "Bs\." lib/ --include="*.dart" | grep -v currency_helper.dart | grep -v business_profile.dart

# Search for hardcoded locale
grep -r "es_BO" lib/ --include="*.dart" | grep -v currency_helper.dart | grep -v business_profile.dart

# Search for hardcoded DB name
grep -r "dulces_pierre" lib/ --include="*.dart"

# Search for orphan user_id references
grep -r "user_id" lib/ --include="*.dart"
```

### Search Queries
- `grep "CurrencyHelper" lib/**/*.dart` — verifies centralized currency usage.
- `grep "renameDatabase" lib/services/database/core_db_mixin.dart` — verifies DB rename method.
- `grep "user_id" lib/services/database/schema_db_mixin.dart` — pre-existing orphan column for future RBAC.
