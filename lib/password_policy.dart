final _strongPassword = RegExp(
  r'''^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*()_+\-=\[\]{};'\\:"|<>?,./`~])\S{12,}$''',
);

final _commonPasswordParts = RegExp(
  r'(password|senha|qwerty|123456|blualert)',
  caseSensitive: false,
);

String? validateRegistrationPassword(String? value) {
  final password = value ?? '';
  if (password.length < 12) return 'Use pelo menos 12 caracteres';
  if (RegExp(r'\s').hasMatch(password)) return 'Não use espaços na senha';
  if (!_strongPassword.hasMatch(password)) {
    return 'Inclua maiúscula, minúscula, número e símbolo';
  }
  if (_commonPasswordParts.hasMatch(password)) {
    return 'Evite palavras e sequências fáceis de adivinhar';
  }
  return null;
}
