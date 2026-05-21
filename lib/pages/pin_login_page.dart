import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class PinLoginPage extends StatefulWidget {
  const PinLoginPage({super.key});

  @override
  State<PinLoginPage> createState() => _PinLoginPageState();
}

class _PinLoginPageState extends State<PinLoginPage> {
  final _pinController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _handlePinSubmit(String pin) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.verifyPin(pin)) {
      // AuthWrapper will handle navigation to Dashboard
    } else {
      setState(() {
        _errorMessage = 'Incorrect PIN';
        _pinController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final authProvider = Provider.of<AuthProvider>(context);
    final userName = authProvider.user?['name'] ?? 'Teacher';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_outline,
                  size: 60,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome Back,',
                style: textTheme.bodyLarge,
              ),
              Text(
                userName,
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your 4-digit PIN to unlock',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 4,
                  autofocus: true,
                  style: const TextStyle(fontSize: 32, letterSpacing: 20),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '****',
                    hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.2)),
                  ),
                  onChanged: (value) {
                    if (value.length == 4) {
                      _handlePinSubmit(value);
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
              const SizedBox(height: 40),
              TextButton(
                onPressed: () {
                  // Option to log out and use password
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Forgot PIN?'),
                      content: const Text('You will need to log in again with your email and password.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            authProvider.logout();
                          },
                          child: const Text('Log Out'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Forgot PIN?'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
