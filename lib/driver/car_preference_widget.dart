import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mitsubishi/backend/api_requests/api_manager.dart';
import 'package:mitsubishi/widgets/notifications/app_notifications.dart';

import '/backend/api_requests/api_calls.dart';
import '/flutter_flow/flutter_flow_theme.dart';

class CarPreferenceWidget extends StatefulWidget {
  const CarPreferenceWidget({
    super.key,
    required this.driverId,
  });

  final int driverId;

  static String routeName = 'CarPreference';
  static String routePath = '/car-preference';

  @override
  State<CarPreferenceWidget> createState() => _CarPreferenceWidgetState();
}

class _CarPreferenceWidgetState extends State<CarPreferenceWidget> {
  final _searchCtrl = TextEditingController();
  bool _onlyFav = false;

  bool _isLoading = false;
  String? _errorMsg;

  final List<_CarPref> _items = [];

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
      _items.clear();
    });

    try {
      final resp = await DriversGetFavoriteCarsCall.call(
        driverId: widget.driverId,
        bearerToken: ApiManager.accessToken,
      );

      if (resp.succeeded) {
        final list = DriversGetFavoriteCarsCall.items(resp);

        for (final it in list) {
          final id = DriversGetFavoriteCarsCall.id(it) ?? -1;
          if (id <= 0) continue;

          final fav = DriversGetFavoriteCarsCall.isFavorite(it);
          final model = DriversGetFavoriteCarsCall.description(it) ?? '-';
          final km = DriversGetFavoriteCarsCall.km(it) ?? 0;
          final plate = DriversGetFavoriteCarsCall.plate(it) ?? '-';
          final color = DriversGetFavoriteCarsCall.color(it) ?? '-';

          _items.add(_CarPref(
            id: id,
            model: model,
            km: km,
            plate: plate,
            color: color,
            fav: fav,
          ));
        }
        setState(() {});
      } else {
        _errorMsg = 'Failed to load cars (${resp.statusCode}).';
        setState(() {});
      }
    } catch (e) {
      _errorMsg = 'Error loading cars: $e';
      setState(() {});
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFav(_CarPref car, bool value) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final token = ApiManager.accessToken ?? '';
      final res = await DriversFavorCarCall.call(
        bearerToken: token,
        driverId: widget.driverId,
        carId: car.id,
        isFavorite: value,
      );

      if (res.succeeded) {
        if (!mounted) return;
        AppNotifications.success(
          context,
          value ? 'Added to favorites' : 'Removed from favorites',
        );
        await _loadFirstPage();
      } else {
        if (!mounted) return;
        AppNotifications.error(context, 'Could not update favorite.');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      AppNotifications.error(context, 'Error updating favorite.');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final titleStyle = theme.bodyMedium.override(
      font: GoogleFonts.inter(fontWeight: FontWeight.w600),
      color: theme.primaryText,
      fontSize: 20,
    );

    final q = _searchCtrl.text.toLowerCase();
    final filtered = _items.where((c) {
      final hit = c.model.toLowerCase().contains(q) ||
          c.plate.toLowerCase().contains(q) ||
          c.color.toLowerCase().contains(q);
      return hit && (!_onlyFav || c.fav);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        title: Text('Car Preference', style: titleStyle),
        backgroundColor: theme.secondaryBackground,
        foregroundColor: theme.primaryText,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: _isLoading ? null : _loadFirstPage,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search for cars',
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                          BorderSide(color: theme.alternate.withOpacity(0.25)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _FavToggle(
                    value: _onlyFav,
                    onChanged: (v) => setState(() => _onlyFav = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_errorMsg != null)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline),
                        const SizedBox(height: 8),
                        Text(_errorMsg!),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadFirstPage,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final isCompact = c.maxWidth < 900;
                      if (filtered.isEmpty) {
                        return RefreshIndicator(
                          onRefresh: _loadFirstPage,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 120),
                              Center(child: Text('No cars found.')),
                              SizedBox(height: 12),
                              _EndFooter(),
                            ],
                          ),
                        );
                      }

                      if (isCompact) {
                        return RefreshIndicator(
                          onRefresh: _loadFirstPage,
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: filtered.length + 1,
                            separatorBuilder: (_, i) => i >= filtered.length
                                ? const SizedBox.shrink()
                                : const SizedBox(height: 12),
                            itemBuilder: (_, i) {
                              if (i == filtered.length) {
                                return const _EndFooter();
                              }
                              final item = filtered[i];
                              return _CarCard(
                                data: item,
                                onFavChanged: (v) => _toggleFav(item, v),
                              );
                            },
                          ),
                        );
                      } else {
                        return RefreshIndicator(
                          onRefresh: _loadFirstPage,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              children: [
                                _CarsTable(
                                  items: filtered,
                                  onFavChanged: (car, v) => _toggleFav(car, v),
                                ),
                                const SizedBox(height: 12),
                                const _EndFooter(),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EndFooter extends StatelessWidget {
  const _EndFooter();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Center(child: Text('End of list')),
    );
  }
}

class _FavToggle extends StatelessWidget {
  const _FavToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Show favorites only',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Color(0x11000000), blurRadius: 3, offset: Offset(0, 1))
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        height: 44,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, color: Colors.amber),
            const SizedBox(width: 6),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _CarPref {
  _CarPref({
    required this.id,
    required this.model,
    required this.km,
    required this.plate,
    required this.color,
    this.fav = false,
  });

  final int id;
  String model;
  int km;
  String plate;
  String color;
  bool fav;
}

class _CarCard extends StatelessWidget {
  const _CarCard({
    required this.data,
    required this.onFavChanged,
  });

  final _CarPref data;
  final ValueChanged<bool> onFavChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                data.model,
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF222222)),
              ),
              const SizedBox(height: 6),
              Text('Km: ${data.km} • Plate: ${data.plate}',
                  style: GoogleFonts.inter(
                      fontSize: 14, color: const Color(0xFF5B5B5B))),
              const SizedBox(height: 6),
              Text('Color: ${data.color}',
                  style: GoogleFonts.inter(
                      fontSize: 14, color: const Color(0xFF5B5B5B))),
            ]),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: () => onFavChanged(!data.fav),
                icon: Icon(
                  data.fav ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
                tooltip:
                data.fav ? 'Remove from favorites' : 'Add to favorites',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CarsTable extends StatelessWidget {
  const _CarsTable({
    required this.items,
    required this.onFavChanged,
  });

  final List<_CarPref> items;
  final void Function(_CarPref car, bool fav) onFavChanged;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: DataTable(
        headingRowColor: MaterialStatePropertyAll(theme.secondaryBackground),
        columns: const [
          DataColumn(label: Text('Model')),
          DataColumn(label: Text('Km')),
          DataColumn(label: Text('License Plate')),
          DataColumn(label: Text('Color')),
          DataColumn(label: Text('Favorite')),
        ],
        rows: List<DataRow>.generate(items.length, (i) {
          final c = items[i];
          return DataRow(cells: [
            DataCell(Text(c.model)),
            DataCell(Text('${c.km}')),
            DataCell(Text(c.plate)),
            DataCell(Text(c.color)),
            DataCell(
              IconButton(
                icon: Icon(c.fav ? Icons.star : Icons.star_border,
                    color: Colors.amber),
                onPressed: () => onFavChanged(c, !c.fav),
                tooltip:
                c.fav ? 'Remove from favorites' : 'Add to favorites',
              ),
            ),
          ]);
        }),
      ),
    );
  }
}
