import 'dart:async';
import 'dart:io';

import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:at_client/at_client.dart';
import 'package:at_policy/at_policy.dart';
import 'package:chalkdart/chalk.dart';
import 'package:ogentic/common.dart';

void main(List<String> args) async {
  await runZonedGuarded(() async {
    try {
      if (!args.join(' ').contains(' -n ')) {
        args = List.from(args)..addAll(['-n', Consts.defaultNameSpace]);
      }
      final parser = CLIBase.argsParser;
      final String defaultConfigFilePath = './ai_talk_policy.conf';
      parser.addOption(
        'config',
        abbr: 'c',
        mandatory: false,
        defaultsTo: defaultConfigFilePath,
        help: 'Path to your config file (defaults to $defaultConfigFilePath)\n'
            'Each line in your config file should look like this:\n'
            '@atsign,@atsign,@atsign <tab> Additional context info goes here',
      );
      final parsedArgs = parser.parse(args);
      final cli = await CLIBase.fromCommandLineArgs(args, parser: parser);
      final atClient = cli.atClient;

      PolicyService ps = PolicyService(
        baseNamespace: atClient.getPreferences()!.namespace!,
        policyRequestNamespace: Consts.policySubNameSpace,
        loggingAtsign: atClient.getCurrentAtSign()!,
        allowList: {},
        allowAll: true,
        atClient: atClient,
        handler: DemoPolicyRequestHandler(parsedArgs['config']),
      );

      await ps.run();
    } catch (e) {
      print(e);
      print(CLIBase.argsParser.usage.replaceAll(RegExp('--namespace.*(mandatory).*\n'), '--namespace                Namespace\n'));
      exit(1);
    }
  }, (error, stackTrace) {
    stderr.writeln('Uncaught error: $error');
    stderr.writeln(stackTrace.toString());
  });
}

class DemoPolicyRequestHandler implements PolicyRequestHandler {
  Map<String, String> policies = {};

  DemoPolicyRequestHandler(String configFilePath) {
    File configFile = File(configFilePath);
    if (!configFile.existsSync()) {
      throw IllegalArgumentException(
        'Cannot find config file $configFilePath',
      );
    }
    for (final line in configFile.readAsLinesSync()) {
      if (!line.contains('\t')) {
        throw IllegalArgumentException(
          'Config file must contain lines'
          ' which contain at least one tab delimiter',
        );
      }

      String additionalContext = line.substring(line.indexOf('\t') + 1).trim();

      List<String> atSigns =
          line.substring(0, line.indexOf('\t')).trim().split(',');
      for (String atSign in atSigns) {
        atSign = atSign.toAtsign();
        policies[atSign] = additionalContext;
      }
    }
  }

  @override
  Future<PolicyResponse> getPolicyDetails(PolicyRequest req) async {
    stdout.writeln(chalk.blue('Received request $req'));

    PolicyIntent? intent = req.infoForIntent(Consts.contextIntent);
    if (intent == null) {
      throw IllegalArgumentException(
        'Intent ${Consts.contextIntent}'
        ' is required but was not supplied',
      );
    }
    if (policies.containsKey(req.clientAtsign)) {
      return PolicyResponse(
        message: 'Found details'
            ' for policy intent ${intent.intent}'
            ' for client atSign ${req.clientAtsign}',
        policyDetails: [
          PolicyDetail(
              intent: intent.intent,
              info: {'additionalContext': policies[req.clientAtsign]}),
        ],
      );
    } else {
      return PolicyResponse(
        message: 'No info found for client atSign ${req.clientAtsign}',
        policyDetails: [],
      );
    }
  }
}
