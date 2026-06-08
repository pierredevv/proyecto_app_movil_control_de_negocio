# Migracion a SaaS - Consideraciones y Preguntas Pendientes

**Proyecto:** ERP Movil Control de Negocio
**Fecha:** 2026-06-04
**Estado:** FUTURO - No aplica actualmente
**Contexto:** El proyecto actualmente es una aplicacion offline-first para
tiendas pequenas/medianas en Bolivia. Este documento registra las
consideraciones tecnicas y preguntas de diseno pendientes para una
futura migracion a modelo SaaS.

---

## 1. Arquitectura Actual vs SaaS

| Capa | Actual (Local) | Futuro (SaaS) |
|------|----------------|---------------|
| Base de datos | SQLite (local) | PostgreSQL (Supabase) |
| Backend | N/A (todo en cliente) | Supabase Edge Functions / FastAPI |
| Autenticacion | PIN hash SHA-256 local | JWT + OAuth (Google, email) |
| Roles/Permisos | SQLite local (RBAC) | PostgreSQL con RLS |
| Sincronizacion | N/A | Sync incremental local <-> nube |
| Almacenamiento archivos | Local (path_provider) | Supabase Storage / S3 |
| Multi-tenancy | N/A (1 empresa por app) | 1 empresa = 1 schema/tenant |
| Pagos/Streaming | N/A | WebSocket (Supabase Realtime) |

---

## 2. Lo que NO Necesita Reescritura (SaaS-Ready)

La arquitectura de RBAC actual es identica para SQLite y PostgreSQL:

- Tablas `roles`, `user_roles`, `role_permissions` -> Mismo DDL en PostgreSQL
- Logica de permisos (`canView`, `canCreate`, etc.) -> Misma logica de negocio
- Modelo de `BusinessProfile` con campos de moneda -> Directamente serializable
- `CurrencyHelper` con `updateConfig()` -> Funciona igual con BD compartida
- Formularios de configuracion -> UI reutilizable

**Esfuerzo estimado de reescritura: ~20% del codigo base (principalmente data layer).**

---

## 3. Lo que SI Necesita Cambio

### 3.1 Data Layer (SQLite -> PostgreSQL/Supabase)

**Archivos afectados:** Todos los `*_db_mixin.dart` (11 archivos)

| Patron Actual | Patron SaaS |
|---------------|-------------|
| `openDatabase(path)` | `SupabaseClient()` connection |
| `db.query('table')` | `supabase.from('table').select()` |
| `db.insert('table', map)` | `supabase.from('table').insert(map)` |
| `db.update('table', map, where:...)` | `supabase.from('table').update(map).eq('id', id)` |
| `db.delete('table', where:...)` | `supabase.from('table').delete().eq('id', id)` |
| `PRAGMA journal_mode=WAL` | No aplica (PostgreSQL usa WAL nativo) |

**Estrategia:** Crear una capa de abstraccion `DataService` con interfaz unica que funcione con SQLite (local) o Supabase (nube). El switch se hace por configuracion.

### 3.2 Autenticacion (PIN local -> JWT)

**Archivos afectados:** `auth_service.dart`, `auth_provider.dart`, `login_screen.dart`

| Actual | SaaS |
|--------|------|
| PIN hash local | Email + password + JWT |
| `active_session` table local | Supabase Auth sessions |
| Sin refresh tokens | Refresh tokens + auto-renew |
| Sin 2FA | 2FA opcional (TOTP) |

**Nota:** El PIN de 4-6 digitos puede mantenerse como "fast login" despues del auth inicial con email/password.

### 3.3 Sincronizacion Offline <-> Online

**Nuevo componente:** `SyncService`

**Patron:**
1. App funciona offline con SQLite local
2. Cuando hay internet, sincroniza cambios pendientes con Supabase
3. Conflictos se resuelven con "last write wins" o merge manual
4. Tabla `sync_queue` para tracking de cambios pendientes

```sql
-- Nueva tabla para sync
CREATE TABLE sync_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  table_name TEXT NOT NULL,
  record_id INTEGER NOT NULL,
  action TEXT NOT NULL, -- 'insert', 'update', 'delete'
  payload JSON NOT NULL,
  created_at INTEGER NOT NULL,
  synced INTEGER DEFAULT 0
);
```

### 3.4 Multi-Tenancy

**Patron:** Row-Level Security (RLS) en Supabase

```sql
-- Cada tabla lleva un tenant_id
ALTER TABLE products ADD COLUMN tenant_id UUID REFERENCES tenants(id);
ALTER TABLE transactions ADD COLUMN tenant_id UUID REFERENCES tenants(id);

-- RLS policy
CREATE POLICY "tenant_isolation" ON products
  USING (tenant_id = auth.uid());
```

**Clave:** `tenant_id` = UUID del negocio. Cada usuario pertenece a un tenant.

### 3.5 Almacenamiento de Archivos

| Actual | SaaS |
|--------|------|
| `path_provider` (local) | Supabase Storage / S3 |
| Logo del negocio en disco local | URL publica en Storage |
| Imagenes de productos en disco | URL publica en Storage |
| Respaldos en disco local | Upload a Storage + descarga |

---

## 4. Estrategia de Migracion Recomendada

### Fase 1: Preparacion (Sin cambios visibles)
- [ ] Crear interfaz `DataService` abstracta
- [ ] Refactorizar todos los `*_db_mixin` para usar `DataService`
- [ ] Agregar `tenant_id` a todas las tablas (DEFAULT NULL para compat)
- [ ] Agregar tabla `sync_queue`
- [ ] Crear migracion V23 con tablas de sync

### Fase 2: Backend (Supabase)
- [ ] Crear proyecto Supabase
- [ ] Configurar tablas con RLS
- [ ] Crear Edge Functions para logica de negocio compleja
- [ ] Configurar Storage para archivos
- [ ] Configurar Auth (email + password + OAuth)

### Fase 3: Sync (Offline <-> Online)
- [ ] Implementar `SyncService` con cola de cambios
- [ ] Implementar resolucion de conflictos
- [ ] Agregar indicador de estado de sync en UI

### Fase 4: Multi-Tenancy
- [ ] Onboarding SaaS: registro de negocio + admin
- [ ] Asignacion de `tenant_id` automatico
- [ ] RLS policies en todas las tablas

### Fase 5: Monetizacion
- [ ] Planes: Free (1 usuario), Pro (5 usuarios), Enterprise (ilimitado)
- [ ] Limites por plan (productos, transacciones, almacenamiento)
- [ ] Billing integration (Stripe / local payment gateway)

---

## 5. Riesgos y Mitigaciones

| Riesgo | Impacto | Mitigacion |
|--------|---------|------------|
| Perdida de datos al migrar SQLite -> PostgreSQL | Alto | Script de migracion con backup completo |
| Conflictos de sincronizacion | Medio | Last-write-wins + log de conflictos |
| Latencia de red en POS | Alto | Modo offline-first con sync diferido |
| Costos de Supabase a escala | Medio | Monitoreo de uso + limites por plan |
| Seguridad de datos multi-tenant | Alto | RLS policies + audit log |

---

## 6. Dependencias SaaS (No en el proyecto actual)

```yaml
# pubspec.yaml futuro
dependencies:
  supabase_flutter: ^2.0.0    # Cliente Supabase
  google_sign_in: ^6.0.0      # OAuth Google
  flutter_dotenv: ^5.0.0      # Variables de entorno
  connectivity_plus: ^5.0.0   # Deteccion de red (ya existe)
  sqflite: ^2.3.0             # Mantener para modo offline
```

---

## 7. Decisiones de Diseno Respondidas (Validacion)

Estas 5 preguntas fueron respondidas en sesion previa y validadas como correctas
para el contexto de tienda pequena/mediana en Bolivia:

1. **Tipo de credencial:** PIN numerico de 4-6 digitos en numpad tactil.
2. **Primera ejecucion:** Onboarding forzado donde el admin define su propio PIN.
3. **Visibilidad de ventas:** Filtro jerarquico por user_id (vendedor solo ve lo suyo, admin/gerente ven todo).
4. **Cierre de sesion:** Manual + timeout automatico configurable (15/30/60 min) + cierre forzado al arqueo de caja.
5. **PIN de otros usuarios:** Nunca visible. Solo "Restablecer PIN" por parte del admin.

---

## 8. Preguntas de Diseno Pendientes (Sin Responder)

### 8.1 Plataforma Backend

- **¿Supabase o Firebase?**
  - Supabase: PostgreSQL nativo, RLS, mejor para SaaS multi-tenant, SQL directo.
  - Firebase: NoSQL (Firestore), mas maduro, mejor offline sync, vendor lock-in.
  - Contexto Bolivia: Latencia a servers US ~100ms. Ambos funcionan.

- **¿Self-hosted o Cloud?**
  - Supabase Cloud: Mas rapido de implementar, costos predecibles.
  - Self-hosted (Docker): Mas control, datos en Bolivia (compliance), requiere DevOps.

### 8.2 Sincronizacion

- **¿Real-time (WebSocket) o Batch (polling)?**
  - Real-time: Mas responsivo, mas costoso, mejor para dashboards.
  - Batch: Mas barato, delay aceptable para POS offline-first.

- **¿Que pasa si un usuario vende offline y luego cambia de turno?**
  - Opcion A: Las ventas se asignan al usuario que inicio sesion.
  - Opcion B: Las ventas quedan en cola y se reasignan al hacer login.
  - Opcion C: Bloquear ventas si no hay sync previo.

### 8.3 Multi-Tenancy

- **¿Tenant por empresa o por sucursal?**
  - Por empresa: 1 tenant = 1 negocio, multiples sucursales dentro.
  - Por sucursal: 1 tenant = 1 local fisico, empresa = grupo de tenants.

- **¿Como manejar tiendas que comparten inventario?**
  - Inventario centralizado: sync entre sucursales, posible conflict.
  - Inventario independiente: cada local con su stock.

### 8.4 Autenticacion

- **¿Login con email o solo PIN?**
  - Solo PIN: Rapido, asume dispositivo dedicado al usuario.
  - Email + PIN: Mas seguro, permite login en cualquier dispositivo.
  - Ambos: PIN como fast login en dispositivo conocido, email para nuevo dispositivo.

- **¿2FA obligatorio o opcional?**
  - Obligatorio: Mas seguro, friccion adicional.
  - Opcional: Mejor UX, riesgo de compromiso.
  - Solo admin: Balance entre seguridad y operacion.

### 8.5 Monetizacion

- **¿Modelo freemium, suscripcion, o pago unico?**
  - Freemium: Adquisicion alta, conversion baja.
  - Suscripcion mensual/anual: Recurrente, mejor para SaaS.
  - Pago unico + mantenimiento: Mercado tradicional, menos escalable.

- **¿Integrar pasarela local (PagoFacil, Tigo Money) o Stripe?**
  - Local: Mejor conversion en Bolivia, comision variable.
  - Stripe: Internacional, estable, alto fee.

### 8.6 Regulatorio

- **¿Facturacion electronica (SIN Bolivia)?**
  - Obligatorio desde 2020 para ciertos contribuyentes.
  - Integrar con proveedores de facturacion electronica.
  - Requiere certificacion y homologacion.

- **¿Donde almacenar datos sensibles (NIT, telefonos)?**
  - Cifrado en reposo (AES-256) requerido por ley.
  - Backup cifrado, cumplimiento de Ley 164 (Proteccion de Datos).

### 8.7 Operaciones

- **¿Como manejar actualizaciones de la app?**
  - Forzar actualizacion: Breaking changes obligatorios.
  - Sugerir actualizacion: Friction menor, versionado complejo.
  - Versionado por tenant: Diferentes clientes en distintas versiones.

- **¿Como monitorear errores en produccion?**
  - Sentry / Crashlytics: Captura automatica, alertas.
  - Logs remotos: Debugging profundo, compliance.

- **¿Como escalar durante picos (Black Friday Bolivia)?**
  - Horizontal scaling en Supabase.
  - Cache (Redis) para queries frecuentes.
  - CDN para assets estaticos.
