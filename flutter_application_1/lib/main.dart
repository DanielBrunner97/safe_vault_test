import 'package:flutter/material.dart';
import 'package:safe_vault/android_options.dart';
// 1. Import your custom plugin
import 'package:safe_vault/safe_vault.dart';
import 'package:safe_vault/safe_vault_exceptions.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safe Vault Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Safe Vault Test Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  final SafeVault _safeVault = SafeVault();
  String _vaultStatus = 'Nothing read yet.';

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  // Helper method to easily show snackbars
  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return; // Always check if mounted after async gaps!
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- 3. Add the SafeVault Methods --- //

  Future<void> _saveToVault() async {
    final secretData = 'My secret counter is: $_counter';

    try {
      final success = await _safeVault.saveSecret(
        key: 'demo_key_secure',
        secret: secretData,
      );

      setState(() {
        if (success) {
          _vaultStatus = 'Saved: "$secretData"';
          _showSnackBar('Secret saved successfully!', isError: false);
        } else {
          _vaultStatus = 'Failed to save secret.';
        }
      });
    } on SafeVaultException catch (e) {
      setState(() => _vaultStatus = 'Save failed.');

      // Dart 3 Exhaustive Pattern Matching!
      final errorMessage = switch (e) {
        VaultUserCanceledException() => 'Save cancelled by user.',
        VaultNoBiometricsException() =>
          'Biometrics not available on this device.',
        VaultAuthException() => 'Authentication failed. Could not save.',
        VaultHardwareDesyncException() =>
          'Device security changed. Keys invalidated.',
        VaultUnknownException() => 'Unknown error: ${e.message}',
      };

      _showSnackBar(errorMessage);
    }
  }

  Future<void> _readFromVault() async {
    try {
      final secret = await _safeVault.getSecret(
        key: 'demo_key_secure',
        androidOptions: const AndroidOptions(
          title: 'Unlock your secret counter!',
          subtitle: 'Please authenticate to view your secret counter value.',
          description: 'This is a demo of the Safe Vault plugin.',
          negativeButtonText: 'No, thanks',
        ),
      );

      setState(() {
        if (secret != null) {
          _vaultStatus = 'Unlocked: $secret';
          _showSnackBar('Secret unlocked!', isError: false);
        } else {
          _vaultStatus = 'No secret found in vault.';
        }
      });
    } on SafeVaultException catch (e) {
      setState(() => _vaultStatus = 'Read failed.');

      // Map the sealed exceptions to user-friendly messages
      final errorMessage = switch (e) {
        VaultUserCanceledException() => 'Authentication cancelled.',
        VaultNoBiometricsException() =>
          'Please enable Face ID / Touch ID in settings.',
        VaultAuthException() => 'Authentication failed. Please try again.',
        VaultHardwareDesyncException() =>
          'Biometrics changed! Vault data was safely wiped.',
        VaultUnknownException() => 'An unknown error occurred: ${e.message}',
      };

      _showSnackBar(errorMessage);
    }
  }

  Future<void> _deleteFromVault() async {
    try {
      final success = await _safeVault.deleteSecret(key: 'demo_key_secure');

      setState(() {
        if (success) {
          _vaultStatus = 'Vault cleared successfully.';
          _showSnackBar('Vault cleared.', isError: false);
        } else {
          _vaultStatus = 'Failed to clear vault.';
        }
      });
    } on SafeVaultException catch (e) {
      _showSnackBar('Error deleting secret: ${e.message}');
    }
  }

  // ---> NEW HARDWARE CHECKS <---
  Future<void> _checkDeviceSupported() async {
    final isSupported = await _safeVault.isDeviceSupported();
    setState(() {
      _vaultStatus = 'Hardware Exists: $isSupported';
    });
  }

  Future<void> _checkBiometricAvailable() async {
    final isAvailable = await _safeVault.isBiometricAvailable();
    setState(() {
      _vaultStatus = 'Biometric Enrolled & Ready: $isAvailable';
    });
  }
  // --- 4. Build the UI --- //

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: SingleChildScrollView(
          // Added scroll view to prevent overflow on smaller screens
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('You have pushed the button this many times:'),
              Text(
                '$_counter',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 40),

              // Vault Status Display
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _vaultStatus,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),

              // Vault Controls
              ElevatedButton.icon(
                onPressed: _saveToVault,
                icon: const Icon(Icons.lock),
                label: const Text('Save Counter to Vault'),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _readFromVault,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Read from Vault'),
              ),
              const SizedBox(height: 20),

              // ---> NEW BUTTONS <---
              OutlinedButton.icon(
                onPressed: _checkDeviceSupported,
                icon: const Icon(Icons.memory),
                label: const Text('Check Device Hardware'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _checkBiometricAvailable,
                icon: const Icon(Icons.fact_check),
                label: const Text('Check if Enrolled'),
              ),

              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: _deleteFromVault,
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text(
                  'Delete Secret',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
