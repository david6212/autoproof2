import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';

/// "פרסום רכב", floating over the listings.
///
/// Publishing used to be reachable from the profile menu and from the seller
/// area — both of which you have to already know exist. Somebody browsing
/// listings who realises they could sell theirs too had no way in from the
/// screen they were on, and a visitor without an account had no way in at all.
///
/// It is deliberately not gated. The flow's first step is a plate and the
/// registry's answer about the reader's own car, which costs us nothing to
/// show and is the most persuasive thing we have; the account is asked for at
/// the last step, where the reason for it is on screen. A button that opened a
/// login wall would be a worse version of no button.
class PublishFab extends StatelessWidget {
  const PublishFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'publish-fab',
      onPressed: () => context.push('/seller/create'),
      backgroundColor: context.colors.tealFill,
      foregroundColor: context.colors.onBrand,
      // The fill token and its paired ink, not the identity green: white on
      // #558B6E measures 3.96:1 and this carries a label.
      icon: const Icon(Icons.directions_car),
      label: const Text('פרסום רכב'),
    );
  }
}
