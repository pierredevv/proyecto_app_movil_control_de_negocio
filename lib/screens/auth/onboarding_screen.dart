import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pin_pad.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _usernameCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _usernameFormKey = GlobalKey<FormState>();
  String _step = 'form';
  String _firstPin = '';
  String _confirmPin = '';
  String? _pinError;
  bool _submitting = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _onFormSubmit() async {
    if (!_usernameFormKey.currentState!.validate()) return;
    if (_usernameCtrl.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario debe tener al menos 3 caracteres')),
      );
      return;
    }
    setState(() => _step = 'pin');
  }

  void _onPinKey(String key) {
    setState(() {
      _pinError = null;
      if (key == 'DEL') {
        if (_step == 'pin') {
          if (_firstPin.isNotEmpty) _firstPin = _firstPin.substring(0, _firstPin.length - 1);
        } else if (_step == 'pin_confirm') {
          if (_confirmPin.isNotEmpty) {
            _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
          } else {
            _step = 'pin';
            if (_firstPin.isNotEmpty) _firstPin = _firstPin.substring(0, _firstPin.length - 1);
          }
        }
        return;
      }

      if (key == 'OK') {
        if (_step == 'pin') {
          if (_firstPin.length >= 4) {
            _step = 'pin_confirm';
          } else {
            _pinError = 'PIN debe tener al menos 4 dígitos';
          }
        } else if (_step == 'pin_confirm') {
          if (_confirmPin.length >= 4) {
            _submitPin();
          }
        }
        return;
      }

      if (_step == 'pin') {
        if (_firstPin.length < 6) {
          _firstPin += key;
          if (_firstPin.length == 6) {
            Future.delayed(const Duration(milliseconds: 150), () {
              if (mounted) setState(() => _step = 'pin_confirm');
            });
          }
        }
      } else if (_step == 'pin_confirm') {
        if (_confirmPin.length < 6) {
          _confirmPin += key;
          if (_confirmPin.length == _firstPin.length) {
            _submitPin();
          }
        }
      }
    });
  }

  Future<void> _submitPin() async {
    if (_firstPin != _confirmPin) {
      setState(() {
        _pinError = 'Los PINs no coinciden';
        _firstPin = '';
        _confirmPin = '';
      });
      return;
    }
    if (_firstPin.length < 4) {
      setState(() {
        _pinError = 'PIN debe tener al menos 4 dígitos';
        _firstPin = '';
        _confirmPin = '';
      });
      return;
    }

    setState(() => _submitting = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.completeOnboarding(
      username: _usernameCtrl.text,
      displayName: _displayNameCtrl.text,
      pin: _firstPin,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _submitting = false;
        _pinError = auth.lastError ?? 'Error al crear usuario';
        _firstPin = '';
        _confirmPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      body: SafeArea(
        child: _step == 'form' ? _buildForm() : _buildPinStep(),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _usernameFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            const Icon(
              Icons.store_mall_directory,
              size: 80,
              color: AppTheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Bienvenido',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Configura tu cuenta de administrador',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 40),
            TextFormField(
              controller: _usernameCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Usuario',
                hintText: 'ej: admin',
                prefixIcon: Icon(Icons.person, color: AppTheme.textSecondary),
                labelStyle: TextStyle(color: AppTheme.textSecondary),
                hintStyle: TextStyle(color: AppTheme.textTertiary),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingresa un usuario';
                if (v.trim().length < 3) return 'Mínimo 3 caracteres';
                return null;
              },
              autocorrect: false,
              textCapitalization: TextCapitalization.none,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _displayNameCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Nombre completo',
                hintText: 'ej: Juan Pérez',
                prefixIcon: Icon(Icons.badge, color: AppTheme.textSecondary),
                labelStyle: TextStyle(color: AppTheme.textSecondary),
                hintStyle: TextStyle(color: AppTheme.textTertiary),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingresa tu nombre';
                return null;
              },
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _onFormSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continuar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinStep() {
    final confirming = _step == 'pin_confirm';
    final dots = confirming ? _confirmPin.length : _firstPin.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Icon(
            Icons.lock_outline,
            size: 64,
            color: AppTheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            confirming ? 'Confirma tu PIN' : 'Crea tu PIN',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            confirming
                ? 'Ingresa el PIN nuevamente'
                : 'Ingresa entre 4 y 6 dígitos',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          PinPad(
            onChanged: _onPinKey,
            maxLength: 6,
            filledLength: dots,
            errorText: _pinError,
          ),
          if (_submitting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: _submitting
                ? null
                : () {
                    setState(() {
                      _firstPin = '';
                      _confirmPin = '';
                      _step = 'form';
                    });
                  },
            child: const Text('Volver'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
