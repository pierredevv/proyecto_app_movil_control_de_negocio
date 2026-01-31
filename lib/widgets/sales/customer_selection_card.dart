import 'package:flutter/material.dart';
import '../../models/customer.dart';

class CustomerSelectionCard extends StatelessWidget {
  final Customer? selectedCustomer;
  final List<Customer> customers;
  final ValueChanged<Customer?> onChanged;

  const CustomerSelectionCard({
    super.key,
    required this.selectedCustomer,
    required this.customers,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : theme.colorScheme.outline),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: selectedCustomer?.id,
          hint: Text(
            'Cliente: Público General',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          dropdownColor: theme.cardColor,
          icon: Icon(Icons.keyboard_arrow_down,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
          isExpanded: true,
          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text('Cliente: Público General',
                  style: TextStyle(color: theme.colorScheme.onSurface)),
            ),
            ...customers.map((c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(c.name,
                      style: TextStyle(color: theme.colorScheme.onSurface)),
                )),
          ],
          onChanged: (id) {
            if (id == null) {
              onChanged(null);
            } else {
              final c = customers.firstWhere((c) => c.id == id);
              onChanged(c);
            }
          },
        ),
      ),
    );
  }
}
