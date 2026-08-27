import 'package:flutter_test/flutter_test.dart';
import 'package:intellitoggle_flutter_beta_demo/main.dart';
import 'package:openfeature_provider_intellitoggle_client/openfeature_provider_intellitoggle_client.dart';

void main() {
  late IntelliToggleClientProvider provider;

  setUp(() async {
    await OpenFeatureAPI.instance.shutdown();
    provider = IntelliToggleClientProvider.fromValues({
      'conference-demo': true,
      'experience': 'FlutterConf LATAM beta preview',
    });
    await OpenFeatureAPI.instance.setProviderAndWait(provider);
  });

  tearDown(() async {
    await OpenFeatureAPI.instance.shutdown();
  });

  testWidgets('replaces a real IntelliToggle provider snapshot', (tester) async {
    await tester.pumpWidget(IntelliToggleDemo(provider: provider));
    expect(find.text('Feature enabled'), findsOneWidget);

    await tester.tap(find.text('Replace backend snapshot'));
    await tester.pump();

    expect(find.text('Feature disabled'), findsOneWidget);
  });
}
