import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../models/enums.dart';
import '../models/json_utils.dart';
import '../models/service_request.dart';

class RequestsRepository {
  RequestsRepository(this._api);
  final ApiClient _api;

  Future<Paginated<ServiceRequest>> list({RequestStatus? status, int page = 1}) async {
    final json = await _api.get<Json>('/requests', query: {'status': status?.api, 'page': page, 'limit': 50});
    return Paginated.fromJson(json, ServiceRequest.fromJson);
  }

  Future<ServiceRequest> create({
    required String listingId,
    String? message,
    DateTime? preferredDate,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    final json = await _api.post<Json>(
      '/requests',
      body: {
        'listingId': listingId,
        if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
        if (preferredDate != null) 'preferredDate': preferredDate.toUtc().toIso8601String(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (address != null && address.isNotEmpty) 'address': address,
      },
    );
    return ServiceRequest.fromJson(json);
  }

  Future<ServiceRequest> accept(String id, {String? note}) =>
      _patch(id, 'accept', {if (note != null && note.trim().isNotEmpty) 'note': note.trim()});

  Future<ServiceRequest> reject(String id, String reason) => _patch(id, 'reject', {'reason': reason.trim()});

  Future<ServiceRequest> complete(String id, {String? note}) =>
      _patch(id, 'complete', {if (note != null && note.trim().isNotEmpty) 'note': note.trim()});

  Future<ServiceRequest> cancel(String id, {String? note}) =>
      _patch(id, 'cancel', {if (note != null && note.trim().isNotEmpty) 'note': note.trim()});

  Future<ProviderStats> stats() async => ProviderStats.fromJson(await _api.get<Json>('/requests/stats'));

  Future<ServiceRequest> _patch(String id, String action, Json body) async =>
      ServiceRequest.fromJson(await _api.patch<Json>('/requests/$id/$action', body: body));
}

final requestsRepositoryProvider = Provider<RequestsRepository>(
  (ref) => RequestsRepository(ref.watch(apiClientProvider)),
);
