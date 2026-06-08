import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';


class WhatsAppHelper {
  static Future<void> launchWhatsApp(String phone, String message) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    final isValidPhone = cleanPhone.length > 5 && !RegExp(r'^[0+]+$').hasMatch(cleanPhone);

    final uriStr = isValidPhone
        ? 'whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent(message)}'
        : 'whatsapp://send?text=${Uri.encodeComponent(message)}';
    
    final uri = Uri.parse(uriStr);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback for web or if whatsapp scheme fails
      final webUriStr = isValidPhone
          ? 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}'
          : 'https://wa.me/?text=${Uri.encodeComponent(message)}';
      final webUri = Uri.parse(webUriStr);
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (e) {
        throw 'Could not launch WhatsApp';
      }
    }
  }

  static String generateOrderMessage(Order order) {
    final buffer = StringBuffer();
    final dateStr = DateFormat('dd/MM/yyyy').format(order.date);

    buffer.writeln('📋 *NUEVO PEDIDO*');
    buffer.writeln('📅 Fecha: $dateStr');
    if (order.supplierName != null) {
      buffer.writeln('👤 Proveedor: ${order.supplierName}');
    }
    buffer.writeln('');
    buffer.writeln('📦 *PRODUCTOS SOLICITADOS:*');
    buffer.writeln('');

    for (var item in order.items) {
      buffer.writeln('▪️ *${item.productName}*');
      buffer.writeln('   Cant: ${item.quantity.toStringAsFixed(0)} ${item.saleUnit}');
    }

    buffer.writeln('');
    if (order.deliveryDate != null) {
      final deliveryStr = DateFormat('dd/MM/yyyy HH:mm').format(order.deliveryDate!);
      buffer.writeln('🚚 Entrega solicitada para: $deliveryStr');
      buffer.writeln('');
    }

    buffer.writeln('Por favor confirmar la recepción de este pedido. ¡Gracias!');

    return buffer.toString();
  }
}
