class PhoneNumber {
  static String? normalize(String prefix, String input) {
    if (RegExp(r'[^0-9\s()+-]').hasMatch(input)) return null;
    var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (prefix == '+7' &&
        digits.length == 11 &&
        (digits.startsWith('7') || digits.startsWith('8'))) {
      digits = digits.substring(1);
    }
    final full = '$prefix$digits';
    if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(full)) return null;
    if (prefix == '+7' && digits.length != 10) return null;
    return full;
  }
}
