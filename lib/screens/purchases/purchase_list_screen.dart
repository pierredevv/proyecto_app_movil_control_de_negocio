import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/transaction_model.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../../widgets/common/glass_transaction_card.dart';
import '../../widgets/common/skeleton_list.dart';
import 'purchase_form_screen.dart';
import 'purchase_details_screen.dart';

class PurchaseListScreen extends StatefulWidget {
  const PurchaseListScreen({super.key});

  @override
  State<PurchaseListScreen> createState() => _PurchaseListScreenState();
}

class _PurchaseListScreenState extends State<PurchaseListScreen> {
  final DatabaseService _db = DatabaseService();
  bool _isLoading = true;
  List<Purchase> _purchases = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPurchases();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPurchases() async {
    setState(() => _isLoading = true);
    try {
      final data = await _db.getPurchases();
      if (mounted) {
        setState(() {
          _purchases = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar compras: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0F172A),
                    const Color(0xFF1E293B),
                    const Color(0xFF0F172A),
                  ]
                : [
                    const Color(0xFFF8FAFC),
                    const Color(0xFFE2E8F0),
                    const Color(0xFFF1F5F9),
                  ],
          ),
        ),
        child: Stack(
          children: [
            // Background Elements (Blobs)
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                      blurRadius: 100,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              left: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.secondary.withValues(alpha: 0.2),
                      blurRadius: 80,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),

            CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Glass App Bar
                SliverAppBar(
                  floating: true,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: isDark
                      ? const Color(0xFF0F172A).withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.7),
                  iconTheme: IconThemeData(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  centerTitle: false,
                  title: Text(
                    'Compras Registradas',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  actions: [
                    IconButton(
                        onPressed: _loadPurchases,
                        icon: Icon(Icons.refresh,
                            color: isDark ? Colors.white : Colors.black87)),
                  ],
                ),

                // Content
                if (_isLoading)
                  const SliverToBoxAdapter(
                    child: SkeletonList(padding: EdgeInsets.all(16)),
                  )
                else if (_purchases.isEmpty)
                  SliverFillRemaining(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_bag_outlined,
                            size: 80,
                            color: isDark ? Colors.white12 : Colors.black12),
                        const SizedBox(height: 16),
                        Text(
                          'No hay compras registradas',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Registra tus gastos de inventario aquí',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ).animate().fadeIn().scale(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final purchase = _purchases[index];
                          return GlassTransactionCard(
                            title: purchase.supplierName ?? 'Proveedor General',
                            subtitle: DateFormat('dd/MM/yyyy HH:mm')
                                .format(purchase.date),
                            amount: purchase.totalAmount,
                            status: purchase.status,
                            color: AppTheme.secondary, // Purchases are Orange
                            icon: Icons.shopping_cart_outlined,
                            isOrder: false,
                            heroTag: 'purchase_${purchase.id}_icon',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      PurchaseDetailsScreen(purchase: purchase),
                                ),
                              );
                            },
                          ).animate().fadeIn(duration: 400.ms).slideY(
                                begin: 0.2,
                                end: 0,
                                curve: Curves.easeOutQuad,
                                delay: (50 * index).ms, // Staggered
                              );
                        },
                        childCount: _purchases.length,
                      ),
                    ),
                  ),
                // Bottom Padding for FAB
                const SliverToBoxAdapter(
                  child: SizedBox(height: 80),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PurchaseFormScreen()),
          );
          if (result == true) {
            _loadPurchases();
          }
        },
        backgroundColor: const Color(0xFFEF5350),
        label:
            const Text('Nueva Compra', style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
