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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1), // Glass effect
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: selectedCustomer?.id,
          hint: const Text(
            'Cliente: Público General',
            style: TextStyle(color: Colors.white),
          ),
          dropdownColor: const Color(0xFF1E2432), // Dark bg for dropdown
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
          isExpanded: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('Cliente: Público General'),
            ),
            ...customers.map((c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(c.name),
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
