import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'welcome_page.dart';

class PinSetupPage extends StatefulWidget {
  const PinSetupPage({super.key});

  @override
  State<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<PinSetupPage> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _isConfirming = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _handlePinSubmit() {
    if (_pinController.text.length < 4) {
      setState(() {
        _errorMessage = 'PIN must be 4 digits';
      });
      return;
    }

    setState(() {
      _isConfirming = true;
      _errorMessage = null;
    });
  }

  Future<void> _handleConfirmSubmit() async {
    if (_confirmPinController.text != _pinController.text) {
      setState(() {
        _errorMessage = 'PINs do not match';
      });
      return;
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.setPin(_pinController.text);
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WelcomePage(name: authProvider.user?['name'] ?? 'Teacher'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to set PIN: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                _isConfirming ? Icons.lock_outline : Icons.lock_open_outlined,
                size: 80,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                _isConfirming ? 'Confirm PIN' : 'Create PIN',
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _isConfirming
                    ? 'Please re-enter your 4-digit PIN'
                    : 'Set a 4-digit PIN for faster access next time',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _isConfirming ? _confirmPinController : _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 4,
                  style: const TextStyle(fontSize: 32, letterSpacing: 20),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '****',
                    hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.2)),
                  ),
                  onChanged: (value) {
                    if (value.length == 4) {
                      if (_isConfirming) {
                        _handleConfirmSubmit();
                      } else {
                        _handlePinSubmit();
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: TextStyle(color: colorScheme.error),
                ),
              const SizedBox(height: 24),
              if (_isConfirming)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isConfirming = false;
                      _confirmPinController.clear();
                      _errorMessage = null;
                    });
                  },
                  child: const Text('Back to Create PIN'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
