import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/hvp_app_bar.dart';
import '../../../../core/widgets/hvp_button.dart';

/// Where the map opens when the branch has no position yet (Ho Chi Minh City centre).
const LatLng defaultBranchCenter = LatLng(10.7769, 106.7009);

/// "Mở bản đồ": tap the map to drop the pin, then confirm. Free OpenStreetMap
/// tiles, no API key. Pops with the chosen [LatLng], or null when cancelled.
class BranchMapPickerScreen extends StatefulWidget {
  const BranchMapPickerScreen({super.key, this.initial, this.tileProvider});

  final LatLng? initial;

  /// Tests pass a provider that draws no network tiles.
  final TileProvider? tileProvider;

  static Future<LatLng?> open(BuildContext context,
          {LatLng? initial, TileProvider? tileProvider}) =>
      Navigator.of(context).push<LatLng>(MaterialPageRoute<LatLng>(
          builder: (_) => BranchMapPickerScreen(
              initial: initial, tileProvider: tileProvider)));

  @override
  State<BranchMapPickerScreen> createState() => _BranchMapPickerScreenState();
}

class _BranchMapPickerScreenState extends State<BranchMapPickerScreen> {
  late LatLng? _picked = widget.initial;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final picked = _picked;
    return Scaffold(
      appBar: const HvpAppBar(title: 'Chọn vị trí', titleIcon: HvpIcons.mapPin),
      body: Column(
        children: <Widget>[
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: widget.initial ?? defaultBranchCenter,
                initialZoom: widget.initial == null ? 13 : 16,
                onTap: (_, point) => setState(() => _picked = point),
              ),
              children: <Widget>[
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'vn.hvp.hvp_forging',
                  tileProvider: widget.tileProvider,
                ),
                if (picked != null)
                  MarkerLayer(markers: <Marker>[
                    Marker(
                      point: picked,
                      width: 48,
                      height: 48,
                      alignment: Alignment.topCenter,
                      child: Icon(HvpIcons.mapPin, size: 44, color: c.red),
                    ),
                  ]),
                const RichAttributionWidget(
                  attributions: <SourceAttribution>[
                    TextSourceAttribution('© OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    picked == null
                        ? 'Chạm vào bản đồ để ghim vị trí chi nhánh.'
                        : 'Vĩ độ ${picked.latitude.toStringAsFixed(6)} · Kinh độ ${picked.longitude.toStringAsFixed(6)}',
                    style: t.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  HvpButton.primary(
                    label: 'Chọn vị trí này',
                    icon: HvpIcons.check,
                    expand: true,
                    onPressed: picked == null
                        ? null
                        : () => Navigator.of(context).pop(picked),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
