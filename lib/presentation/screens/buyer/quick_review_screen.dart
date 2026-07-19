import 'package:flutter/material.dart';

import '../../widgets/placeholder_scaffold.dart';

class QuickReviewScreen extends StatelessWidget {
  const QuickReviewScreen({super.key, required this.carId});

  final String carId;

  @override
  Widget build(BuildContext context) =>
      PlaceholderScaffold(title: 'עזרה לקונה', subtitle: 'carId: $carId');
}
