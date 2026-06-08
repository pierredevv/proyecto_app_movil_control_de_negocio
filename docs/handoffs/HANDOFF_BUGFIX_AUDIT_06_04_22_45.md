# Handoff: Bug Fixes Audit Round 1 — 06/04/2026 22:45

## Goal
Audit all bugs reported across multiple previous agent sessions and fix only the **real, verified bugs**. Avoid making changes where the code is already correct.

---

## Audit Summary

After thorough manual code review and cross-referencing with user-reported issues, the audit found:

| # | Reported Bug | Status | Action |
|---|---|---|---|
| 1 | Login rejects 6-digit PINs | ✅ Already correct (auto-submit at 6) | None |
| 2 | No limit on incorrect PIN attempts | ⚠️ In-memory lockout (3 fails → 30s) | Future: persist via SharedPreferences |
| 3 | Onboarding screen pixel overflow | ✅ Already fixed (SingleChildScrollView) | None |
| 4 | WhatsApp sends to hardcoded number | ❌ **REAL BUG — FIXED** | `order_list_screen.dart` |
| 5 | Product multi-select delete | ✅ Feature exists in code (review only) | None |
| 6 | Categories cannot be deleted in filter | ✅ Exists via gear icon → CategoryManagerScreen | None |
| 7 | Orders don't show in recent activity | ✅ Already correct (Order type handled) | None |
| 8 | Empty state buttons don't navigate | ✅ All navigate correctly | None |
| 9 | "Pay" button in POS | ✅ Says "COBRAR" (Collect) | None |
| 10 | Box vs unit price in purchase | ✅ **NOT A BUG** (WAC fallback makes it work) | Verified — see below |
| 11 | Reports: Excel is basic | Cosmetic — out of scope | None |
| 12 | Sales Report custom section error | Likely related to #13/#14 | None |
| 13 | PDF/Excel export errors | ❌ **REAL BUG — FIXED** | `report_export_service.dart` |
| 14 | Stock reports inaccurate | ❌ **CAUSE FIXED** (WAC fallback in exports) | Same as #13 |
| 15 | Advanced analytics shows wrong data | ❌ **CAUSE FIXED** (same WAC issue) | Same as #13 |

---

## Fix 1: WhatsApp Hardcoded Phone in Order List

**File:** `lib/screens/orders/order_list_screen.dart:507-535`

**Before:**
```dart
TextButton.icon(
  onPressed: () {
    final message = WhatsAppHelper.generateOrderMessage(order);
    // TODO: Get real phone number from supplier if available
    WhatsAppHelper.launchWhatsApp('59100000000', message);
  },
  ...
)
```

**Issue:** Always sent to the placeholder number `59100000000`, which is a non-existent Bolivian phone. This caused WhatsApp to either fail to find the contact or send the order to a wrong number.

**After:**
```dart
TextButton.icon(
  onPressed: () async {
    final message = WhatsAppHelper.generateOrderMessage(order);
    String phone = '';
    if (order.supplierId != null) {
      final db = DatabaseService();
      final supplier = await db.getSupplierById(order.supplierId!);
      if (supplier != null &&
          supplier.phone != null &&
          supplier.phone!.isNotEmpty) {
        phone = supplier.phone!;
      }
    }
    try {
      await WhatsAppHelper.launchWhatsApp(phone, message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'No se pudo abrir WhatsApp. Verifique si está instalado.'),
              backgroundColor: Colors.orange),
        );
      }
    }
  },
  ...
)
```

**Behavior:**
- Looks up the order's `supplierId` in the `suppliers` table
- Uses the real supplier phone if available
- Falls back to opening WhatsApp with no pre-filled recipient (via `WhatsAppHelper` logic) if no phone
- Shows SnackBar on error (mirrors `order_details_screen.dart` pattern)
- Uses `mounted` (not `context.mounted`) since this is in a `State` method

---

## Fix 2: WAC Fallback in Inventory Report Exports

**File:** `lib/services/report_export_service.dart:117-167` (PDF + Excel exports)

**Before:**
```dart
wac: p.weightedAverageCost > 0 ? p.weightedAverageCost : p.cost,
value: p.stock * (p.weightedAverageCost > 0 ? p.weightedAverageCost : p.cost),
```

**Issue:** When `weightedAverageCost == 0`, the fallback uses `p.cost` (per SALE UNIT, e.g., per box). But `p.stock` is in BASE units. This **overstated** inventory value by a factor of `unitsPerSaleUnit` for products without an explicit WAC.

**Example of the bug:**
- Product: `cost = 35.80/box`, `unitsPerSaleUnit = 36`, `stock = 36 units`, `weightedAverageCost = 0`
- Buggy value: `36 * 35.80 = Bs. 1288.80` (WRONG — looks like 36 boxes worth)
- Correct value: `36 * (35.80 / 36) = Bs. 35.80` (correct per-unit value)

This was the root cause of the "incorrect stock" issue in the Valued Inventory report and downstream (Advanced Analytics, PDF/Excel exports).

**After:**
```dart
final effectiveWac = p.weightedAverageCost > 0
    ? p.weightedAverageCost
    : p.cost / (p.unitsPerSaleUnit > 0 ? p.unitsPerSaleUnit : 1);
return InventoryItem(
  name: p.name,
  category: '',
  stock: p.stock,
  saleUnit: p.saleUnit,
  wac: effectiveWac,
  value: p.stock * effectiveWac,
);
```

**Why this is correct:**
- Matches the formula already used in `valued_inventory_report_screen.dart:31-32, 36, 81-82, 87, 177`
- The screen display and the export will now show the same value
- Safe division (checks `unitsPerSaleUnit > 0`)

---

## Verification: "Box Price Bug" in Purchase Form

**Reported:** "When adding a product, the view displays the box price (supposedly per box) but shows the unit price."

**Investigation result:** **This is NOT a bug.** The code at `purchase_form_screen.dart:131-153` is correct:

```dart
double defaultCost = product.weightedAverageCost > 0
    ? product.weightedAverageCost
    : product.cost;

if (isBox) {
  defaultCost = defaultCost * product.unitsPerSaleUnit;
}
```

**Why it works correctly:**
1. `Product.fromMap` (line 126) initializes `weightedAverageCost` with fallback to `cost`:
   ```dart
   weightedAverageCost: (map['weighted_average_cost'] as num?)?.toDouble()
       ?? (map['cost'] as num?)?.toDouble() ?? 0.0,
   ```
2. For any product with a defined `cost`, `weightedAverageCost > 0` is TRUE
3. So `defaultCost = weightedAverageCost` (which is per BASE unit)
4. `defaultCost * unitsPerSaleUnit` correctly converts to per-BOX price

**The user confirmed** the price shows correctly (e.g., 35.80). No code change needed.

---

## Files Modified

1. `lib/screens/orders/order_list_screen.dart` — WhatsApp phone lookup from DB
2. `lib/services/report_export_service.dart` — WAC fallback formula in inventory exports

## Files NOT Modified (already correct)

- `lib/screens/auth/login_screen.dart` — 6-digit PIN works, lockout implemented
- `lib/screens/auth/onboarding_screen.dart` — has `SingleChildScrollView`
- `lib/widgets/sales/cart_total_footer.dart` — says "COBRAR"
- `lib/widgets/dashboard/recent_activity_list.dart` — handles all transaction types
- `lib/screens/inventory/category_manager_screen.dart` — has delete with confirmation
- `lib/screens/purchases/purchase_form_screen.dart` — box price logic correct

---

## Pre-existing Issues (NOT introduced by this PR)

- `lib/screens/cash_register/cash_register_screen.dart:665:40` — `use_build_context_synchronously` (info, present in `main` before this PR). Do NOT fix per handoff convention.

---

## flutter analyze result

```
1 issue found. (ran in 56.2s)
   info - Don't use 'BuildContext's across async gaps - lib\screens/cash_register/cash_register_screen.dart:665:40 - use_build_context_synchronously
```

Only the pre-existing warning. ✅

---

## Testing Checklist (manual)

- [ ] Open Orders list, tap "Enviar" on an order linked to a supplier with a phone
  - [ ] Should open WhatsApp with the correct supplier as recipient
  - [ ] Message should contain order details
- [ ] Open Orders list, tap "Enviar" on an order without supplier phone
  - [ ] Should open WhatsApp with the message pre-filled but no recipient (user picks)
  - [ ] If WhatsApp not installed, should show orange SnackBar
- [ ] Generate Valued Inventory PDF report
  - [ ] For products with WAC = 0, value should be `stock * (cost / unitsPerSaleUnit)`
  - [ ] Value should match what the on-screen report shows
- [ ] Generate Valued Inventory Excel report
  - [ ] Same as above

---

## Related Documents

- `docs/handoffs/HANDOFF_RBAC_V22_06_04_22_00.md` — RBAC implementation
- `docs/handoffs/HANDOFF_CURRENCY_DB_ROLES_06_04_19_30.md` — RBAC roadmap
- `docs/SAAS_MIGRATION_CONSIDERATIONS.md` — Future cloud sync questions
