import 'dart:async';
import 'dart:io';

Future<bool> brialleSpin(List<bool> spin) async {
  final frames = [
    '⠋',
    '⠙',
    '⠹',
    '⠸',
    '⠼',
    '⠴',
    '⠦',
    '⠧',
    '⠇',
    '⠏'
  ]; //braille spinner
  print("\x1b[2K");
  print('\x1b[2A');
  int frameIndex = 0;
  while (spin[0]) {
    stdout.write('\r${frames[frameIndex]}');
    await Future.delayed(Duration(milliseconds: 100)); //faster
    frameIndex = (frameIndex + 1) % frames.length;
  }
  return spin[0];
}
