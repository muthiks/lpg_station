import 'package:flutter/material.dart';
import 'package:lpg_station/models/receive_model.dart';
import 'package:lpg_station/theme/theme.dart';
import 'package:lpg_station/widget/success_dialog.dart';

class ReceiveStockBottomSheet extends StatefulWidget {
  final Receive receive;
  final VoidCallback onSuccess;

  const ReceiveStockBottomSheet({
    super.key,
    required this.receive,
    required this.onSuccess,
  });

  @override
  State<ReceiveStockBottomSheet> createState() =>
      _ReceiveStockBottomSheetState();
}

class _ReceiveStockBottomSheetState extends State<ReceiveStockBottomSheet> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _hasError = {};

  // ✅ Fix 1: listen to controllers so button reacts to onTap auto-fill too
  bool get _hasAnyInput =>
      _controllers.values.any((c) => c.text.trim().isNotEmpty);

  bool _hasErrors() => _hasError.values.any((e) => e);

  @override
  void initState() {
    super.initState();

    for (final c in widget.receive.cylinders) {
      final controller = TextEditingController(text: '');
      // ✅ Fix 1: add listener so setState fires on every change including onTap fill
      controller.addListener(() => setState(() {}));
      _controllers[c.cylinderType] = controller;
      _hasError[c.cylinderType] = false;
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // ✅ Fix 2: keeps button above system nav bar
      child: Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _header(),

            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: widget.receive.cylinders.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: Colors.white24),
                itemBuilder: (_, index) {
                  final c = widget.receive.cylinders[index];
                  final locked = c.undeliveredCount == 0;

                  return Opacity(
                    opacity: locked ? 0.5 : 1,
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                c.cylinderType,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              _expectedBadge(c.undeliveredCount),
                            ],
                          ),
                        ),

                        SizedBox(
                          width: 90,
                          child: TextField(
                            controller: _controllers[c.cylinderType],
                            enabled: !locked,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Qty',
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              errorText: _hasError[c.cylinderType]!
                                  ? ' '
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),

                            // ✅ Auto-fill on tap — listener above handles button state
                            onTap: () {
                              if (_controllers[c.cylinderType]!.text.isEmpty) {
                                _controllers[c.cylinderType]!.text = c
                                    .undeliveredCount
                                    .toString();
                              }
                            },

                            onChanged: (val) {
                              final entered = int.tryParse(val) ?? 0;
                              setState(() {
                                _hasError[c.cylinderType] =
                                    entered > c.undeliveredCount;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ✅ Fix 2: button stays inside safe area, never hidden by nav bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _hasAnyInput && !_hasErrors() ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    disabledBackgroundColor: AppTheme.primaryOrange.withOpacity(
                      0.4,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Confirm Receipt',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2, color: Colors.orange),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Receive Stock',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _expectedBadge(int qty) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primaryOrange,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        qty.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _submit() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SuccessDialog(),
    );

    Navigator.pop(context);
    widget.onSuccess();
  }

  Map<String, dynamic> _buildPayload() {
    final items = <Map<String, dynamic>>[];

    for (final c in widget.receive.cylinders) {
      final text = _controllers[c.cylinderType]!.text.trim();
      if (text.isNotEmpty) {
        final qty = int.tryParse(text) ?? 0;
        if (qty > 0) {
          items.add({'cylinderType': c.cylinderType, 'quantity': qty});
        }
      }
    }

    return {'receiveId': widget.receive.saleID, 'items': items};
  }
}
