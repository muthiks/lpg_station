import 'package:flutter/material.dart';
import 'package:lpg_station/models/receive_model.dart';
import 'package:lpg_station/services/api_service.dart';
import 'package:lpg_station/widget/receive_bottom_sheet.dart';
import 'package:lpg_station/widget/receive_card.dart';

class ReceiveStockScreen extends StatefulWidget {
  const ReceiveStockScreen({super.key});

  @override
  State<ReceiveStockScreen> createState() => _ReceiveStockScreenState();
}

class _ReceiveStockScreenState extends State<ReceiveStockScreen> {
  late Future<List<Receive>> receiptsFuture;

  @override
  void initState() {
    super.initState();
    receiptsFuture = ApiService.fetchPendingReceipts();
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
                  receiptsFuture = ApiService.fetchPendingReceipts();
                });
              },
              child: ListView.separated(
                separatorBuilder: (_, _) => const Divider(color: Colors.white),
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
            receiptsFuture = ApiService.fetchPendingReceipts();
          });
        },
      ),
    );
  }
}
