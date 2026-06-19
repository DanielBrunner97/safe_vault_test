import 'package:flutter/material.dart';
// 1. Import your custom plugin
import 'package:safe_vault/safe_vault.dart'; 

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
  
  // 2. Initialize the vault and a state variable for the UI
  final SafeVault _safeVault = SafeVault();
  String _vaultStatus = 'Nothing read yet.';

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  // --- 3. Add the SafeVault Methods --- //

  Future<void> _saveToVault() async {
    // We will save the current counter value as the secret
    final secretData = 'My secret counter is: $_counter';
    final success = await _safeVault.saveSecret(key: 'demo_key', secret: secretData);
    
    setState(() {
      if (success) {
        _vaultStatus = 'Saved: "$secretData"';
      } else {
        _vaultStatus = 'Failed to save secret (Cancelled or Error).';
      }
    });
  }

  Future<void> _readFromVault() async {
    final secret = await _safeVault.getSecret(key: 'demo_key');
    
    setState(() {
      if (secret != null) {
        _vaultStatus = 'Unlocked: $secret';
      } else {
        _vaultStatus = 'Read failed. (Cancelled, missing, or Xiaomi desync caught!)';
      }
    });
  }

  Future<void> _deleteFromVault() async {
    final success = await _safeVault.deleteSecret(key: 'demo_key');
    
    setState(() {
      if (success) {
        _vaultStatus = 'Vault cleared successfully.';
      } else {
        _vaultStatus = 'Failed to clear vault.';
      }
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
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _deleteFromVault,
              icon: const Icon(Icons.delete, color: Colors.red),
              label: const Text('Delete Secret', style: TextStyle(color: Colors.red)),
            ),
          ],
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