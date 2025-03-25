import 'dart:io';
import 'dart:convert';
import 'dart:async';

// external packages
import 'package:args/args.dart';
import 'package:ogentic/pipe_print.dart';
import 'package:logging/src/level.dart';
import 'package:chalkdart/chalk.dart';

// atPlatform packages
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';

// Local Packages
import 'package:ogentic/home_directory.dart';
import 'package:ogentic/check_file_exists.dart';
import 'package:version/version.dart';
import 'package:ogentic/ogentic.dart';

const String digits = '0123456789';
final RegExp generateCommandRegEx = RegExp(r'^/gen \d+$');

void main(List<String> args) async {
  //starting secondary in a zone
  var logger = AtSignLogger('aiTalk sender ');
  logger.logger.level = Level.SHOUT;
  await runZonedGuarded(() async {
    await aiTalkServer(args);
  }, (error, stackTrace) {
    logger.severe('Uncaught error: $error');
    logger.severe(stackTrace.toString());
  });
}

Future<void> aiTalkServer(List<String> args) async {
  final AtSignLogger logger = AtSignLogger(' aiTalk ');
  logger.hierarchicalLoggingEnabled = true;
  logger.logger.level = Level.SHOUT;

  var parser = ArgParser();
// Args
  parser.addOption('key-file',
      abbr: 'k', mandatory: false, help: 'Your atSign\'s atKeys file if not in ~/.atsign/keys/');
  parser.addOption('atsign', abbr: 'a', mandatory: true, help: 'Your atSign');
  parser.addOption('root-domain', abbr: 'd', mandatory: false, help: 'Root Domain (defaults to root.atsign.org)');
  parser.addOption('namespace', abbr: 'n', mandatory: false, help: 'Namespace (defaults to llama)');
  parser.addFlag('verbose', abbr: 'v', help: 'More logging', negatable: false);

  // Check the arguments
  dynamic parsedArgs;
  String atsignFile;

  String fromAtsign = 'unknown';
  String toAtsign = 'unknown';
  String? homeDirectory = getHomeDirectory();
  String nameSpace = 'llama';
  String rootDomain = 'root.atsign.org';
  String firstname = '';
  String context = '';

  try {
    // Arg check
    parsedArgs = parser.parse(args);
    // Find atSign key file
    fromAtsign = parsedArgs['atsign'];
    //toAtsign = parsedArgs['toatsign'];

    if (parsedArgs['root-domain'] != null) {
      rootDomain = parsedArgs['root-domain'];
    }

    if (parsedArgs['namespace'] != null) {
      nameSpace = parsedArgs['namespace'];
    }

    if (parsedArgs['key-file'] != null) {
      atsignFile = parsedArgs['key-file'];
    } else {
      atsignFile = '${fromAtsign}_key.atKeys';
      atsignFile = '$homeDirectory/.atsign/keys/$atsignFile';
    }
    // Check atKeyFile selected exists
    if (!await fileExists(atsignFile)) {
      throw ('\n Unable to find .atKeys file : $atsignFile');
    }
  } catch (e) {
    print(parser.usage);
    print(e);
    exit(1);
  }

  AtServiceFactory? atServiceFactory;

// Now on to the atPlatform startup
  AtSignLogger.root_level = 'SHOUT';
  if (parsedArgs['verbose']) {
    logger.logger.level = Level.INFO;

    AtSignLogger.root_level = 'INFO';
  }

  //onboarding preference builder can be used to set onboardingService parameters
  AtOnboardingPreference atOnboardingConfig = AtOnboardingPreference()
    ..hiveStoragePath = '$homeDirectory/.$nameSpace/$fromAtsign/storage'
    ..namespace = nameSpace
    ..downloadPath = '$homeDirectory/.$nameSpace/files'
    ..isLocalStoreRequired = true
    ..commitLogPath = '$homeDirectory/.$nameSpace/$fromAtsign/storage/commitLog'
    ..rootDomain = rootDomain
    ..fetchOfflineNotifications = true
    ..atKeysFilePath = atsignFile
    ..atProtocolEmitted = Version(2, 0, 0);

  var metaData = Metadata()
    ..isPublic = false
    ..isEncrypted = true
    ..namespaceAware = true;

  AtOnboardingService onboardingService =
      AtOnboardingServiceImpl(fromAtsign, atOnboardingConfig, atServiceFactory: atServiceFactory);
  bool onboarded = false;
  Duration retryDuration = Duration(seconds: 3);
  while (!onboarded) {
    try {
      stdout.write(chalk.brightBlue('\r\x1b[KConnecting ... '));
      await Future.delayed(Duration(milliseconds: 1000)); // Pause just long enough for the retry to be visible
      onboarded = await onboardingService.authenticate();
    } catch (exception) {
      stdout.write(chalk.brightRed('$exception. Will retry in ${retryDuration.inSeconds} seconds'));
    }
    if (!onboarded) {
      await Future.delayed(retryDuration);
    }
  }
  stdout.writeln(chalk.brightGreen('Connected'));

  // Current atClient is the one which the onboardingService just authenticated
  AtClient atClient = AtClientManager.getInstance().atClient;

  atClient.notificationService.subscribe(regex: 'aitalk.$nameSpace@', shouldDecrypt: true).listen(
      ((notification) async {
    print('goti');
    String keyAtsign = notification.key;
    keyAtsign = keyAtsign.replaceAll('${notification.to}:', '');
    keyAtsign = keyAtsign.replaceAll('.$nameSpace${notification.from}', '');

    if (keyAtsign == 'aitalk') {
      logger.info('aiTalk update received from ${notification.from} notification id : ${notification.id}');
      var talk = notification.value!;
      //print('Getting firstname \n');
      var namekey = AtKey()
        ..key = "firstname"
        ..sharedBy = notification.from
        ..sharedWith = toAtsign
        ..namespace = nameSpace
        ..metadata = metaData;
      var nameAtkey = await atClient.get(namekey);
      firstname = nameAtkey.value;
      firstname = firstname.split(" ").elementAt(0);
      if (firstname.isEmpty) firstname = notification.from;
      
      print('got the firstname $firstname');

      var contextKey = AtKey()
        ..key = "context"
        ..sharedBy = notification.from
        ..sharedWith = toAtsign
        ..namespace = nameSpace
        ..metadata = metaData;

      var contextAtkey = await atClient.get(contextKey);
      context = contextAtkey.value;

      print('got the context $context');

      var key = AtKey()
        ..key = 'aitalk'
        ..sharedBy = fromAtsign
        ..sharedWith = notification.from
        ..namespace = nameSpace
        ..metadata = metaData;

      // Terminal Control
      // '\r\x1b[K' is used to set the cursor back to the beginning of the line then deletes to the end of line
      //
      print(chalk.brightGreen.bold('\r\x1b[K${notification.from}: ') + chalk.brightGreen(talk));
      String? answer = await questionLlamma(talk, firstname, context);
      pipePrint('$fromAtsign: $answer\n');

      var success = sendNotification(atClient.notificationService, key, answer!, logger);
      if (!await success) {
        print(
            '${chalk.brightRed.bold('\r\x1b[KError Sending: ')}"$answer" to ${notification.from} - unable to reach the Internet !');
        pipePrint('$fromAtsign: ');
      }

      pipePrint('$fromAtsign: ');
    }
  }),
      onError: (e) => logger.severe('Notification Failed:$e'),
      onDone: () => logger.info('Notification listener stopped'));

  String input = "";
  pipePrint('$fromAtsign: ');

  var lines = stdin.transform(utf8.decoder).transform(const LineSplitter());

  await for (final l in lines) {
    pipePrint('$fromAtsign: ');
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
      input = String.fromCharCodes(Iterable.generate(length, (index) => digits.codeUnitAt(index % 10)));
    }
  }
}

Future<bool> sendNotification(
    NotificationService notificationService, AtKey key, String input, AtSignLogger logger) async {
  bool success = false;

  // back off retries (max 3)
  for (int retry = 1; retry < 4; retry++) {
    try {
      NotificationResult result = await notificationService.notify(
          NotificationParams.forUpdate(key, value: input, notificationExpiry: Duration(seconds: 30)),
          waitForFinalDeliveryStatus: false,
          checkForFinalDeliveryStatus: false);
      if (result.atClientException != null) {
        logger.warning(result.atClientException);
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
