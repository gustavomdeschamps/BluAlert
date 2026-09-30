import 'package:blualert/password_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exige tamanho e mistura de caracteres', () {
    expect(validateRegistrationPassword('Curta1!'), isNotNull);
    expect(validateRegistrationPassword('semmaiuscula123!'), isNotNull);
    expect(validateRegistrationPassword('SemNumeroAqui!'), isNotNull);
    expect(validateRegistrationPassword('RioSeguro2026'), isNotNull);
    expect(validateRegistrationPassword('Rio Seguro!2026'), isNotNull);
    expect(validateRegistrationPassword('Password12345!'), isNotNull);
    expect(validateRegistrationPassword('RioSeguro!2026'), isNull);
  });
}
