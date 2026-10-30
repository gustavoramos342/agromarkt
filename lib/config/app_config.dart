class AppConfig {
  static const bool useMockAuth = bool.fromEnvironment(
    'USE_MOCK_AUTH',
    defaultValue: false,
  );

  static const bool useMockProducts = bool.fromEnvironment(
    'USE_MOCK_PRODUCTS',
    defaultValue: true,
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://agromarkt-api.onrender.com/api',
  );
}
