import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

enum LoanStatus { loading, ready, loadError }

/// F6 state. Amounts come from the API; the UI never recomputes them.
class LoanSimulatorState extends Equatable {
  const LoanSimulatorState({
    this.status = LoanStatus.loading,
    this.products = const [],
    this.selected,
    this.simulating = false,
    this.simulation,
    this.error,
  });

  final LoanStatus status;
  final List<LoanProduct> products;
  final LoanProduct? selected;
  final bool simulating;
  final LoanSimulation? simulation;

  /// Last simulation error (e.g. `out_of_range` with a localized message).
  final ApiError? error;

  LoanSimulatorState copyWith({
    LoanStatus? status,
    List<LoanProduct>? products,
    LoanProduct? Function()? selected,
    bool? simulating,
    LoanSimulation? Function()? simulation,
    ApiError? Function()? error,
  }) => LoanSimulatorState(
    status: status ?? this.status,
    products: products ?? this.products,
    selected: selected != null ? selected() : this.selected,
    simulating: simulating ?? this.simulating,
    simulation: simulation != null ? simulation() : this.simulation,
    error: error != null ? error() : this.error,
  );

  @override
  List<Object?> get props => [status, products, selected, simulating, simulation, error];
}

class LoanSimulatorCubit extends Cubit<LoanSimulatorState> {
  LoanSimulatorCubit(this._repo, {this.conversationId}) : super(const LoanSimulatorState());

  final LoanRepository _repo;
  final String? conversationId;

  /// Loads the products in [lang] (names and requirements are localized by the backend).
  Future<void> load(String lang) async {
    emit(state.copyWith(status: LoanStatus.loading, error: () => null));
    try {
      final products = await _repo.products(lang);
      final keep = state.selected == null ? null : products.where((p) => p.id == state.selected!.id).firstOrNull;
      emit(
        state.copyWith(
          status: LoanStatus.ready,
          products: products,
          selected: () => keep ?? (products.isEmpty ? null : products.first),
          simulation: () => null,
        ),
      );
    } on ApiError catch (e) {
      emit(state.copyWith(status: LoanStatus.loadError, error: () => e));
    }
  }

  void select(LoanProduct product) =>
      emit(state.copyWith(selected: () => product, simulation: () => null, error: () => null));

  Future<void> simulate({required int amount, required int termMonths, required String lang}) async {
    final product = state.selected;
    if (product == null || state.simulating) return;
    emit(state.copyWith(simulating: true, error: () => null));
    try {
      final sim = await _repo.simulate(
        productId: product.id,
        amount: amount,
        termMonths: termMonths,
        lang: lang,
        conversationId: conversationId,
      );
      emit(state.copyWith(simulating: false, simulation: () => sim));
    } on ApiError catch (e) {
      emit(state.copyWith(simulating: false, simulation: () => null, error: () => e));
    }
  }
}
