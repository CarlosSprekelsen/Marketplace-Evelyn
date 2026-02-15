import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/service_request_model.dart';
import '../../../shared/models/user.dart';
import '../../../shared/utils/date_formatter.dart';
import '../../auth/state/auth_notifier.dart';
import '../state/admin_providers.dart';

class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  bool _loading = true;
  bool _updating = false;
  String? _error;
  int _selectedTab = 0;
  UserRole? _roleFilter;
  List<User> _users = const [];
  List<ServiceRequestModel> _requests = const [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final authNotifier = ref.read(authNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Admin'),
        actions: [
          IconButton(
            onPressed: () => authNotifier.logout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesion',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 0, label: Text('Solicitudes')),
                          ButtonSegment(value: 1, label: Text('Usuarios')),
                        ],
                        selected: {_selectedTab},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _selectedTab = selection.first;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadData,
                        child: _selectedTab == 0 ? _buildRequestsList() : _buildUsersList(),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildRequestsList() {
    if (_requests.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: Text('No hay solicitudes para mostrar')),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: _requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final request = _requests[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.district?.name ?? request.districtId,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text('ID: ${request.id}'),
                Text('Cliente: ${request.clientId}'),
                Text('Proveedor: ${request.providerId ?? '-'}'),
                Text('Fecha: ${formatDateTime(request.scheduledAt)}'),
                Text('Precio: \$${request.priceTotal.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                DropdownButtonFormField<ServiceRequestStatus>(
                  initialValue: request.status,
                  decoration: const InputDecoration(
                    labelText: 'Estado',
                    border: OutlineInputBorder(),
                  ),
                  items: ServiceRequestStatus.values
                      .map(
                        (status) => DropdownMenuItem<ServiceRequestStatus>(
                          value: status,
                          child: Text(status.value),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _updating
                      ? null
                      : (value) {
                          if (value == null || value == request.status) {
                            return;
                          }
                          _updateRequestStatus(request, value);
                        },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUsersList() {
    final filteredUsers = _roleFilter == null
        ? _users
        : _users.where((user) => user.role == _roleFilter).toList(growable: false);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Todos'),
              selected: _roleFilter == null,
              onSelected: (_) => setState(() => _roleFilter = null),
            ),
            ChoiceChip(
              label: const Text('Clientes'),
              selected: _roleFilter == UserRole.client,
              onSelected: (_) => setState(() => _roleFilter = UserRole.client),
            ),
            ChoiceChip(
              label: const Text('Proveedores'),
              selected: _roleFilter == UserRole.provider,
              onSelected: (_) => setState(() => _roleFilter = UserRole.provider),
            ),
            ChoiceChip(
              label: const Text('Admins'),
              selected: _roleFilter == UserRole.admin,
              onSelected: (_) => setState(() => _roleFilter = UserRole.admin),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (filteredUsers.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: Text('No hay usuarios para mostrar')),
          )
        else
          ...filteredUsers.map(_buildUserCard),
      ],
    );
  }

  Widget _buildUserCard(User user) {
    final isProvider = user.role == UserRole.provider;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(user.email),
            Text('Rol: ${user.role.value}'),
            Text('Distrito: ${user.district?.name ?? user.districtId}'),
            Text('Telefono: ${user.phone}'),
            Text('Creado: ${formatDateTime(user.createdAt)}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isProvider)
                  OutlinedButton(
                    onPressed: _updating
                        ? null
                        : () => _toggleVerified(user, isVerified: !user.isVerified),
                    child: Text(user.isVerified ? 'Quitar verificación' : 'Verificar'),
                  ),
                OutlinedButton(
                  onPressed: _updating ? null : () => _toggleBlocked(user, isBlocked: !user.isBlocked),
                  child: Text(user.isBlocked ? 'Desbloquear' : 'Bloquear'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final repo = ref.read(adminRepositoryProvider);
      final results = await Future.wait([
        repo.getUsers(),
        repo.getServiceRequests(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _users = results[0] as List<User>;
        _requests = results[1] as List<ServiceRequestModel>;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'No se pudo cargar panel admin: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleVerified(User user, {required bool isVerified}) async {
    setState(() => _updating = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      final updated = await repo.setUserVerified(user.id, isVerified);
      _replaceUser(updated);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estado de verificación actualizado')),
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _updating = false);
      }
    }
  }

  Future<void> _toggleBlocked(User user, {required bool isBlocked}) async {
    setState(() => _updating = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      final updated = await repo.setUserBlocked(user.id, isBlocked);
      _replaceUser(updated);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estado de bloqueo actualizado')),
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _updating = false);
      }
    }
  }

  Future<void> _updateRequestStatus(
    ServiceRequestModel request,
    ServiceRequestStatus status,
  ) async {
    setState(() => _updating = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      final updated = await repo.setServiceRequestStatus(request.id, status);
      _replaceRequest(updated);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estado de solicitud actualizado')),
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _updating = false);
      }
    }
  }

  void _replaceUser(User user) {
    setState(() {
      _users = _users
          .map((existing) => existing.id == user.id ? user : existing)
          .toList(growable: false);
    });
  }

  void _replaceRequest(ServiceRequestModel request) {
    setState(() {
      _requests = _requests
          .map((existing) => existing.id == request.id ? request : existing)
          .toList(growable: false);
    });
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Operacion fallida: $error')),
    );
  }
}
