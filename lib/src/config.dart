const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

const int demoRateIdrPerMnee = int.fromEnvironment(
  'DEMO_RATE_IDR_PER_MNEE',
  defaultValue: 16000,
);
