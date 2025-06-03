import 'dart:io';

import 'package:ogentic/src/version.dart' as binaries;

/// Print version number
void printVersion() {
  stderr.writeln('Version : ${binaries.packageVersion}');
}
