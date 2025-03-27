import 'dart:io';
import 'package:chalkdart/chalk.dart';

void serverPrint(String p) {
  stdout.write(chalk.red.bold(p));
}
