import 'package:flutter/material.dart';

import '../../widgets/placeholder_scaffold.dart';

class BookInspectionScreen extends StatelessWidget {
  const BookInspectionScreen({super.key, required this.inspectorId});

  final String inspectorId;

  @override
  Widget build(BuildContext context) => PlaceholderScaffold(
        title: 'הזמנת בדיקה',
        subtitle: 'inspectorId: $inspectorId',
      );
}
