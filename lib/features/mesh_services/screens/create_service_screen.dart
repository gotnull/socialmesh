// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Create Service screen.
///
/// Entry point for service creation. Delegates to the canonical
/// type-first wizard flow.
library;

import 'package:flutter/material.dart';

// GuidedFlowScaffold in ServiceCreationWizard wraps GlassScaffold.
import 'service_creation_wizard.dart';

class CreateServiceScreen extends StatelessWidget {
  const CreateServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ServiceCreationWizard();
  }
}
