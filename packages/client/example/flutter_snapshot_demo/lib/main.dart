import 'package:flutter/material.dart';
import 'package:openfeature_provider_intellitoggle_client/openfeature_provider_intellitoggle_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final provider = IntelliToggleClientProvider.fromValues({
    'conference-demo': true,
    'experience': 'FlutterConf LATAM beta preview',
  });
  await OpenFeatureAPI.instance.setProviderAndWait(provider);
  runApp(IntelliToggleDemo(provider: provider));
}

class IntelliToggleDemo extends StatefulWidget {
  const IntelliToggleDemo({required this.provider, super.key});

  final IntelliToggleClientProvider provider;

  @override
  State<IntelliToggleDemo> createState() => _IntelliToggleDemoState();
}

class _IntelliToggleDemoState extends State<IntelliToggleDemo> {
  late final OpenFeatureClient _client = OpenFeatureAPI.instance.getClient();

  void _toggleDemo() {
    final current = _client.getBooleanValue('conference-demo', false);
    widget.provider.replaceValues({
      'conference-demo': !current,
      'experience': 'FlutterConf LATAM beta preview',
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _client.getBooleanValue('conference-demo', false);
    final experience = _client.getStringValue('experience', 'Beta preview');
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IntelliToggle + OpenFeature beta',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff6750a4)),
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Real provider beta validation')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(experience, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Text(
                    enabled ? 'Feature enabled' : 'Feature disabled',
                    key: const Key('flag-status'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _toggleDemo,
                    child: const Text('Replace backend snapshot'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'The app receives resolved values only. No IntelliToggle '
                    'client secret or targeting rule is shipped to Flutter.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
