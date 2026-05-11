import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class MarginCalculatorScreen extends StatefulWidget {
  const MarginCalculatorScreen({super.key});

  @override
  State<MarginCalculatorScreen> createState() => _MarginCalculatorScreenState();
}

class _MarginCalculatorScreenState extends State<MarginCalculatorScreen> {
  final Color moduleColor = const Color(0xFFF5A623); // Orange

  final TextEditingController _costController = TextEditingController();
  final TextEditingController _sellController = TextEditingController();
  final TextEditingController _targetMarginController = TextEditingController();

  double _netProfit = 0.0;
  double _profitMargin = 0.0;
  double _marginOnCost = 0.0;
  double _suggestedPrice = 0.0;

  @override
  void initState() {
    super.initState();
    _costController.addListener(_calculate);
    _sellController.addListener(_calculate);
    _targetMarginController.addListener(_calculate);
  }

  @override
  void dispose() {
    _costController.dispose();
    _sellController.dispose();
    _targetMarginController.dispose();
    super.dispose();
  }

  void _calculate() {
    final cost = double.tryParse(_costController.text) ?? 0.0;
    final sell = double.tryParse(_sellController.text) ?? 0.0;
    final targetMargin = double.tryParse(_targetMarginController.text) ?? 0.0;

    setState(() {
      _netProfit = sell - cost;

      if (sell > 0) {
        _profitMargin = (_netProfit / sell) * 100;
      } else {
        _profitMargin = 0.0;
      }

      if (cost > 0) {
        _marginOnCost = (_netProfit / cost) * 100;
        if (targetMargin > 0 && targetMargin < 100) {
          _suggestedPrice = cost / (1 - (targetMargin / 100));
        } else {
          _suggestedPrice = 0.0;
        }
      } else {
        _marginOnCost = 0.0;
        _suggestedPrice = 0.0;
      }
    });
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08), width: 1.5),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller,
      {String prefix = ''}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFFA0A8C1),
                fontSize: 13,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixText: prefix,
              prefixStyle: const TextStyle(color: Colors.white70, fontSize: 16),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultRow(String title, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Flexible(
            child: Text(
              title,
              style: const TextStyle(color: Color(0xFFA0A8C1), fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: highlight ? moduleColor : Colors.white,
                fontSize: highlight ? 20 : 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF151924),
      appBar: AppBar(
        title: const Text('Calculadora de Margen',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_note, color: moduleColor, size: 24),
                      const SizedBox(width: 8),
                      const Text('Valores Base',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildInputField('Costo (\$) *', _costController,
                      prefix: '\$ '),
                  const SizedBox(height: 16),
                  _buildInputField('Precio de Venta (\$) *', _sellController,
                      prefix: '\$ '),
                  const SizedBox(height: 16),
                  _buildInputField(
                      'Margen Esperado (%) - Opcional', _targetMarginController,
                      prefix: '% '),
                ],
              ),
            ),
            _buildGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.analytics, color: moduleColor, size: 24),
                      const SizedBox(width: 8),
                      const Text('Resultados',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildResultRow(
                      'Ganancia Neta:', '\$${_netProfit.toStringAsFixed(2)}',
                      highlight: true),
                  const Divider(color: Colors.white12, height: 24),
                  _buildResultRow('Margen de Ganancia (sobre venta):',
                      '${_profitMargin.toStringAsFixed(2)}%'),
                  const SizedBox(height: 4),
                  _buildResultRow('Markup (sobre costo):',
                      '${_marginOnCost.toStringAsFixed(2)}%'),
                  const Divider(color: Colors.white12, height: 24),
                  _buildResultRow(
                      'Precio Sugerido (meta):',
                      _suggestedPrice > 0
                          ? '\$${_suggestedPrice.toStringAsFixed(2)}'
                          : '-',
                      highlight: _suggestedPrice > 0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
