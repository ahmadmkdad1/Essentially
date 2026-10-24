/// Form validators mirroring the API's validation rules.
abstract final class Validators {
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _phone = RegExp(r'^\+?[0-9 ()-]{6,30}$');
  static final _passwordRule = RegExp(r'^(?=.*[A-Za-z])(?=.*\d).+$');

  static String? required(String? v, [String field = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    return _email.hasMatch(v.trim()) ? null : 'Enter a valid email address';
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Use at least 8 characters';
    if (!_passwordRule.hasMatch(v)) return 'Include at least one letter and one number';
    return null;
  }

  static String? optionalPhone(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return _phone.hasMatch(v.trim()) ? null : 'Enter a valid phone number';
  }

  static String? minLength(String? v, int min, [String field = 'This field']) {
    if (v == null || v.trim().isEmpty) return '$field is required';
    return v.trim().length < min ? '$field must be at least $min characters' : null;
  }

  static String? price(String? v) {
    final value = double.tryParse((v ?? '').replaceAll(',', '.'));
    if (value == null) return 'Enter a valid price';
    if (value < 0) return 'Price cannot be negative';
    if (value > 1000000) return 'Price is too high';
    return null;
  }
}
