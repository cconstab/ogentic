import 'dart:io';
import 'dart:convert';
import 'dart:async';

// external packages
import 'package:args/args.dart';
import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:dfunc/dfunc.dart';
import 'package:ogentic/common.dart';
import 'package:ogentic/pipe_print.dart';
import 'package:logging/src/level.dart';
import 'package:chalkdart/chalk.dart';

// atPlatform packages
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';

// Local Packages
import 'package:ogentic/braille_spin.dart';
import 'package:uuid/uuid.dart';

const String digits = '0123456789';
final RegExp generateCommandRegEx = RegExp(r'^/gen \d+$');

void main(List<String> args) async {
  //starting secondary in a zone
  var logger = AtSignLogger('aiTalk sender ');
  logger.logger.level = Level.SHOUT;
  await runZonedGuarded(() async {
    await aiTalk(args);
  }, (error, stackTrace) {
    logger.shout('Uncaught error: $error');
    logger.shout(stackTrace.toString());
  });
}

Future<void> aiTalk(List<String> args) async {
  String context = '';
  String firstname = '';
  String nameSpace;
  AtSignLogger.defaultLoggingHandler = AtSignLogger.stdErrLoggingHandler;
  final AtSignLogger logger = AtSignLogger(' aiTalk ');
  logger.hierarchicalLoggingEnabled = true;
  logger.logger.level = Level.SHOUT;

  ArgParser parser = CLIBase.argsParser;
  parser.addOption('toatsign',
      abbr: 't', mandatory: true, help: 'Talk to this atSign');
  parser.addOption('firstname',
      abbr: 'f', mandatory: false, help: 'Send and Store your firstname');
  parser.addOption('context',
      abbr: 'c',
      mandatory: false,
      help: 'Send and Store the context of the prompt');

  // kludge because CLIBase default argsParse has namespace as mandatory
  if (!args.join(' ').contains(' -n ')) {
    args = List.from(args)..addAll(['-n', Consts.defaultNameSpace]);
  }

  final parsedArgs = parser.parse(args);
  String toAtsign = parsedArgs['toatsign'];

  if (parsedArgs['firstname'] != null) {
    firstname = parsedArgs['firstname'];
  }

  nameSpace = parsedArgs['namespace'];

  if (parsedArgs['context'] != null) {
    context = parsedArgs['context'];
    var limit255 = limit(255);
    context = limit255(context);
  }

  final cli = CLIBase(
    atSign: parsedArgs['atsign'],
    atKeysFilePath: parsedArgs['key-file'],
    nameSpace: parsedArgs['namespace'],
    rootDomain: parsedArgs['root-domain'],
    homeDir: getHomeDirectory(),
    storageDir: parsedArgs['storage-dir'] ??
        standardAtClientStoragePath(
          baseDir: getHomeDirectory()!,
          atSign: parsedArgs['atsign'],
          progName: 'ai_talk',
          uniqueID: Uuid().v4(), // many clients
        ),
    verbose: parsedArgs['verbose'],
    syncDisabled: parsedArgs['never-sync'],
    maxConnectAttempts: int.parse(parsedArgs['max-connect-attempts']),
    passPhrase: parsedArgs['passPhrase'],
  );

  await cli.init();
  final atClient = cli.atClient;

  bool hasTerminal = true;
  List<bool> spin = [false];

  var metaData = Metadata()
    ..isPublic = false
    ..isEncrypted = true
    ..namespaceAware = true;

  var key = AtKey()
    ..key = 'aitalk'
    ..sharedBy = cli.atSign
    ..sharedWith = toAtsign
    ..namespace = nameSpace
    ..metadata = metaData;

  AtKey nameKey = key;
  nameKey.key = "firstname";
  // Auto cleanup after an hour.
  nameKey.metadata.ttl = 60 * 60 * 1000;
  if (firstname != '') {
    await atClient.put(nameKey, firstname,
        putRequestOptions: PutRequestOptions()..useRemoteAtServer = true);
  }

  nameKey.key = "context";
  if (context != '') {
    await atClient.put(nameKey, context,
        putRequestOptions: PutRequestOptions()..useRemoteAtServer = true);
  }

  atClient.notificationService
      .subscribe(regex: 'aitalk.$nameSpace@', shouldDecrypt: true)
      .listen(((notification) async {
    String keyAtsign = notification.key;
    keyAtsign = keyAtsign.replaceAll('${notification.to}:', '');
    keyAtsign = keyAtsign.replaceAll('.$nameSpace${notification.from}', '');
    if (keyAtsign == 'aitalk') {
      logger.info(
          'aiTalk update received from ${notification.from} notification id : ${notification.id}');
      var talk = notification.value!;
      // Terminal Control
      // '\r\x1b[K' is used to set the cursor back to the beginning of the line then deletes to the end of line
      //
      spin[0] = false;
      if (hasTerminal) {
        pipePrint(chalk.brightGreen.bold('\r\x1b[K${notification.from}: ') +
            chalk.brightGreen('$talk\n'));
      } else {
        stdout.write("$talk\n");
      }
      pipePrint('${cli.atSign}: ');
    }
  }),
          onError: (e) => logger.severe('Notification Failed:$e'),
          onDone: () => logger.info('Notification listener stopped'));

  String input = "";
  String buffer = "";
  pipePrint('${cli.atSign}: ');

  var lines = stdin.transform(utf8.decoder).transform(const LineSplitter());
  metaData = Metadata()
    ..isPublic = false
    ..isEncrypted = true
    ..namespaceAware = true;

  key = AtKey()
    ..key = 'aitalk'
    ..sharedBy = cli.atSign
    ..sharedWith = toAtsign
    ..namespace = nameSpace
    ..metadata = metaData;

  await for (final l in lines) {
    pipePrint('${cli.atSign}: ');
    input = l;
    if (input == '/exit') {
      exit(0);
    }
    if (input.startsWith(RegExp('^/@'))) {
      toAtsign = input.replaceFirst(RegExp('^/'), '');
      print('now talking to: $toAtsign');
      input = '';
    }

    if (generateCommandRegEx.hasMatch(input)) {
      int length = int.parse(input.split(' ')[1]);
      input = String.fromCharCodes(
          Iterable.generate(length, (index) => digits.codeUnitAt(index % 10)));
    }

    if (!(input == "")) {
      if (!(stdin.hasTerminal)) {
        hasTerminal = false;
        buffer = '$buffer\n\r$input';
      } else {
        hasTerminal = true;
        spin[0] = true;
        brailleSpin(spin);
        var success = await sendNotification(
            atClient.notificationService, key, input, logger);
        if (success == false) {
          spin[0] = false;
          print(
              '${chalk.brightRed.bold('\r\x1b[KError Sending: ')}"$input" to $toAtsign - unable to reach the Internet !');
          pipePrint('${cli.atSign}: ');
        }
      }
    }
  }

// Send file contents if stdin has no terminal
  if (!(hasTerminal)) {
    spin[0] = true;
    var success = await sendNotification(
        atClient.notificationService, key, buffer, logger);
    if (success == false) {
      spin[0] = false;
      print(
          '${chalk.brightRed.bold('\r\x1b[KError Sending: ')}"$input" to $toAtsign - unable to reach the Internet !');
    }
  }
  while (spin[0]) {
    await Future.delayed(Duration(milliseconds: (100)));
  }

  exit(0);
}

Future<bool> sendNotification(NotificationService notificationService,
    AtKey key, String input, AtSignLogger logger) async {
  bool success = false;

  // back off retries (max 3)
  for (int retry = 1; retry < 4; retry++) {
    try {
      NotificationResult result = await notificationService.notify(
          NotificationParams.forUpdate(key,
              value: input,
              notificationExpiry: Duration(seconds: 360),
              strategy: StrategyEnum.all),
          waitForFinalDeliveryStatus: false,
          onSentToSecondary: (p0) {},
          checkForFinalDeliveryStatus: false);
      if (result.atClientException != null) {
        logger.warning(result.atClientException);
        print(
            '${chalk.brightRed.bold('\r\x1b[KError Sending: ')} retry number $retry of 3');
        await Future.delayed(Duration(milliseconds: (500 * (retry))));
      } else {
        success = true;
        break;
      }
    } catch (e) {
      logger.warning(e);
    }
  }
  return (success);
}
