import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/user_address.dart';
import '../../auth/state/auth_notifier.dart';
import '../state/client_requests_providers.dart';
import 'addresses_provider.dart';

class AddressesScreen extends ConsumerStatefulWidget {
  const AddressesScreen({super.key});

  @override
  ConsumerState<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends ConsumerState<AddressesScreen> {
  @override
  Widget build(BuildContext context) {
    final addressesAsync = ref.watch(userAddressesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Direcciones')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddressForm(context),
        child: const Icon(Icons.add),
      ),
      body: addressesAsync.when(
        data: (addresses) {
          if (addresses.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No tienes direcciones guardadas',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _showAddressForm(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar dirección'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(userAddressesProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: addresses.length,
              itemBuilder: (context, index) {
                final addr = addresses[index];
                return _AddressCard(
                  address: addr,
                  onEdit: () => _showAddressForm(context, existing: addr),
                  onDelete: () => _confirmDelete(addr),
                  onSetDefault: () => _setDefault(addr),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Error: ${mapDioErrorToMessage(error)}',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddressForm(BuildContext context, {UserAddress? existing}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _AddressFormSheet(existing: existing),
    );
    if (result == true) {
      ref.invalidate(userAddressesProvider);
    }
  }

  Future<void> _confirmDelete(UserAddress addr) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar dirección'),
        content: Text('¿Eliminar "${addr.displayLabel}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí, eliminar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final repo = ref.read(addressesRepositoryProvider);
      await repo.deleteAddress(addr.id);
      ref.invalidate(userAddressesProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${mapDioErrorToMessage(error)}')),
      );
    }
  }

  Future<void> _setDefault(UserAddress addr) async {
    try {
      final repo = ref.read(addressesRepositoryProvider);
      await repo.setDefault(addr.id);
      ref.invalidate(userAddressesProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${mapDioErrorToMessage(error)}')),
      );
    }
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  final UserAddress address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  address.label == AddressLabel.casa
                      ? Icons.home
                      : address.label == AddressLabel.oficina
                          ? Icons.business
                          : Icons.place,
                  size: 24,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address.displayLabel,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                if (address.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Predeterminada',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (address.district != null)
              Text(
                address.district!.name,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            const SizedBox(height: 4),
            Text(address.fullAddress, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!address.isDefault)
                  TextButton.icon(
                    onPressed: onSetDefault,
                    icon: const Icon(Icons.star_outline, size: 18),
                    label: const Text('Predeterminada'),
                  ),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Editar'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  label: const Text('Eliminar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressFormSheet extends ConsumerStatefulWidget {
  const _AddressFormSheet({this.existing});
  final UserAddress? existing;

  @override
  ConsumerState<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends ConsumerState<_AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late AddressLabel _label;
  late final TextEditingController _labelCustomCtrl;
  late final TextEditingController _streetCtrl;
  late final TextEditingController _numberCtrl;
  late final TextEditingController _floorAptCtrl;
  late final TextEditingController _referenceCtrl;
  String? _selectedDistrictId;
  bool _isDefault = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _label = e?.label ?? AddressLabel.casa;
    _labelCustomCtrl = TextEditingController(text: e?.labelCustom ?? '');
    _streetCtrl = TextEditingController(text: e?.addressStreet ?? '');
    _numberCtrl = TextEditingController(text: e?.addressNumber ?? '');
    _floorAptCtrl = TextEditingController(text: e?.addressFloorApt ?? '');
    _referenceCtrl = TextEditingController(text: e?.addressReference ?? '');
    _selectedDistrictId = e?.districtId;
    _isDefault = e?.isDefault ?? false;
  }

  @override
  void dispose() {
    _labelCustomCtrl.dispose();
    _streetCtrl.dispose();
    _numberCtrl.dispose();
    _floorAptCtrl.dispose();
    _referenceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final districtsAsync = ref.watch(districtsProvider);
    final isEditing = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEditing ? 'Editar dirección' : 'Nueva dirección',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Label selector
              const Text('Etiqueta', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SegmentedButton<AddressLabel>(
                segments: const [
                  ButtonSegment(value: AddressLabel.casa, label: Text('Casa'), icon: Icon(Icons.home)),
                  ButtonSegment(value: AddressLabel.oficina, label: Text('Oficina'), icon: Icon(Icons.business)),
                  ButtonSegment(value: AddressLabel.otro, label: Text('Otro'), icon: Icon(Icons.place)),
                ],
                selected: {_label},
                onSelectionChanged: (set) => setState(() => _label = set.first),
              ),
              if (_label == AddressLabel.otro) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _labelCustomCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre personalizado',
                    hintText: 'Ej: Casa de playa',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 50,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
              ],
              const SizedBox(height: 16),
              // District dropdown
              districtsAsync.when(
                data: (districts) => DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Distrito',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedDistrictId,
                  items: districts
                      .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedDistrictId = v),
                  validator: (v) => v == null ? 'Selecciona un distrito' : null,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Error cargando distritos'),
              ),
              const SizedBox(height: 16),
              // Address fields
              TextFormField(
                controller: _streetCtrl,
                decoration: const InputDecoration(
                  labelText: 'Calle / Avenida *',
                  border: OutlineInputBorder(),
                ),
                maxLength: 200,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _numberCtrl,
                decoration: const InputDecoration(
                  labelText: 'N° Casa / Edificio *',
                  border: OutlineInputBorder(),
                ),
                maxLength: 50,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _floorAptCtrl,
                decoration: const InputDecoration(
                  labelText: 'Piso / Apartamento',
                  border: OutlineInputBorder(),
                ),
                maxLength: 100,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _referenceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Punto de referencia',
                  hintText: 'Ej: frente al parque, casa azul',
                  border: OutlineInputBorder(),
                ),
                maxLength: 300,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Dirección predeterminada'),
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEditing ? 'Guardar cambios' : 'Guardar dirección'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final repo = ref.read(addressesRepositoryProvider);

      if (widget.existing != null) {
        await repo.updateAddress(
          id: widget.existing!.id,
          label: _label.value,
          labelCustom: _label == AddressLabel.otro ? _labelCustomCtrl.text.trim() : null,
          districtId: _selectedDistrictId,
          addressStreet: _streetCtrl.text.trim(),
          addressNumber: _numberCtrl.text.trim(),
          addressFloorApt: _floorAptCtrl.text.trim().isNotEmpty ? _floorAptCtrl.text.trim() : null,
          addressReference: _referenceCtrl.text.trim().isNotEmpty ? _referenceCtrl.text.trim() : null,
          isDefault: _isDefault,
        );
      } else {
        await repo.createAddress(
          label: _label.value,
          labelCustom: _label == AddressLabel.otro ? _labelCustomCtrl.text.trim() : null,
          districtId: _selectedDistrictId!,
          addressStreet: _streetCtrl.text.trim(),
          addressNumber: _numberCtrl.text.trim(),
          addressFloorApt: _floorAptCtrl.text.trim().isNotEmpty ? _floorAptCtrl.text.trim() : null,
          addressReference: _referenceCtrl.text.trim().isNotEmpty ? _referenceCtrl.text.trim() : null,
          isDefault: _isDefault,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${mapDioErrorToMessage(error)}')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
