import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SidePanel extends StatefulWidget {
  final bool expanded;
  final Function(bool) onExpandToggle;
  final Function(DateTime?) onDateSelected;
  final DateTime? selectedDate;
  final VoidCallback onLogout;
  final VoidCallback onDeleteAll;

  const SidePanel({
    required this.expanded,
    required this.onExpandToggle,
    required this.onDateSelected,
    required this.selectedDate,
    required this.onLogout,
    required this.onDeleteAll,
    super.key,
  });

  @override
  State<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<SidePanel> {
  late Future<List<DateTime>> _datesFuture;

  @override
  void initState() {
    super.initState();
    _datesFuture = _fetchOrderDates();
  }

  Future<List<DateTime>> _fetchOrderDates() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('orders')
        .orderBy('timestamp', descending: true)
        .get();

    final Set<String> dateStrings = {};
    for (var doc in snapshot.docs) {
      final ts = doc['timestamp'];
      if (ts != null) {
        final dt = ts.toDate();
        dateStrings.add(DateFormat('yyyy-MM-dd').format(dt));
      }
    }
    final dates = dateStrings
        .map((s) => DateFormat('yyyy-MM-dd').parse(s))
        .toList()
      ..sort((a, b) => b.compareTo(a)); // Descending

    return dates;
  }

  @override
  Widget build(BuildContext context) {
    final double width = widget.expanded ? 230 : 56;
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: Duration(milliseconds: 250),
      width: width,
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              border: Border(
                right: BorderSide(
                  color: Colors.white.withOpacity(0.08),
                  width: 1.5,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 18,
                  offset: Offset(4, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Expand/Collapse button
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: Icon(widget.expanded ? Icons.chevron_left : Icons.chevron_right, color: Colors.white70),
                    onPressed: () => widget.onExpandToggle(!widget.expanded),
                  ),
                ),
                if (widget.expanded)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      "Orders",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                Expanded(
                  child: FutureBuilder<List<DateTime>>(
                    future: _datesFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(child: CircularProgressIndicator(color: Colors.white24));
                      }
                      final dates = snapshot.data!;
                      final today = DateTime.now();
                      final todayStr = DateFormat('yyyy-MM-dd').format(today);

                      // Always show "Today"
                      final List<Widget> dateTiles = [
                        _dateTile(
                          label: "Today",
                          date: today,
                          selected: widget.selectedDate == null ||
                              DateFormat('yyyy-MM-dd').format(widget.selectedDate!) == todayStr,
                        ),
                      ];

                      // Add previous dates (skip today)
                      for (final dt in dates) {
                        final dtStr = DateFormat('yyyy-MM-dd').format(dt);
                        if (dtStr != todayStr) {
                          dateTiles.add(_dateTile(
                            label: DateFormat('EEE, MMM d').format(dt),
                            date: dt,
                            selected: widget.selectedDate != null &&
                                DateFormat('yyyy-MM-dd').format(widget.selectedDate!) == dtStr,
                          ));
                        }
                      }

                      return ListView(
                        padding: EdgeInsets.only(top: 8, left: 4, right: 4),
                        children: dateTiles,
                      );
                    },
                  ),
                ),
                if (widget.expanded)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8),
                    child: Column(
                      children: [
                        Divider(color: Colors.white24),
                        ListTile(
                          leading: Icon(Icons.delete_forever, color: Colors.redAccent),
                          title: Text("Delete All", style: TextStyle(color: Colors.redAccent)),
                          onTap: widget.onDeleteAll,
                          dense: true,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        ListTile(
                          leading: Icon(Icons.logout, color: Colors.white70),
                          title: Text("Logout", style: TextStyle(color: Colors.white70)),
                          onTap: widget.onLogout,
                          dense: true,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateTile({required String label, required DateTime date, required bool selected}) {
    return ListTile(
      leading: Icon(Icons.calendar_today, color: selected ? Colors.purpleAccent : Colors.white38, size: 22),
      title: widget.expanded
          ? Text(label, style: TextStyle(color: selected ? Colors.purpleAccent : Colors.white70, fontWeight: selected ? FontWeight.bold : FontWeight.normal))
          : null,
      onTap: () => widget.onDateSelected(label == "Today" ? null : date),
      selected: selected,
      selectedTileColor: Colors.purpleAccent.withOpacity(0.08),
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: EdgeInsets.symmetric(horizontal: 8),
    );
  }
}