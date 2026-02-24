class NumberToWords {
  static const List<String> _unidades = [
    '',
    'UN',
    'DOS',
    'TRES',
    'CUATRO',
    'CINCO',
    'SEIS',
    'SIETE',
    'OCHO',
    'NUEVE',
    'DIEZ',
    'ONCE',
    'DOCE',
    'TRECE',
    'CATORCE',
    'QUINCE',
    'DIECISEIS',
    'DIECISIETE',
    'DIECIOCHO',
    'DIECINUEVE',
    'VEINTE',
    'VEINTIUN',
    'VEINTIDOS',
    'VEINTITRES',
    'VEINTICUATRO',
    'VEINTICINCO',
    'VEINTISEIS',
    'VEINTISIETE',
    'VEINTIOCHO',
    'VEINTINUEVE'
  ];

  static const List<String> _decenas = [
    '',
    '',
    '',
    'TREINTA',
    'CUARENTA',
    'CINCUENTA',
    'SESENTA',
    'SETENTA',
    'OCHENTA',
    'NOVENTA'
  ];

  static const List<String> _centenas = [
    '',
    'CIENTO',
    'DOSCIENTOS',
    'TRESCIENTOS',
    'CUATROCIENTOS',
    'QUINIENTOS',
    'SEISCIENTOS',
    'SETECIENTOS',
    'OCHOCIENTOS',
    'NOVECIENTOS'
  ];

  static String toLiteral(double number, {String currency = 'Bolivianos'}) {
    if (number == 0) return 'CERO 00/100 $currency'.toUpperCase();

    int integerPart = number.truncate();
    int decimalPart = ((number - integerPart) * 100).round();

    String literal =
        '${_convertNumber(integerPart)} ${decimalPart.toString().padLeft(2, '0')}/100 $currency';
    return 'SON: ${literal.toUpperCase()}';
  }

  static String _convertNumber(int number) {
    if (number == 0) return 'CERO';
    if (number == 100) return 'CIEN';
    if (number < 30) return _unidades[number];

    if (number < 100) {
      int d = number ~/ 10;
      int u = number % 10;
      return '${_decenas[d]}${u > 0 ? ' Y ${_unidades[u]}' : ''}';
    }

    if (number < 1000) {
      int c = number ~/ 100;
      int r = number % 100;
      return '${_centenas[c]}${r > 0 ? ' ${_convertNumber(r)}' : ''}';
    }

    if (number < 1000000) {
      int m = number ~/ 1000;
      int r = number % 1000;
      String mStr = (m == 1) ? 'MIL' : '${_convertNumber(m)} MIL';
      return '$mStr${r > 0 ? ' ${_convertNumber(r)}' : ''}';
    }

    if (number < 1000000000) {
      int m = number ~/ 1000000;
      int r = number % 1000000;
      String mStr = (m == 1) ? 'UN MILLON' : '${_convertNumber(m)} MILLONES';
      return '$mStr${r > 0 ? ' ${_convertNumber(r)}' : ''}';
    }

    return number.toString();
  }
}
