/// Configuration options for Android-specific behavior.
class AndroidOptions {
  // Biometric Prompt UI Strings
  final String title;
  final String subtitle;
  final String description;
  final String negativeButtonText;

  const AndroidOptions({
    this.title = 'Authenticate',
    this.subtitle = '',
    this.description = '',
    this.negativeButtonText = 'Cancel',
  });

  /// Converts the options into a map to pass over the MethodChannel.
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
      'description': description,
      'negativeButtonText': negativeButtonText,
    };
  }
}