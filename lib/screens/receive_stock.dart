import 'package:flutter/material.dart';
import 'package:lpg_station/models/receive_model.dart';
import 'package:lpg_station/services/api_service.dart';
import 'package:lpg_station/widget/receive_bottom_sheet.dart';
import 'package:lpg_station/widget/receive_card.dart';

class ReceiveStockScreen extends StatefulWidget {
  final void Function(int count)? onCountLoaded; // ✅ new

  const ReceiveStockScreen({super.key, this.onCountLoaded}); // ✅ updated

  @override
  State<ReceiveStockScreen> createState() => _ReceiveStockScreenState();
}

class _ReceiveStockScreenState extends State<ReceiveStockScreen> {
  late Future<List<Receive>> receiptsFuture;

  @override
  void initState() {
    super.initState();
    receiptsFuture = _fetchAndReport(); // ✅ use wrapper instead of direct call
  }

  // ✅ Fetches data and fires the count back to the parent tab
  Future<List<Receive>> _fetchAndReport() async {
    final results = await ApiService.fetchPendingReceipts();
    widget.onCountLoaded?.call(results.length);
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: FutureBuilder<List<Receive>>(
          future: receiptsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            final deliveries = snapshot.data!;

            if (deliveries.isEmpty) {
              return const Center(
                child: Text(
                  'No deliveries found',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  receiptsFuture =
                      _fetchAndReport(); // ✅ also report on refresh
                });
              },
              child: ListView.separated(
                separatorBuilder: (_, __) => const Divider(color: Colors.white),
                itemCount: deliveries.length,
                itemBuilder: (_, index) {
                  return ReceiveCard(
                    delivery: deliveries[index],
                    onTap: () => _openReceiveBottomSheet(deliveries[index]),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _openReceiveBottomSheet(Receive receive) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReceiveStockBottomSheet(
        receive: receive,
        onSuccess: () {
          setState(() {
            receiptsFuture = _fetchAndReport(); // ✅ also report after receiving
          });
        },
      ),
    );
  }
}
