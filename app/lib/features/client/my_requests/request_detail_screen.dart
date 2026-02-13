import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/service_request_model.dart';
import '../state/client_requests_providers.dart';

class RequestDetailScreen extends ConsumerStatefulWidget {
  const RequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  ServiceRequestModel? _request;
  String? _error;
  bool _loading = true;
  Timer? _countdownTimer;
  Timer? _pollingTimer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadRequest();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle Solicitud')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      );
    }

    final request = _request;
    if (request == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle Solicitud')),
        body: const Center(child: Text('Solicitud no encontrada')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Solicitud'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _row('Estado', request.status.value),
          _row('Distrito', request.district?.name ?? request.districtId),
          _row('Precio', request.priceTotal.toStringAsFixed(2)),
          _row('Direccion', request.addressDetail),
          _row('Fecha (local)', request.scheduledAt.toLocal().toString()),
          if (request.status == ServiceRequestStatus.pending)
            _row('Tiempo restante', _formatRemaining(_remaining)),
          if (request.status == ServiceRequestStatus.accepted && request.provider != null) ...[
            const SizedBox(height: 12),
            const Text(
              'Proveedor asignado',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            _row('Nombre', request.provider!.fullName),
            _row('Telefono', request.provider!.phone),
          ],
          if (request.status == ServiceRequestStatus.expired)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Nadie acepto tu solicitud. Intenta de nuevo.',
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _loadRequest() async {
    try {
      final repo = ref.read(clientRequestsRepositoryProvider);
      final request = await repo.getRequestById(widget.requestId);
      if (!mounted) {
        return;
      }
      setState(() {
        _request = request;
        _loading = false;
        _error = null;
      });
      _setupTimersForStatus(request);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = mapDioErrorToMessage(error);
        _loading = false;
      });
    }
  }

  void _setupTimersForStatus(ServiceRequestModel request) {
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();

    if (request.status != ServiceRequestStatus.pending) {
      _remaining = Duration.zero;
      return;
    }

    _updateRemaining(request.expiresAt);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining(request.expiresAt);
    });

    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final repo = ref.read(clientRequestsRepositoryProvider);
      try {
        final fresh = await repo.getRequestById(widget.requestId);
        if (!mounted) {
          return;
        }
        setState(() {
          _request = fresh;
        });
        if (fresh.status != ServiceRequestStatus.pending) {
          _countdownTimer?.cancel();
          _pollingTimer?.cancel();
        }
      } catch (_) {
        // Silent retry on next polling tick.
      }
    });
  }

  void _updateRemaining(DateTime expiresAt) {
    final diff = expiresAt.difference(DateTime.now().toUtc());
    if (!mounted) {
      return;
    }
    setState(() {
      _remaining = diff.isNegative ? Duration.zero : diff;
    });
  }

  String _formatRemaining(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
