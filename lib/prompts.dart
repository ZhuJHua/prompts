import 'dart:io';

import 'package:charcode/ascii.dart';
import 'package:io/ansi.dart';

// final String _ansi = String.fromCharCode($esc);

/// Goes up one line.
void goUpOneLine() {
  // ^[[1A
  stdout.add([$esc, $lbracket, $1, $A]);
}

/// Clears the current line, and goes back to the start of the line.
void clearLine() {
  // // \r^[[2K\r
  stdout.add([$esc, $lbracket, $2, $k, $cr]);
  // stdout.write('\r');
  // for (int i = 0; i < stdout.terminalColumns; i++) stdout.write(' ');
  // stdout.write('\r');
}

/// Prompt the user, and return the first line read.
/// This is the core of [Prompter], and the basis for all other
/// functions.
///
/// A function to [validate] may be passed. If `null`, it defaults
/// to checking if the string is not empty.
///
/// A default value may be given as [defaultsTo]. If present, the [message]
/// will have `' ($defaultsTo)'` append to it.
///
/// If [chevron] is `true` (default), then a `>` will be appended to the prompt.
///
/// If [color] is `true` (default), then pretty ANSI colors will be used in the prompt.
///
/// [inputColor] may be used to give a color to the user's input as they type.
///
/// If [allowMultiline] is `true` (default: `false`), then lines ending in a
/// backslash (`\`) will be interpreted as a signal that another line of
/// input is to come. This is helpful for building REPL's.
String get(String message,
    {bool Function(String)? validate,
    String? defaultsTo,
    @deprecated bool colon = true,
    bool chevron = true,
    bool color = true,
    bool allowMultiline = false,
    bool conceal = false,
    AnsiCode inputColor = cyan}) {
  validate ??= (s) => s.trim().isNotEmpty;

  if (defaultsTo != null) {
    var oldValidate = validate;
    validate = (s) => s.trim().isEmpty || oldValidate(s);
  }

  var prefix = '?';
  var code = cyan;
  var currentChevron = '\u00BB';
  var oldEchoMode = stdin.echoMode;

  void writeIt() {
    var msg = color
        ? (code.wrap(prefix)! + ' ' + wrapWith(message, [darkGray, styleBold])!)
        : message;
    stdout.write(msg);
    if (defaultsTo != null) stdout.write(' ($defaultsTo)');
    if (chevron && colon) {
      stdout.write(
          color ? lightGray.wrap(' $currentChevron') : ' $currentChevron');
    }

    stdout.write(' ');

    if (ansiOutputEnabled) {
      // Clear the rest of line.
      // ^[[0K
      stdout.add([$esc, $lbracket, $0, $K]);
    }

    // stdout.write(color ? inputColor?.escape ?? '' : '');
  }

  while (true) {
    if (message.isNotEmpty) {
      writeIt();
    }

    var buf = StringBuffer();
    if (conceal) stdin.echoMode = false;

    while (true) {
      var line = stdin.readLineSync()!.trim();

      if (!line.endsWith('\\')) {
        buf.writeln(line);
        break;
      } else {
        buf.writeln(line.substring(0, line.length - 1));
      }

      clearLine();
    }

    if (conceal) {
      stdin.echoMode = oldEchoMode;
      stdout.writeln();
    }

    // Reset
    // stdout.write(color ? resetAll.escape : '');

    var line = buf.toString().trim();

    if (validate(line)) {
      String out;

      if (defaultsTo != null) {
        out = line.isEmpty ? defaultsTo : line;
      } else {
        out = line;
      }

      if (color) {
        var toWrite = line;
        if (conceal) {
          var asterisks = List.filled(line.length, $asterisk);
          toWrite = String.fromCharCodes(asterisks);
        }

        prefix = '\u2714';
        code = green;
        currentChevron = '\u2025';

        if (ansiOutputEnabled) stdout.add([$esc, $F]);
        goUpOneLine();
        clearLine();
        writeIt();
        // stdout.write(color ? darkGray.escape : '');
        stdout.writeln(color ? darkGray.wrap(toWrite) : toWrite);
        // stdout.write(color ? resetAll.escape : '');
      }

      return out;
    } else {
      code = red;
      prefix = '\u2717';
      if (ansiOutputEnabled) stdout.add([$esc, $F]);

      // Clear the line.
      goUpOneLine();
      clearLine();
    }
  }
}

/// Presents a yes/no prompt to the user.
///
/// If [appendYesNo] is `true`, then a `(y/n)`, `(Y/n)` or `(y/N)` is
/// appended to the [message], depending on its value.
///
/// [color], [inputColor], [conceal], and [chevron] are forwarded to [get].
bool getBool(String message,
    {bool defaultsTo = false,
    bool appendYesNo = true,
    bool color = true,
    bool chevron = true,
    bool conceal = false,
    @deprecated bool colon = true,
    AnsiCode inputColor = cyan}) {
  if (appendYesNo) {
    message +=
        // ignore: unnecessary_null_comparison
        defaultsTo == null ? ' (y/n)' : (defaultsTo ? ' (Y/n)' : ' (y/N)');
  }
  var result = get(
    message,
    color: color,
    inputColor: inputColor,
    conceal: conceal,
    chevron: chevron && colon,
    validate: (s) {
      s = s.trim().toLowerCase();
      return (s.isEmpty) || s.startsWith('y') || s.startsWith('n');
    },
  );
  result = result.toLowerCase();

  if (result.isEmpty) {
    return defaultsTo;
  } else if (result == 'y') return true;
  return false;
}

/// Prompts the user to enter an integer.
///
/// An optional [radix] may be provided.
///
/// [color], [defaultsTo], [inputColor], [conceal], and [chevron] are forwarded to [get].
int getInt(String message,
    {int? defaultsTo,
    int radix = 10,
    bool color = true,
    bool chevron = true,
    bool conceal = false,
    @deprecated bool colon = true,
    AnsiCode inputColor = cyan}) {
  return int.parse(get(
    message,
    defaultsTo: defaultsTo?.toString(),
    chevron: chevron && colon,
    inputColor: inputColor,
    color: color,
    conceal: conceal,
    validate: (s) => int.tryParse(s, radix: radix) != null,
  ));
}

/// Prompts the user to enter a double.
///
/// [color], [defaultsTo], [inputColor], [conceal], and [chevron] are forwarded to [get].
double getDouble(String message,
    {double? defaultsTo,
    bool color = true,
    bool chevron = true,
    @deprecated bool colon = true,
    bool conceal = false,
    AnsiCode inputColor = cyan}) {
  return double.parse(get(
    message,
    defaultsTo: defaultsTo?.toString(),
    chevron: chevron && colon,
    inputColor: inputColor,
    color: color,
    conceal: conceal,
    validate: (s) => double.tryParse(s) != null,
  ));
}

/// Displays to the user a list of [options], and returns
/// once one has been chosen.
///
/// Each option will be prefixed with a number, corresponding
/// to its index + `1`. Pass an iterable of [names] to provide custom prefixes.
///
/// A default option may be provided by means of [defaultsTo].
///
/// A custom [prompt] may be provided, which is then forwarded to [get].
///
/// This function also supports an [interactive] mode, where user arrow keys are processed.
/// In [interactive] mode, you can provide a [defaultIndex] for the UI to start on.
///
/// [color], [defaultsTo], [inputColor], [conceal], and [chevron] are forwarded to [get].
///
/// Example:
///
/// ```
/// Choose a color:
///
/// 1) Red
/// 2) Blue
/// 3) Green
/// ```
T? choose<T>(String message, Iterable<T> options,
    {T? defaultsTo,
    String prompt = 'Enter your choice',
    // int defaultIndex = 0,
    bool chevron = true,
    @deprecated bool colon = true,
    AnsiCode inputColor = cyan,
    bool color = true,
    bool conceal = false,
    bool interactive = true,
    Iterable<String>? names}) {
  if (options.isEmpty) {
    throw ArgumentError.value('`options` may not be empty.');
  }

  if (defaultsTo != null && !options.contains(defaultsTo)) {
    throw ArgumentError(
        '$defaultsTo is not contained in $options, and therefore cannot be the default value.');
  }

  if (names != null && names.length != options.length) {
    throw ArgumentError(
        '$names must have length ${options.length}, not ${names.length}.');
  }

  if (names != null && names.any((s) => s.length != 1)) {
    throw ArgumentError(
        'Every member of $names must be a string with a length of 1.');
  }

  var map = <T, String>{};
  for (var option in options) {
    map[option] = option.toString();
  }

  if (chevron && colon) message += ':';

  var b = StringBuffer();

  b.writeln(message);

  if (interactive && ansiOutputEnabled && !Platform.isWindows) {
    var index = defaultsTo != null ? options.toList().indexOf(defaultsTo) : 0;
    var oldEchoMode = stdin.echoMode;
    var oldLineMode = stdin.lineMode;
    var needsClear = false;
    if (color) {
      print(wrapWith(b.toString(), [darkGray, styleBold]));
    } else {
      print(b);
    }

    void writeIt() {
      if (!needsClear) {
        needsClear = true;
      } else {
        for (var i = 0; i < options.length; i++) {
          goUpOneLine();
          clearLine();
        }
      }

      for (var i = 0; i < options.length; i++) {
        var key = map.keys.elementAt(i);
        var msg = map[key];
        AnsiCode code;

        if (index == i) {
          code = cyan;
          msg = '* $msg';
        } else {
          code = darkGray;
          msg = '$msg  ';
        }

        if (names != null) {
          msg = names.elementAt(i) + ') $msg';
        }

        if (color) {
          print(code.wrap(msg));
        } else {
          print(msg);
        }
      }
    }

    do {
      int ch;
      writeIt();

      try {
        stdin.lineMode = stdin.echoMode = false;
        ch = stdin.readByteSync();

        if (ch == $esc) {
          ch = stdin.readByteSync();
          if (ch == $lbracket) {
            ch = stdin.readByteSync();
            if (ch == $A) {
              // Up key
              index--;
              if (index < 0) index = options.length - 1;
              writeIt();
            } else if (ch == $B) {
              // Down key
              index++;
              if (index >= options.length) index = 0;
              writeIt();
            }
          }
        } else if (ch == $lf) {
          // Enter key pressed - submit
          return map.keys.elementAt(index);
        } else {
          // Check if this matches any name
          var s = String.fromCharCode(ch);
          if (names != null && names.contains(s)) {
            index = names.toList().indexOf(s);
            return map.keys.elementAt(index);
          }
        }
      } finally {
        stdin.lineMode = oldLineMode;
        stdin.echoMode = oldEchoMode;
      }
    } while (true);
  } else {
    b.writeln();

    for (var i = 0; i < options.length; i++) {
      var key = map.keys.elementAt(i);
      var indicator = names != null ? names.elementAt(i) : (i + 1).toString();
      b.write('$indicator) ${map[key]}');
      if (key == defaultsTo) b.write(' [Default - Press Enter]');
      b.writeln();
    }

    b.writeln();
    if (color) {
      print(wrapWith(b.toString(), [darkGray, styleBold]));
    } else {
      print(b);
    }

    var line = get(
      prompt,
      chevron: false,
      inputColor: inputColor,
      color: color,
      conceal: conceal,
      validate: (s) {
        if (s.isEmpty) return defaultsTo != null;
        if (map.values.contains(s)) return true;
        if (names != null && names.contains(s)) return true;
        var i = int.tryParse(s);
        if (i == null) return false;
        return i >= 1 && i <= options.length;
      },
    );

    if (line.isEmpty) return defaultsTo;
    int? i;
    if (names != null && names.contains(line)) {
      i = names.toList().indexOf(line) + 1;
    } else {
      i = int.tryParse(line);
    }

    if (i != null) return map.keys.elementAt(i - 1);
    return map.keys.elementAt(map.values.toList(growable: false).indexOf(line));
  }
}

/// Prompt the user to select multiple options.
List<T> multiChoose<T>(
  String message,
  List<T> options, {
  String prompt =
      'Select options (press [space] to toggle, [enter] to confirm)',
  AnsiCode selectedColor = cyan,
  bool color = true,
  Iterable<String>? names,
  Set<T> defaultSelected = const {},
}) {
  if (options.isEmpty) throw ArgumentError('Options cannot be empty.');
  if (names != null && names.length != options.length) {
    throw ArgumentError('names must match options length.');
  }

  var selected = List<bool>.filled(options.length, false);
  if (defaultSelected.isNotEmpty) {
    for (var i = 0; i < options.length; i++) {
      if (defaultSelected.contains(options[i])) {
        selected[i] = true;
      }
    }
  }
  var index = 0;

  stdout.writeln('\n$message\n');

  void render() {
    for (var i = 0; i < options.length; i++) {
      var prefix = selected[i] ? '[✔]' : '[ ]';
      var text = '$prefix ${options[i]}';

      if (i == index) {
        if (color) {
          stdout.writeln(selectedColor.wrap('> $text'));
        } else {
          stdout.writeln('> $text');
        }
      } else {
        stdout.writeln('  $text');
      }
    }
  }

  if (ansiOutputEnabled && !Platform.isWindows) {
    var oldEchoMode = stdin.echoMode;
    var oldLineMode = stdin.lineMode;

    try {
      stdin.echoMode = false;
      stdin.lineMode = false;

      render();

      while (true) {
        var ch = stdin.readByteSync();
        if (ch == $esc) {
          ch = stdin.readByteSync();
          if (ch == $lbracket) {
            ch = stdin.readByteSync();
            if (ch == $A) {
              // Up
              index = (index - 1) % options.length;
            } else if (ch == $B) {
              // Down
              index = (index + 1) % options.length;
            }
          }
        } else if (ch == $space) {
          selected[index] = !selected[index];
        } else if (ch == $lf) {
          // Enter key
          break;
        }

        for (var i = 0; i < options.length; i++) {
          goUpOneLine();
          clearLine();
        }

        render();
      }
    } finally {
      stdin.echoMode = oldEchoMode;
      stdin.lineMode = oldLineMode;
    }

    stdout.writeln(); // for spacing
  } else {
    // Fallback: comma-separated
    for (var i = 0; i < options.length; i++) {
      stdout.writeln('${i + 1}) ${options[i]}');
    }

    var input = get(prompt);
    var indexes = input
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .where((e) => e != null && e > 0 && e <= options.length)
        .map((e) => e! - 1)
        .toList();

    for (var i in indexes) {
      selected[i] = true;
    }
  }

  return [
    for (var i = 0; i < options.length; i++)
      if (selected[i]) options[i],
  ];
}

/// Similar to [choose], but opts for a shorthand syntax that fits into one line,
/// rather than a multi-line prompt.
///
/// Acceptable inputs include:
/// * The full value of `toString()` for any one option
/// * The first character (case-insensitive) of `toString()` for an option
///
/// A default option may be provided by means of [defaultsTo].
///
/// [color], [defaultsTo], [inputColor], and [chevron] are forwarded to [get].
T? chooseShorthand<T>(String message, Iterable<T> options,
    {T? defaultsTo,
    bool chevron = true,
    @deprecated bool colon = true,
    AnsiCode inputColor = cyan,
    bool color = true,
    bool conceal = false}) {
  if (options.isEmpty) {
    throw ArgumentError.value('`options` may not be empty.');
  }

  var b = StringBuffer(message);
  if (chevron && colon) b.write(':');
  b.write(' (');
  var firstChars = <String>[], strings = <String>[];
  var i = 0;

  for (var option in options) {
    var str = option.toString();
    if (i++ > 0) b.write('/');

    if (defaultsTo != null) {
      if (defaultsTo == option) {
        str = str[0].toUpperCase() + str.substring(1);
      } else {
        str = str[0].toLowerCase() + str.substring(1);
      }
    }

    b.write(str);
    firstChars.add(str[0].toLowerCase());
    strings.add(str);
  }

  b.write(')');

  T? value;

  get(
    b.toString(),
    chevron: chevron && colon,
    inputColor: inputColor,
    color: color,
    conceal: conceal,
    validate: (s) {
      if (s.isEmpty) return (value = defaultsTo) != null;

      if (strings.contains(s)) {
        value = options.elementAt(strings.indexOf(s));
        return true;
      }

      if (firstChars.contains(s[0].toLowerCase())) {
        value = options.elementAt(firstChars.indexOf(s[0].toLowerCase()));
        return true;
      }

      return false;
    },
  );

  return value;
}
