import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/user_address.dart';
import 'addresses_provider.dart';

class AddressPickerWidget extends ConsumerWidget {
  const AddressPickerWidget({
    super.key,
    required this.onAddressSelected,
    required this.onNewAddress,
    this.selectedAddressId,
  });

  final void Function(UserAddress address) onAddressSelected;
  final VoidCallback onNewAddress;
  final String? selectedAddressId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(userAddressesProvider);

    return addressesAsync.when(
      data: (addresses) {
        if (addresses.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Direcciones guardadas',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...addresses.map(
                  (addr) => ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          addr.label == AddressLabel.casa
                              ? Icons.home
                              : addr.label == AddressLabel.oficina
                              ? Icons.business
                              : Icons.place,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(addr.displayLabel),
                        if (addr.isDefault) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                        ],
                      ],
                    ),
                    selected: selectedAddressId == addr.id,
                    onSelected: (_) => onAddressSelected(addr),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Nueva'),
                  onPressed: onNewAddress,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}
