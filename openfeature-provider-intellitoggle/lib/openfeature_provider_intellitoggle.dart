// SPDX-License-Identifier: Apache-2.0

/// Main entry point for the IntelliToggle OpenFeature provider package.
///
/// Exports all public provider, client, context, event, and utility classes.
///
/// See https://intellitoggle.com and https://openfeature.dev for documentation.

/// IntelliToggle provider for OpenFeature Dart Server SDK
library openfeature_provider_intellitoggle;

export 'src/provider.dart';
export 'src/client.dart';
export 'src/options.dart';
export 'src/context.dart';
export 'src/events.dart';
export 'src/in_memory_provider.dart';
export 'src/console_logging_hook.dart';
export 'src/utils.dart'
    show
        IntelliToggleUtils,
        FlagNotFoundException,
        AuthenticationException,
        ApiException;

// Re-export OpenFeature types
export 'package:openfeature_dart_server_sdk/open_feature_api.dart';
export 'package:openfeature_dart_server_sdk/evaluation_context.dart';
// export 'package:openfeature_dart_server_sdk/feature_provider.dart';
export 'package:openfeature_dart_server_sdk/client.dart';
