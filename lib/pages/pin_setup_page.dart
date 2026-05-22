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
  String _pin = "";
  String _confirmPin = "";
  bool _isConfirming = false;
  String? _errorMessage;

  void _handleNumberPress(String number) {
    setState(() {
      _errorMessage = null;
      if (!_isConfirming) {
        if (_pin.length < 4) {
          _pin += number;
          if (_pin.length == 4) {
            Future.delayed(const Duration(milliseconds: 300), () {
              setState(() => _isConfirming = true);
            });
          }
        }
      } else {
        if (_confirmPin.length < 4) {
          _confirmPin += number;
          if (_confirmPin.length == 4) {
            _verifyAndSubmit();
          }
        }
      }
    });
  }

  void _handleBackspace() {
    setState(() {
      _errorMessage = null;
      if (!_isConfirming) {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      } else {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          _isConfirming = false;
          _pin = _pin.substring(0, _pin.length - 1);
        }
      }
    });
  }

  Future<void> _verifyAndSubmit() async {
    if (_pin != _confirmPin) {
      setState(() {
        _errorMessage = "PINs do not match. Try again.";
        _confirmPin = "";
      });
      return;
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.setPin(_pin);
      
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
        _pin = "";
        _confirmPin = "";
        _isConfirming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            // Header Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isConfirming ? Icons.lock_rounded : Icons.lock_outline_rounded,
                      size: 40,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isConfirming ? 'Confirm your PIN' : 'Create a PIN',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isConfirming
                        ? 'Please re-enter your 4-digit PIN'
                        : 'Set a 4-digit PIN for faster access next time',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            
            const Spacer(),
            
            // PIN Dots Display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final currentLength = _isConfirming ? _confirmPin.length : _pin.length;
                final isActive = index < currentLength;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? colorScheme.primary : colorScheme.surfaceVariant,
                    border: Border.all(
                      color: isActive ? colorScheme.primary : colorScheme.outlineVariant,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            
            if (_errorMessage != null) ...[
              const SizedBox(height: 24),
              Text(
                _errorMessage!,
                style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.w500),
              ),
            ],
            
            const Spacer(),
            
            // Numeric Keypad
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                children: [
                  _buildKeyboardRow(['1', '2', '3']),
                  const SizedBox(height: 20),
                  _buildKeyboardRow(['4', '5', '6']),
                  const SizedBox(height: 20),
                  _buildKeyboardRow(['7', '8', '9']),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 80), // Empty space for layout balance
                      _buildKey('0'),
                      _buildBackspaceKey(),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyboardRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) => _buildKey(key)).toList(),
    );
  }

  Widget _buildKey(String label) {
    return InkWell(
      onTap: () => _handleNumberPress(label),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceKey() {
    return InkWell(
      onTap: _handleBackspace,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        child: const Icon(Icons.backspace_outlined, size: 28),
      ),
    );
  }
}
