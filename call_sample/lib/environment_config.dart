import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// read environment variables from config.json file with --dart-define-from-file
/// "--dart-define-from-file=config.json"
/// format config.json file:
/// {
///    "API_SID_KEY": "API_SID_KEY=",
///    "API_SECRET_KEY": "API_SECRET_KEY="
/// }
class EnvironmentConfig {
  // ignore: constant_identifier_names
  static const String API_SID_KEY = String.fromEnvironment('API_SID_KEY');

  // ignore: constant_identifier_names
  static const String API_SECRET_KEY = String.fromEnvironment('API_SECRET_KEY');
}

String getAccessToken({
  String apiKeySid = EnvironmentConfig.API_SID_KEY,
  String apiKeySecret = EnvironmentConfig.API_SECRET_KEY,
  required String userId,
  int ttl = 3600,
}) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final exp = now + ttl;

  final header = {"cty": "stringee-api;v=1"};
  final payload = {
    "jti": "$apiKeySid-$now",
    "iss": apiKeySid,
    "exp": exp,
    "userId": userId,
  };

  final jwt = JWT(payload, header: header);
  final token =
      jwt.sign(SecretKey(apiKeySecret), algorithm: JWTAlgorithm.HS256);

  return token;
}
