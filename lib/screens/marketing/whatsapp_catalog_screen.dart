import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/product.dart';
import 'dart:ui' as ui;

class WhatsAppCatalogScreen extends StatefulWidget {
  const WhatsAppCatalogScreen({super.key});

  @override
  State<WhatsAppCatalogScreen> createState() => _WhatsAppCatalogScreenState();
}

class _WhatsAppCatalogScreenState extends State<WhatsAppCatalogScreen> {
  String _catalogText = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateCatalog();
    });
  }

  void _generateCatalog() {
    final products = context.read<InventoryProvider>().products;
    final profile = context.read<SettingsProvider>().profile;
    
    final StringBuffer buffer = StringBuffer();
    
    buffer.writeln('🏪 *${profile.businessName.isNotEmpty ? profile.businessName : "Nuestro Catálogo"}* 🏪');
    buffer.writeln('===========================');
    buffer.writeln('');
    
    // Group products by category (optional, but nice)
    Map<int, List<Product>> byCategory = {};
    for (var p in products) {
      final catId = p.categoryId ?? -1;
      if (!byCategory.containsKey(catId)) {
        byCategory[catId] = [];
      }
      byCategory[catId]!.add(p);
    }

    final categories = context.read<InventoryProvider>().categories;

    for (var entry in byCategory.entries) {
      final catId = entry.key;
      final catProducts = entry.value;
      if (catProducts.isEmpty) continue;

      String catName = 'Sin Categoría';
      if (catId != -1) {
        final match = categories.where((c) => c.id == catId).firstOrNull;
        if (match != null) catName = match.name;
      }

      buffer.writeln('📦 *$catName*');
      for (var p in catProducts) {
        buffer.writeln('  ▫️ ${p.name}');
        buffer.writeln('      Precio: Bs. ${p.price.toStringAsFixed(2)} por ${p.saleUnit}');
        // Optional: display stock status or variations
      }
      buffer.writeln('');
    }

    buffer.writeln('===========================');
    buffer.writeln('Para hacer pedidos, contáctanos:');
    if (profile.phone.isNotEmpty) buffer.writeln('📞 ${profile.phone}');
    if (profile.address.isNotEmpty) buffer.writeln('📍 ${profile.address}');
    
    setState(() {
      _catalogText = buffer.toString();
    });
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _catalogText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Catálogo copiado al portapapeles'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF151924),
      appBar: AppBar(
        title: const Text('Catálogo WhatsApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
                ),
              ),
            ),
          ),
          Positioned(
            top: 50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: const Color(0xFF51CF66).withValues(alpha: 0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: const Color(0xFF51CF66).withValues(alpha: 0.2), blurRadius: 100, spreadRadius: 20),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   const Text(
                    'Vista Previa del Catálogo',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.5),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              _catalogText,
                              style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _generateCatalog,
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text('Actualizar', style: TextStyle(color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(colors: [Color(0xFF51CF66), Color(0xFF69DB7C)]),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _copyToClipboard,
                            icon: const Icon(Icons.copy, color: Colors.white),
                            label: const Text('Copiar Texto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
