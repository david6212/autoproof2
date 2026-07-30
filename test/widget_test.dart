// Basic smoke test for the AutoProof placeholder scaffold.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:otov/presentation/widgets/placeholder_scaffold.dart';

void main() {
  testWidgets('PlaceholderScaffold shows its title', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PlaceholderScaffold(title: 'בדיקה'),
      ),
    );

    expect(find.text('בדיקה'), findsWidgets);
  });
}
