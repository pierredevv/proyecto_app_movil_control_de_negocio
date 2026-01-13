import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart'; // Add to pubspec.yaml

class ContactHelper {
  // ✅ Request permissions with complete case handling
  static Future<Contact?> pickPhoneContact(BuildContext context) async {
    try {
      // 1. Verify if we already have permission
      PermissionStatus status = await Permission.contacts.status;

      if (status.isDenied) {
        // 2. Request permission
        status = await Permission.contacts.request();
      }

      if (status.isPermanentlyDenied) {
        // 3. User permanently denied - lead to settings
        if (context.mounted) {
          final shouldOpenSettings = await _showPermissionDeniedDialog(context);
          if (shouldOpenSettings == true) {
            await openAppSettings();
          }
        }
        return null;
      }

      if (status.isDenied || status.isRestricted) {
        // 4. User denied or restricted
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Se necesita permiso para acceder a los contactos',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return null;
      }

      // 5. Permission granted - get contacts
      if (!context.mounted) return null;

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando contactos...'),
                ],
              ),
            ),
          ),
        ),
      );

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      // Close loading
      if (context.mounted) Navigator.pop(context);

      if (!context.mounted) return null;

      if (contacts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontraron contactos en tu dispositivo'),
          ),
        );
        return null;
      }

      // 6. Show selector
      return await showModalBottomSheet<Contact>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => _ContactPickerSheet(contacts: contacts),
      );
    } catch (e) {
      debugPrint('Error al acceder a contactos: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar contactos: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      return null;
    }
  }

  // ✅ Dialog for permanently denied permissions
  static Future<bool?> _showPermissionDeniedDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('Permiso Requerido'),
          ],
        ),
        content: const Text(
          'Para importar contactos, necesitas habilitar el permiso de contactos '
          'en la configuración de tu dispositivo.\n\n'
          '¿Deseas abrir la configuración ahora?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abrir Configuración'),
          ),
        ],
      ),
    );
  }
}

class _ContactPickerSheet extends StatefulWidget {
  final List<Contact> contacts;

  const _ContactPickerSheet({required this.contacts});

  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  late List<Contact> _filteredContacts;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredContacts = widget.contacts;
  }

  void _filter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = widget.contacts;
      } else {
        final lower = query.toLowerCase();
        _filteredContacts = widget.contacts
            .where((c) => c.displayName.toLowerCase().contains(lower))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Seleccionar Contacto',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Buscar nombre...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: _filter,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _filteredContacts.isEmpty
                ? const Center(child: Text('No se encontraron contactos'))
                : ListView.builder(
                    itemCount: _filteredContacts.length,
                    itemBuilder: (context, index) {
                      final contact = _filteredContacts[index];
                      final phone = contact.phones.isNotEmpty
                          ? contact.phones.first.number
                          : 'Sin teléfono';
                      final email = contact.emails.isNotEmpty
                          ? contact.emails.first.address
                          : null;

                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(contact.displayName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(phone, style: const TextStyle(fontSize: 12)),
                            if (email != null)
                              Text(
                                email,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey),
                              ),
                          ],
                        ),
                        onTap: () => Navigator.pop(context, contact),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
