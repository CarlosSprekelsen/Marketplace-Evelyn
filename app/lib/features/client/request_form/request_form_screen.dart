import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/price_quote.dart';
import '../../../shared/models/service_request_model.dart';
import '../../../shared/models/user_address.dart';
import '../../../shared/utils/date_formatter.dart';
import '../../auth/state/auth_notifier.dart';
import '../addresses/address_picker_widget.dart';
import '../addresses/addresses_provider.dart';
import '../state/client_requests_providers.dart';

class RequestFormScreen extends ConsumerStatefulWidget {
  const RequestFormScreen({
    super.key,
    this.prefillDistrictId,
    this.prefillHours,
  });

  final String? prefillDistrictId;
  final int? prefillHours;

  @override
  ConsumerState<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends ConsumerState<RequestFormScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _districtId;
  String? _selectedAddressId;
  UserAddress? _selectedAddress;
  int _hours = 1;
  DateTime? _scheduledAt;
  PriceQuote? _quote;
  bool _loadingQuote = false;
  bool _submitting = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    if (widget.prefillDistrictId != null) {
      _districtId = widget.prefillDistrictId;
    }
    if (widget.prefillHours != null) {
      _hours = widget.prefillHours!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final districtsAsync = ref.watch(districtsProvider);
    final addressesAsync = ref.watch(userAddressesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitar Limpieza'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  districtsAsync.when(
                    data: (districts) {
                      final selectedDistrict = districts.where((d) => d.id == _districtId).firstOrNull;
                      final districtLocked = _selectedAddressId != null;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _districtId,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Distrito',
                            ),
                            items: districts
                                .map((district) {
                                  return DropdownMenuItem<String>(
                                    value: district.id,
                                    child: Text(district.name),
                                  );
                                })
                                .toList(growable: false),
                            onChanged: districtLocked
                                ? null
                                : (value) {
                                    setState(() {
                                      _districtId = value;
                                      _quote = null;
                                    });
                                    _fetchQuoteIfReady();
                                  },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Selecciona un distrito';
                              }
                              return null;
                            },
                          ),
                          if (selectedDistrict != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  selectedDistrict.hasActiveProviders
                                      ? Icons.check_circle
                                      : Icons.warning_amber_rounded,
                                  size: 16,
                                  color: selectedDistrict.hasActiveProviders
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    selectedDistrict.hasActiveProviders
                                        ? 'Hay proveedores activos en este distrito'
                                        : 'No hay proveedores activos — tu solicitud podría expirar',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: selectedDistrict.hasActiveProviders
                                          ? Colors.green.shade700
                                          : Colors.orange.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => Text(
                      'No se pudo cargar distritos: ${mapDioErrorToMessage(error)}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  const SizedBox(height: 12),
                  addressesAsync.when(
                    data: (addresses) {
                      if (addresses.isEmpty) {
                        return Card(
                          color: Colors.orange.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Primero agrega una dirección',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () => context.push('/client/addresses'),
                                  icon: const Icon(Icons.add_location_alt_outlined),
                                  label: const Text('Ir a mis direcciones'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AddressPickerWidget(
                            selectedAddressId: _selectedAddressId,
                            onAddressSelected: (addr) {
                              setState(() {
                                _selectedAddressId = addr.id;
                                _selectedAddress = addr;
                                _districtId = addr.districtId;
                                _quote = null;
                              });
                              _fetchQuoteIfReady();
                            },
                            onNewAddress: () {
                              setState(() {
                                _selectedAddressId = null;
                                _selectedAddress = null;
                                _districtId = null;
                                _quote = null;
                              });
                              context.push('/client/addresses');
                            },
                          ),
                          if (_selectedAddress != null)
                            _SelectedAddressSummaryCard(
                              address: _selectedAddress!,
                              districtName: _selectedAddress!.district?.name ??
                                  districtsAsync
                                      .asData
                                      ?.value
                                      .where((d) => d.id == _selectedAddress!.districtId)
                                      .firstOrNull
                                      ?.name,
                            ),
                        ],
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    ),
                    error: (error, _) => Text(
                      'No se pudo cargar direcciones: ${mapDioErrorToMessage(error)}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _hours,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Horas',
                    ),
                    items: List<int>.generate(8, (index) => index + 1)
                        .map(
                          (hours) => DropdownMenuItem<int>(
                            value: hours,
                            child: Text('$hours hora(s)'),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      setState(() {
                        _hours = value ?? 1;
                        _quote = null;
                      });
                      _fetchQuoteIfReady();
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _pickDateTime,
                    child: Text(
                      _scheduledAt == null
                          ? 'Seleccionar fecha y hora'
                          : 'Fecha: ${formatDateTime(_scheduledAt!)}',
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_loadingQuote)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  if (_quote != null) ...[
                    Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _quote!.districtName,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_quote!.hours} hora${_quote!.hours == 1 ? '' : 's'} x ${formatPrice(_quote!.pricePerHour, _quote!.currency)}/hora',
                              style: const TextStyle(fontSize: 15),
                            ),
                            const Divider(height: 20),
                            Text(
                              'Total: ${formatPrice(_quote!.priceTotal, _quote!.currency)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _message!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  FilledButton(
                    onPressed: _submitting ? null : _onConfirmPressed,
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Confirmar Solicitud'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _fetchQuoteIfReady() async {
    final districtId = _districtId;
    if (districtId == null || districtId.isEmpty) return;

    setState(() {
      _loadingQuote = true;
      _message = null;
    });

    try {
      final repo = ref.read(clientRequestsRepositoryProvider);
      final quote = await repo.getQuote(districtId: districtId, hours: _hours);
      if (mounted) setState(() => _quote = quote);
    } catch (error) {
      if (mounted) setState(() => _message = mapDioErrorToMessage(error));
    } finally {
      if (mounted) setState(() => _loadingQuote = false);
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) {
      return;
    }

    final selectedMinute = await _pickSlotMinute();
    if (selectedMinute == null || !mounted) {
      return;
    }

    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        selectedMinute ~/ 60,
        selectedMinute % 60,
      );
    });
  }

  Future<int?> _pickSlotMinute() async {
    final slots = <TimeOfDay>[];
    for (int h = 6; h <= 21; h++) {
      slots.add(TimeOfDay(hour: h, minute: 0));
      if (h < 21) {
        slots.add(TimeOfDay(hour: h, minute: 30));
      }
    }

    return showDialog<int>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Selecciona hora'),
          children: slots.map((slot) {
            final label =
                '${slot.hour.toString().padLeft(2, '0')}:${slot.minute.toString().padLeft(2, '0')}';
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(context, slot.hour * 60 + slot.minute),
              child: Text(label, style: const TextStyle(fontSize: 16)),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _onConfirmPressed() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final selectedAddress = _selectedAddress;
    if (selectedAddress == null || _selectedAddressId == null) {
      setState(() => _message = 'Selecciona una dirección guardada');
      return;
    }
    final districtId = _districtId;
    if (districtId == null || districtId.isEmpty) {
      setState(() => _message = 'Selecciona un distrito');
      return;
    }
    if (_scheduledAt == null) {
      setState(() => _message = 'Selecciona fecha y hora');
      return;
    }

    setState(() {
      _submitting = true;
      _message = null;
    });

    try {
      final repo = ref.read(clientRequestsRepositoryProvider);
      final request = await repo.createRequest(
        districtId: districtId,
        addressId: _selectedAddressId,
        addressStreet: selectedAddress.addressStreet,
        addressNumber: selectedAddress.addressNumber,
        addressFloorApt: selectedAddress.addressFloorApt,
        addressReference: selectedAddress.addressReference,
        hoursRequested: _hours,
        scheduledAtLocal: _scheduledAt!,
      );
      if (!mounted) {
        return;
      }
      context.go('/client/requests/${request.id}');
    } catch (error) {
      setState(() => _message = mapDioErrorToMessage(error));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class _SelectedAddressSummaryCard extends StatelessWidget {
  const _SelectedAddressSummaryCard({
    required this.address,
    this.districtName,
  });

  final UserAddress address;
  final String? districtName;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.home_outlined, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address.displayLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(address.fullAddress),
                  if (districtName != null && districtName!.isNotEmpty)
                    Text(
                      districtName!,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
