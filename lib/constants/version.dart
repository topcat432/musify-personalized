// Only explicitly supplied build metadata is a fallback for non-Android targets.
const appVersion = String.fromEnvironment(
  'MUSIFY_VERSION_NAME',
  defaultValue: 'unknown',
);
