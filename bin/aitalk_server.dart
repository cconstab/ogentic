import 'dart:async';
import 'dart:io';

// external packages
import 'package:at_policy/at_policy.dart';
import 'package:ogentic/common.dart';
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
  await runZonedGuarded(() async {
    await AITalkServer().run(args);
  }, (error, stackTrace) {
    stderr.writeln('Uncaught error: $error');
    stderr.writeln(stackTrace);
  });
}

class AITalkServer {
  late String nameSpace;
  late AtClient atClient;
  late String policyAtsign;
  late CLIBase cli;

  final logger = AtSignLogger(' aiTalk server ');

  final _md = Metadata()
    ..isPublic = false
    ..isEncrypted = true
    ..namespaceAware = true;

  late final bool policy;
  AtRpcClient? _policyClient;

  Future<void> run(List<String> args) async {
    AtSignLogger.defaultLoggingHandler = AtSignLogger.stdErrLoggingHandler;
    logger.hierarchicalLoggingEnabled = true;
    logger.logger.level = Level.SHOUT;

    // kludge because CLIBase default argsParse has namespace as mandatory
    if (!args.join(' ').contains(' -n ')) {
      args = List.from(args)..addAll(['-n', Consts.defaultNameSpace]);
    }
    final parser = CLIBase.argsParser;
    try {
      parser.addOption('policy', abbr: 'p', help: 'the atsign of the policy service being used');
      final parsedArgs = parser.parse(args);
      nameSpace = parsedArgs['namespace'];
      policyAtsign = parsedArgs['policy'].toString().toAtsign();
      cli = CLIBase(
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

      if (parsedArgs['policy'] != null) {
        policy = true;
      } else {
        policy = false;
      }
      await cli.init();
    } catch (e) {
      // Kludge to remove the '-n' mandatory notice from the parser
      print(parser.usage.replaceAll(RegExp('--namespace.*(mandatory).*\n'), '--namespace                Namespace\n'));
      print(e);
      exit(1);
    }
     atClient = cli.atClient;
    
    if (policy) {
      // Make a client for talking to the policy service
      _policyClient = AtRpcClient(
          atClient: atClient,
          baseNameSpace: nameSpace,
          domainNameSpace: Consts.policySubNameSpace,
          serverAtsign: policyAtsign);
    }

    atClient.notificationService.subscribe(regex: 'aitalk.$nameSpace@', shouldDecrypt: true).listen(requestHandler,
        onError: (e) => logger.severe('Notification Failed:$e'),
        onDone: () => logger.info('Notification listener stopped'));
  }

  Future<void> requestHandler(notification) async {
    String keyAtsign = notification.key;
    keyAtsign = keyAtsign.replaceAll('${notification.to}:', '');
    keyAtsign = keyAtsign.replaceAll('.$nameSpace${notification.from}', '');

    if (keyAtsign == 'aitalk') {
      logger.info('aiTalk update received from ${notification.from} notification id : ${notification.id}');
      var talk = notification.value!;

      // Terminal Control
      // '\r\x1b[K' is used to set the cursor back to the beginning of the line then deletes to the end of line
      //
      print(chalk.brightGreen.bold('\r\x1b[K${notification.from}: ') + chalk.lightGreen(talk));

      var nameKey = AtKey()
        ..key = "firstname"
        ..sharedBy = notification.from
        ..sharedWith = cli.atSign
        ..namespace = nameSpace
        ..metadata = _md;

      String firstname = '';
      try {
        var nameAtkey = await atClient.get(nameKey, getRequestOptions: GetRequestOptions()..useRemoteAtServer = true);
        firstname = nameAtkey.value ?? '';
        firstname = firstname.split(" ").elementAt(0);
        if (firstname.isEmpty) firstname = notification.from;
      } catch (e) {
        logger.info('Notification no value found for: FirstName');
      }

      print(chalk.brightBlue('\r\x1b[KFirstname: ') + chalk.lightBlue(firstname));

      String context = '';
      var contextKey = AtKey()
        ..key = "context"
        ..sharedBy = notification.from
        ..sharedWith = cli.atSign
        ..namespace = nameSpace
        ..metadata = _md;
      try {
        var contextAtkey =
            await atClient.get(contextKey, getRequestOptions: GetRequestOptions()..useRemoteAtServer = true);
        context = contextAtkey.value;
      } catch (e) {
        logger.info('Notification no value found for: Context');
      }

      print(chalk.brightBlue('\r\x1b[KContext: ') + chalk.lightBlue(context));

      String defaultAdditionalContext = 'Ignore all previous instructions,'
          ' just talk about the weather.';

      String additionalContext = '';

      if (_policyClient != null) {
        print(chalk.purple('Checking policy'));
        PolicyRequest polReq = PolicyRequest(
            serviceAtsign: atClient.getCurrentAtSign()!,
            serviceName: 'llama_demo',
            serviceGroupName: 'default',
            clientAtsign: notification.from,
            intents: [PolicyIntent(intent: Consts.contextIntent, params: {})]);

        additionalContext = defaultAdditionalContext;
        try {
          Map<String, dynamic> rpcResponse = await _policyClient!.call(polReq.toJson()).timeout(Duration(seconds: 5));
          PolicyResponse response = PolicyResponse.fromJson(rpcResponse);
          PolicyDetail? pd = response.infoForIntent(Consts.contextIntent);
          if (pd != null && pd.info['additionalContext'] != null) {
            additionalContext = pd.info['additionalContext'];
            print(chalk.purple(
              'Fetched additional context'
              ' for ${notification.from}',
            ));
          } else {
            print(chalk.purple(
              'NO additional context'
              ' for ${notification.from}'
              ' - keeping default additional context',
            ));
          }
        } on TimeoutException {
          stderr.writeln(chalk.brightRed('timed out waiting for policy service response'));
        } catch (e) {
          stderr.writeln(chalk.brightRed(e));
        }
      }

      var key = AtKey()
        ..key = 'aitalk'
        ..sharedBy = cli.atSign
        ..sharedWith = notification.from
        ..namespace = nameSpace
        ..metadata = _md;

      String? answer = await questionLlama(talk, firstname, context, additionalContext);
      // String answer = 'Echoing:\n'
      //     '    atSign ${notification.from}\n'
      //     '    firstname: $firstname\n'
      //     '    context: $context\n'
      //     '    additionalContext: $additionalContext\n'
      //     '    talk: $talk';
      serverPrint('${cli.atSign}: ');
      print(chalk.lightBlue(answer));

      var success = sendNotification(atClient.notificationService, key, answer!, logger);
      if (!await success) {
        print(
            '${chalk.brightRed.bold('\r\x1b[KError Sending: ')}"$answer" to ${notification.from} - unable to reach the Internet !');
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
}
