import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

enum BranchStatus { loading, ready, error }

/// F8 state.
class BranchFinderState extends Equatable {
  const BranchFinderState({
    this.status = BranchStatus.loading,
    this.branches = const [],
    this.provinces = const [],
    this.province,
    this.query = '',
    this.error,
  });

  final BranchStatus status;
  final List<Branch> branches;

  /// Built from the unfiltered list (first load).
  final List<String> provinces;
  final String? province;
  final String query;
  final ApiError? error;

  BranchFinderState copyWith({
    BranchStatus? status,
    List<Branch>? branches,
    List<String>? provinces,
    String? Function()? province,
    String? query,
    ApiError? Function()? error,
  }) => BranchFinderState(
    status: status ?? this.status,
    branches: branches ?? this.branches,
    provinces: provinces ?? this.provinces,
    province: province != null ? province() : this.province,
    query: query ?? this.query,
    error: error != null ? error() : this.error,
  );

  @override
  List<Object?> get props => [status, branches, provinces, province, query, error];
}

class BranchFinderCubit extends Cubit<BranchFinderState> {
  BranchFinderCubit(this._repo, {this.debounce = const Duration(milliseconds: 350)}) : super(const BranchFinderState());

  final BranchRepository _repo;
  final Duration debounce;
  Timer? _timer;
  String _lang = 'fr';
  int _request = 0;

  Future<void> load(String lang) async {
    _lang = lang;
    await _fetch(updateProvinces: state.provinces.isEmpty);
  }

  Future<void> selectProvince(String? province) async {
    emit(state.copyWith(province: () => province));
    await _fetch();
  }

  /// Debounced free-text search.
  void search(String query) {
    emit(state.copyWith(query: query));
    _timer?.cancel();
    _timer = Timer(debounce, _fetch);
  }

  Future<void> retry() => _fetch(updateProvinces: state.provinces.isEmpty);

  Future<void> _fetch({bool updateProvinces = false}) async {
    final id = ++_request;
    emit(state.copyWith(status: BranchStatus.loading, error: () => null));
    try {
      final items = await _repo.list(province: state.province, q: state.query.trim(), lang: _lang);
      if (id != _request || isClosed) return; // a newer request superseded this one
      emit(
        state.copyWith(
          status: BranchStatus.ready,
          branches: items,
          provinces: updateProvinces ? (items.map((b) => b.province).toSet().toList()..sort()) : null,
        ),
      );
    } on ApiError catch (e) {
      if (id != _request || isClosed) return;
      emit(state.copyWith(status: BranchStatus.error, error: () => e));
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
