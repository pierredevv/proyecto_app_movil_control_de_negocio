import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/customer_provider.dart';
import '../../models/customer.dart';
import '../../theme/app_theme.dart';
import 'customer_form_screen.dart';
import 'customer_history_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final TextEditingController _searchController = TextEditingController();

  Future<void> _showPaymentDialog(Customer customer) async {
    final controller = TextEditingController();
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Registrar Pago: ${customer.name}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Monto del Pago (Bs.)',
            prefixText: 'Bs. ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar')),
        ],
      ),
    );

    if (!mounted) return;

    if (shouldSave == true && controller.text.isNotEmpty) {
      final amount = double.tryParse(controller.text);
      if (amount != null && amount > 0) {
        if (!mounted) return;
        try {
          await context
              .read<CustomerProvider>()
              .addPayment(customer.id!, amount);
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pago registrado exitosamente')),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.watch<CustomerProvider>().isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final customers = context.watch<CustomerProvider>().filteredCustomers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar cliente...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          context.read<CustomerProvider>().setSearchQuery('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
              onChanged: (value) {
                context.read<CustomerProvider>().setSearchQuery(value);
                setState(() {});
              },
            ),
          ),
        ),
      ),
      body: customers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No hay clientes',
                    style: TextStyle(color: Colors.grey[600]),
                  )
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: customers.length,
              itemBuilder: (context, index) {
                final customer = customers[index];
                final hasDebt = customer.totalDebt > 0;

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          AppTheme.secondary.withValues(alpha: 0.1),
                      child: Text(
                        customer.name[0].toUpperCase(),
                        style: const TextStyle(
                            color: AppTheme.secondary,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      customer.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (customer.phone != null)
                          Text('${customer.phone}',
                              style: const TextStyle(fontSize: 12)),
                        if (hasDebt)
                          Text(
                            'Deuda: Bs. ${customer.totalDebt.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (customer.phone != null &&
                            customer.phone!.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.phone,
                                color: AppTheme.secondary),
                            onPressed: () {
                              context
                                  .read<CustomerProvider>()
                                  .makePhoneCall(customer.phone!);
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.monetization_on,
                              color: Colors.green),
                          tooltip: 'Registrar Pago',
                          onPressed: () => _showPaymentDialog(customer),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _navigateToForm(context, customer);
                            } else if (value == 'history') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => CustomerHistoryScreen(
                                        customerId: customer.id!)),
                              );
                            }
                          },
                          itemBuilder: (BuildContext context) =>
                              <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'edit',
                              child: Text('Editar'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'history',
                              child: Text('Ver Historial'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    onTap: () => _navigateToForm(context, customer),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToForm(context, null),
        child: const Icon(Icons.person_add),
      ),
    );
  }

  void _navigateToForm(BuildContext context, Customer? customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerFormScreen(customer: customer),
      ),
    );
  }
}
