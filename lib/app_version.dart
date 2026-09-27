/// The version the Settings and About screens show (#86).
///
/// CI passes both as `--dart-define`s: release.yml from `tools/ci_version.sh`
/// (a full semver and the Play version code), the PR gate with the pubspec
/// version and `pr`. A local build shows "dev" for both.
library;

const String appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: 'dev',
);
const String appBuild = String.fromEnvironment(
  'APP_BUILD',
  defaultValue: 'dev',
);

/// "v0.2.0 · BUILD 1034", "vdev · BUILD dev".
String get versionLine => 'v$appVersion · BUILD $appBuild';
