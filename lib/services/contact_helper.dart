import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart'; // Add to pubspec.yaml

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
        backgroundColor: Colors.transparent, // Required for Glassmorphism
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
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
              color: Colors.white.withValues(alpha: 0.10), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 20,
            offset: const Offset(0, -8),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Column(
            children: [
              // HANDLE
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.30),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // HEADER
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Seleccionar Contacto',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      highlightColor: Colors.white.withValues(alpha: 0.10),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // SEARCH FIELD
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08), width: 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: TextField(
                        controller: _searchController,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: const InputDecoration(
                          hintText: 'Buscar nombre...',
                          hintStyle:
                              TextStyle(color: AppTheme.textTertiary, fontSize: 15),
                          prefixIcon: Icon(Icons.search,
                              color: AppTheme.textSecondary, size: 20),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        onChanged: _filter,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // LIST
              Expanded(
                child: _filteredContacts.isEmpty
                    ? Center(
                        child: Text('No se encontraron contactos',
                            style: TextStyle(color: Colors.grey[400])))
                    : ListView.separated(
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        itemCount: _filteredContacts.length,
                        separatorBuilder: (context, index) => Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.05),
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        itemBuilder: (context, index) {
                          final contact = _filteredContacts[index];
                          final phone = contact.phones.isNotEmpty
                              ? contact.phones.first.number
                              : 'Sin teléfono';
                          final email = contact.emails.isNotEmpty
                              ? contact.emails.first.address
                              : null;

                          Widget item = _AnimatedContactItem(
                            contactName: contact.displayName,
                            phone: phone,
                            email: email,
                            onTap: () => Navigator.pop(context, contact),
                          );

                          // Animate the first 8 items
                          if (index < 8) {
                            return item
                                .animate()
                                .fade(duration: 300.ms, delay: (index * 50).ms)
                                .slideY(
                                    begin: 0.1,
                                    end: 0,
                                    duration: 300.ms,
                                    delay: (index * 50).ms);
                          }
                          return item;
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .slideY(begin: 1.0, end: 0, duration: 350.ms, curve: Curves.easeOut);
  }
}

class _AnimatedContactItem extends StatefulWidget {
  final String contactName;
  final String phone;
  final String? email;
  final VoidCallback onTap;

  const _AnimatedContactItem({
    required this.contactName,
    required this.phone,
    this.email,
    required this.onTap,
  });

  @override
  State<_AnimatedContactItem> createState() => _AnimatedContactItemState();
}

class _AnimatedContactItemState extends State<_AnimatedContactItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.diagonal3Values(
            _isPressed ? 0.98 : 1.0, _isPressed ? 0.98 : 1.0, 1.0),
        transformAlignment: Alignment.center,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _isPressed
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.redAccent.withValues(alpha: 0.80),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.person, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.contactName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.phone,
                    style:
                        const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ),
                  if (widget.email != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.email!,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
