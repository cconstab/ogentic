import 'dart:async';

// external packages
import 'package:ogentic/server_print.dart';
import 'package:logging/src/level.dart';
import 'package:chalkdart/chalk.dart';

// atPlatform packages
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:at_cli_commons/at_cli_commons.dart';

// Local Packages
import 'package:ogentic/ogentic.dart';

void main(List<String> args) async {
  //starting secondary in a zone
  var logger = AtSignLogger('aiTalk sender ');
  logger.logger.level = Level.SHOUT;
  await runZonedGuarded(() async {
    await aiTalkServer(args);
  }, (error, stackTrace) {
    logger.shout('Uncaught error: $error');
    logger.shout(stackTrace.toString());
  });
}

Future<void> aiTalkServer(List<String> args) async {
  String nameSpace = 'llama';
  String context = '';
  AtSignLogger.defaultLoggingHandler = AtSignLogger.stdErrLoggingHandler;
  final AtSignLogger logger = AtSignLogger(' aiTalk ');
  logger.hierarchicalLoggingEnabled = true;
  logger.logger.level = Level.SHOUT;

  // kludge because CLIBase default argsParse has namespace as mandatory
  if (!args.join(' ').contains(' -n ')) {
    args = List.from(args)..addAll(['-n', nameSpace]);
  }
  final parser = CLIBase.argsParser;
  final parsedArgs = parser.parse(args);
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
          uniqueID: 'singleton', // only one server
        ),
    verbose: parsedArgs['verbose'],
    syncDisabled: parsedArgs['never-sync'],
    maxConnectAttempts: int.parse(parsedArgs['max-connect-attempts']),
    passPhrase: parsedArgs['passPhrase'],
  );

  await cli.init();
  final atClient = cli.atClient;

  var metaData = Metadata()
    ..isPublic = false
    ..isEncrypted = true
    ..namespaceAware = true;

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
      print(chalk.brightGreen.bold('\r\x1b[K${notification.from}: ') +
          chalk.lightGreen(talk));

      var nameKey = AtKey()
        ..key = "firstname"
        ..sharedBy = notification.from
        ..sharedWith = cli.atSign
        ..namespace = nameSpace
        ..metadata = metaData;

      String firstname = '';
      try {
        var nameAtkey = await atClient.get(nameKey,
            getRequestOptions: GetRequestOptions()..useRemoteAtServer = true);
        firstname = nameAtkey.value ?? '';
        firstname = firstname.split(" ").elementAt(0);
        if (firstname.isEmpty) firstname = notification.from;
      } catch (e) {
        logger.info('Notification no value found for: FirstName');
      }

      print(
          chalk.brightBlue('\r\x1b[KFirstname: ') + chalk.lightBlue(firstname));

      var contextKey = AtKey()
        ..key = "context"
        ..sharedBy = notification.from
        ..sharedWith = cli.atSign
        ..namespace = nameSpace
        ..metadata = metaData;
      try {
        var contextAtkey = await atClient.get(contextKey,
            getRequestOptions: GetRequestOptions()..useRemoteAtServer = true);
        context = contextAtkey.value;
      } catch (e) {
        logger.info('Notification no value found for: Context');
      }

      print(chalk.brightBlue('\r\x1b[KContext: ') + chalk.lightBlue(context));

      var key = AtKey()
        ..key = 'aitalk'
        ..sharedBy = cli.atSign
        ..sharedWith = notification.from
        ..namespace = nameSpace
        ..metadata = metaData;

      String? answer = await questionLlama(talk, firstname, context);
      serverPrint('${cli.atSign}: ');
      print(chalk.lightBlue(answer));

      var success =
          sendNotification(atClient.notificationService, key, answer!, logger);
      if (!await success) {
        print(
            '${chalk.brightRed.bold('\r\x1b[KError Sending: ')}"$answer" to ${notification.from} - unable to reach the Internet !');
      }
    }
  }),
          onError: (e) => logger.severe('Notification Failed:$e'),
          onDone: () => logger.info('Notification listener stopped'));
}

Future<bool> sendNotification(NotificationService notificationService,
    AtKey key, String input, AtSignLogger logger) async {
  bool success = false;

  // back off retries (max 3)
  for (int retry = 1; retry < 4; retry++) {
    try {
      NotificationResult result = await notificationService.notify(
          NotificationParams.forUpdate(key,
              value: input, notificationExpiry: Duration(seconds: 30)),
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
