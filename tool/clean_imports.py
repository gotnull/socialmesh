import pathlib

removals = {
    'lib/features/admin/conformance/conformance_exporter.dart': [
        "import 'package:socialmesh/l10n/app_localizations.dart';",
    ],
    'lib/providers/auth_providers.dart': [
        "import 'dart:ui';",
        "import 'dart:ui' show PlatformDispatcher;",
        "import 'package:socialmesh/l10n/app_localizations.dart';",
    ],
    'lib/providers/connection_providers.dart': [
        "import 'dart:ui';",
        "import 'dart:ui' show PlatformDispatcher;",
        "import 'package:socialmesh/l10n/app_localizations.dart';",
    ],
    'lib/services/deep_link/deep_link_types.dart': [
        "import 'dart:ui';",
        "import 'dart:ui' show PlatformDispatcher;",
        "import 'package:socialmesh/l10n/app_localizations.dart';",
    ],
    'lib/services/mesh_health/mesh_health_analyzer.dart': [
        "import 'dart:ui';",
        "import 'dart:ui' show PlatformDispatcher;",
        "import 'package:socialmesh/l10n/app_localizations.dart';",
    ],
    'lib/services/messaging/offline_queue_service.dart': [
        "import 'dart:ui';",
        "import 'dart:ui' show PlatformDispatcher;",
        "import 'package:socialmesh/l10n/app_localizations.dart';",
    ],
}

for path, imports in removals.items():
    p = pathlib.Path(path)
    lines = p.read_text().splitlines(keepends=True)
    new_lines = [l for l in lines if l.rstrip('\n') not in imports]
    p.write_text(''.join(new_lines))
    print(f'Cleaned: {path}')
