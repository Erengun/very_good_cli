// Expected usage of the plugin will need to be adjacent strings due to format
// and also be longer than 80 chars.
// ignore_for_file: no_adjacent_strings_in_list, lines_longer_than_80_chars

import 'dart:io';

import 'package:args/args.dart';
import 'package:mason/mason.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:very_good_cli/src/commands/commands.dart';

import '../../../../helpers/helpers.dart';

class _MockLogger extends Mock implements Logger {}

class _MockProgress extends Mock implements Progress {}

class _MockMasonGenerator extends Mock implements MasonGenerator {}

class _MockGeneratorHooks extends Mock implements GeneratorHooks {}

class _MockArgResults extends Mock implements ArgResults {}

class _FakeLogger extends Fake implements Logger {}

class _FakeDirectoryGeneratorTarget extends Fake
    implements DirectoryGeneratorTarget {}

final expectedUsage = [
  'Generate a Very Good Flutter plugin.\n'
      '\n'
      'Usage: very_good create flutter_plugin <project-name> [arguments]\n'
      '-h, --help                       Print this usage information.\n'
      '-o, --output-directory           The desired output directory when creating a new project.\n'
      '    --description                The description for this new project.\n'
      '                                 (defaults to "A Very Good Project created by Very Good CLI.")\n'
      '    --org-name                   The organization for this new project.\n'
      '                                 (defaults to "com.example.verygoodcore")\n'
      '    --publishable                Whether the generated project is intended to be published.\n'
      '    --platforms                  The platforms supported by the plugin. By default, all platforms are enabled. Example: --platforms=android,ios\n'
      '\n'
      '          [android] (default)    The plugin supports the Android platform.\n'
      '          [ios] (default)        The plugin supports the iOS platform.\n'
      '          [web] (default)        The plugin supports the Web platform.\n'
      '          [linux] (default)      The plugin supports the Linux platform.\n'
      '          [macos] (default)      The plugin supports the macOS platform.\n'
      '          [windows] (default)    The plugin supports the Windows platform.\n'
      '\n'
      'Run "very_good help" to see global options.',
];

const pubspec = '''
name: example
environment:
  sdk: ^3.8.0
''';

void main() {
  late Logger logger;

  setUpAll(() {
    registerFallbackValue(_FakeDirectoryGeneratorTarget());
    registerFallbackValue(_FakeLogger());
  });

  setUp(() {
    logger = _MockLogger();

    final progress = _MockProgress();

    when(() => logger.progress(any())).thenReturn(progress);
  });

  group('can be instantiated', () {
    test('with default options', () {
      final logger = Logger();
      final command = CreateFlutterPlugin(
        logger: logger,
        generatorFromBundle: null,
        generatorFromBrick: null,
      );
      expect(command.name, equals('flutter_plugin'));
      expect(
        command.description,
        equals('Generate a Very Good Flutter plugin.'),
      );
      expect(command.logger, equals(logger));
      expect(command, isA<Publishable>());
      expect(command.argParser.options, contains('platforms'));
    });
  });

  group('create flutter_plugin', () {
    test(
      'help',
      withRunner((commandRunner, logger, pubUpdater, printLogs) async {
        final result = await commandRunner.run([
          'create',
          'flutter_plugin',
          '--help',
        ]);
        expect(printLogs, equals(expectedUsage));
        expect(result, equals(ExitCode.success.code));

        printLogs.clear();

        final resultAbbr = await commandRunner.run([
          'create',
          'flutter_plugin',
          '-h',
        ]);
        expect(printLogs, equals(expectedUsage));
        expect(resultAbbr, equals(ExitCode.success.code));
      }),
    );

    group('running the command', () {
      final generatedFiles = List.filled(
        10,
        const GeneratedFile.created(path: ''),
      );

      late GeneratorHooks hooks;
      late MasonGenerator generator;

      setUp(() {
        hooks = _MockGeneratorHooks();
        generator = _MockMasonGenerator();

        when(() => generator.hooks).thenReturn(hooks);
        when(
          () => hooks.preGen(
            vars: any(named: 'vars'),
            onVarsChanged: any(named: 'onVarsChanged'),
          ),
        ).thenAnswer((_) async {});

        when(
          () => generator.generate(
            any(),
            vars: any(named: 'vars'),
            logger: any(named: 'logger'),
          ),
        ).thenAnswer((_) async {
          return generatedFiles;
        });

        when(() => generator.id).thenReturn('generator_id');
        when(() => generator.description).thenReturn('generator description');
        when(() => generator.hooks).thenReturn(hooks);

        when(
          () => hooks.preGen(
            vars: any(named: 'vars'),
            onVarsChanged: any(named: 'onVarsChanged'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => generator.generate(
            any(),
            vars: any(named: 'vars'),
            logger: any(named: 'logger'),
          ),
        ).thenAnswer((invocation) async {
          final target =
              invocation.positionalArguments.first as DirectoryGeneratorTarget;
          File(path.join(target.dir.path, 'my_plugin', 'pubspec.yaml'))
            ..createSync(recursive: true)
            ..writeAsStringSync(pubspec);
          return generatedFiles;
        });
      });

      test('creates a flutter plugin', () async {
        final tempDirectory = Directory.systemTemp.createTempSync();
        addTearDown(() => tempDirectory.deleteSync(recursive: true));

        final argResults = _MockArgResults();
        final command = CreateFlutterPlugin(
          logger: logger,
          generatorFromBundle: (_) async => throw Exception('oops'),
          generatorFromBrick: (_) async => generator,
        )..argResultOverrides = argResults;
        when(
          () => argResults['output-directory'] as String?,
        ).thenReturn(tempDirectory.path);
        when(() => argResults.rest).thenReturn(['my_plugin']);
        when(
          () => argResults['platforms'] as List<String>,
        ).thenReturn(['android', 'ios', 'windows']);

        final result = await command.run();

        expect(command.template.name, 'flutter_plugin');
        expect(result, equals(ExitCode.success.code));

        verify(() => logger.progress('Bootstrapping')).called(1);
        verify(
          () => hooks.preGen(
            vars: <String, dynamic>{
              'project_name': 'my_plugin',
              'description': '',
              'org_name': 'com.example.verygoodcore',
              'publishable': false,
              'platforms': ['android', 'ios', 'windows'],
            },
            onVarsChanged: any(named: 'onVarsChanged'),
          ),
        );
        verify(
          () => generator.generate(
            any(),
            vars: <String, dynamic>{
              'project_name': 'my_plugin',
              'description': '',
              'org_name': 'com.example.verygoodcore',
              'publishable': false,
              'platforms': ['android', 'ios', 'windows'],
            },
            logger: logger,
          ),
        ).called(1);
        verify(
          () => logger.info('Created a Very Good Flutter Plugin! 🦄'),
        ).called(1);
      });
    });
  });
}
