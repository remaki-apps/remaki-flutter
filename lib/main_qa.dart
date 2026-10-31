import 'config/env_config.dart';
import 'main.dart' as app;

void main() async {
  EnvConfig.initialize(Environment.qa);
  await app.bootstrapApp();
}
