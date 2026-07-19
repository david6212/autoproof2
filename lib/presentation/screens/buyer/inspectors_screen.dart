import 'package:flutter/material.dart';

import '../../widgets/placeholder_scaffold.dart';

class InspectorsScreen extends StatelessWidget {
  const InspectorsScreen({super.key, required this.carId});

  final String carId;

  @override
  Widget build(BuildContext context) =>
      PlaceholderScaffold(title: 'בודקי רכב', subtitle: 'carId: $carId');
}
