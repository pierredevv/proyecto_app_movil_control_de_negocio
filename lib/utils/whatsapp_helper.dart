import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';

class WhatsAppHelper {
  static Future<void> launchWhatsApp(String phone, String message) async {
    // Basic cleanup of phone number
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');

    final uri = Uri.parse(
      'whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent(message)}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback for web or if whatsapp scheme fails
      final webUri = Uri.parse(
        'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
      );
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri);
      } else {
        throw 'Could not launch WhatsApp';
      }
    }
  }

  static String generateOrderMessage(Order order) {
    final buffer = StringBuffer();
    final dateStr = DateFormat('dd/MM/yyyy').format(order.date);

    buffer.writeln('📋 *NUEVO PEDIDO*');
    buffer.writeln('📅 Fecha: $dateStr');
    buffer.writeln('👤 Proveedor: ${order.supplierName ?? "General"}');
    buffer.writeln('');
    buffer.writeln('📦 *DETALLE DEL PEDIDO:*');

    for (var item in order.items) {
      buffer.writeln(
          '- ${item.quantity.toStringAsFixed(0)} ${item.saleUnit} x ${item.productName}');
    }

    buffer.writeln('');
    if (order.deliveryDate != null) {
      final deliveryStr = DateFormat('dd/MM/yyyy').format(order.deliveryDate!);
      buffer.writeln('🚚 Entrega estimada: $deliveryStr');
    }

    buffer.writeln(
        '💰 *Total Estimado: Bs. ${order.totalAmount.toStringAsFixed(2)}*');
    buffer.writeln('');
    buffer.writeln(
        'Por favor confirmar disponibilidad y fecha de entrega. Gracias!');

    return buffer.toString();
  }
}
