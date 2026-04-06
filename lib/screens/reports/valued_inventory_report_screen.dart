import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../theme/app_theme.dart';
import 'dart:io';

class ValuedInventoryReportScreen extends StatelessWidget {
  const ValuedInventoryReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Force a UI update if the products change
    final inventory = context.watch<InventoryProvider>();
    final products = inventory.products;

    // Filter out products with 0 stock to avoid clutter, or keep them? Usually kept to be transparent, or filtered if requested. Let's keep stock > 0 for valued inventory.
    final valuedProducts = products.where((p) => p.stock > 0).toList()
      ..sort((a, b) => (b.stock * b.cost).compareTo(a.stock * a.cost)); // Sort by largest value

    final totalCapital = valuedProducts.fold(0.0, (sum, p) => sum + (p.stock * p.cost));

    return Scaffold(
      backgroundColor: const Color(0xFF151924),
      appBar: AppBar(
        title: const Text('Inventario Valorado'),
        backgroundColor: const Color(0xFF1E2432),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Summary Card
          Padding(
             padding: const EdgeInsets.all(16.0),
             child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2432),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    const Text('Capital Total Invertido', style: TextStyle(color: Colors.white70, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Bs. ${totalCapital.toStringAsFixed(2)}', 
                        style: const TextStyle(color: AppTheme.blueIcon, fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Text('${valuedProducts.length} Productos con Stock', style: const TextStyle(color: Colors.white54)),
                  ],
                ),
             ),
          ),

          // Search / Filter could go here 

          // List
          Expanded(
            child: valuedProducts.isEmpty
                ? const Center(child: Text('No hay productos en inventario con stock mayor a 0.', style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: valuedProducts.length,
                    itemBuilder: (context, index) {
                      final p = valuedProducts[index];
                      final value = p.stock * p.cost;
                      
                      return Card(
                        color: const Color(0xFF1E2432),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                  image: (p.imagePath != null && p.imagePath!.isNotEmpty)
                                      ? DecorationImage(
                                          image: FileImage(File(p.imagePath!)),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: (p.imagePath != null && p.imagePath!.isNotEmpty)
                                    ? null
                                    : Center(
                                        child: Text(
                                          p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                                          style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 20),
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text('Stock: ${p.stock.toStringAsFixed(1)} ${p.saleUnit} | Costo: Bs. ${p.cost.toStringAsFixed(2)}', 
                                      style: const TextStyle(color: Colors.white54, fontSize: 13)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Valor Total', style: TextStyle(color: Colors.white54, fontSize: 10)),
                                  const SizedBox(height: 2),
                                  Text('Bs. ${value.toStringAsFixed(2)}', 
                                    style: const TextStyle(color: AppTheme.blueIcon, fontWeight: FontWeight.bold, fontSize: 15)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
