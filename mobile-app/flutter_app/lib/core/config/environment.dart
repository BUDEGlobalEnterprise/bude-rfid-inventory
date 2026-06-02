class Environment {
  final String name;
  final String apiBaseUrl;
  final String appName;
  final bool isProduction;

  const Environment({
    required this.name,
    required this.apiBaseUrl,
    required this.appName,
    required this.isProduction,
  });

  factory Environment.development() => const Environment(
        name: 'development',
        apiBaseUrl: 'http://localhost:8000',
        appName: 'Bude Inventory (Dev)',
        isProduction: false,
      );

  factory Environment.staging() => const Environment(
        name: 'staging',
        apiBaseUrl: 'https://staging.example.com',
        appName: 'Bude Inventory (Staging)',
        isProduction: false,
      );

  factory Environment.production() => const Environment(
        name: 'production',
        apiBaseUrl: 'https://erp.example.com',
        appName: 'Bude Inventory',
        isProduction: true,
      );
}
