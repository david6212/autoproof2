import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../data/models/car_model.dart';

final _priceFmt = NumberFormat('#,###', 'en');

/// Public link to a listing.
String listingLink(CarModel car) => '${AppStrings.siteUrl}/#/car/${car.id}';

/// The text that gets forwarded.
///
/// Deliberately plain — make, year, price, the link. It makes no claim about
/// the seller or the car's condition, because a message pasted into WhatsApp
/// outlives every disclaimer on the page it came from
/// (BUSINESS_ROADMAP section 10).
String listingShareText(CarModel car) {
  return '${car.title}\n'
      '₪${_priceFmt.format(car.price)} · ${car.year} · '
      '${_priceFmt.format(car.km)} ק"מ · ${car.area}\n'
      '${listingLink(car)}';
}

/// Opens the platform share sheet for [car].
Future<void> shareListing(BuildContext context, CarModel car) async {
  final box = context.findRenderObject() as RenderBox?;
  try {
    await SharePlus.instance.share(
      ShareParams(
        text: listingShareText(car),
        subject: car.title,
        // iPad anchors the share popover to whatever opened it; without an
        // origin rect it throws instead of appearing.
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('לא הצלחנו לפתוח את תפריט השיתוף.')),
    );
  }
}

/// Icon form, for overlaying on a photo.
class ShareListingButton extends StatelessWidget {
  const ShareListingButton({
    super.key,
    required this.car,
    this.color = AppColors.textPrimary,
  });

  final CarModel car;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.ios_share, color: color),
      tooltip: 'שתף מודעה',
      onPressed: () => shareListing(context, car),
    );
  }
}
