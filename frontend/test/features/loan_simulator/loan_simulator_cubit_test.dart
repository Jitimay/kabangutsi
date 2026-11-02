import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabangutsi/data/models/models.dart';
import 'package:kabangutsi/data/repositories/repositories.dart';
import 'package:kabangutsi/features/loan_simulator/bloc/loan_simulator_cubit.dart';
import 'package:mocktail/mocktail.dart';

class MockLoanRepository extends Mock implements LoanRepository {}

void main() {
  const business = LoanProduct(
    id: 'business_loan',
    name: 'Crédit commerce',
    description: 'Stock',
    annualRatePct: 16,
    minAmount: 500000,
    maxAmount: 50000000,
    minTermMonths: 3,
    maxTermMonths: 36,
    requirements: ['Registre de commerce'],
  );
  const agri = LoanProduct(
    id: 'agri_loan',
    name: 'Crédit agricole',
    description: 'Récolte',
    annualRatePct: 12,
    minAmount: 100000,
    maxAmount: 10000000,
    minTermMonths: 3,
    maxTermMonths: 24,
    requirements: [],
  );
  const sim = LoanSimulation(
    productId: 'business_loan',
    productName: 'Crédit commerce',
    amount: 5000000,
    termMonths: 24,
    annualRatePct: 16,
    monthlyPayment: 244816,
    totalPayment: 5875584,
    totalInterest: 875584,
    explanation: 'Pour 5 000 000 FBu…',
    lang: 'fr',
  );
  late MockLoanRepository repo;
  setUp(() => repo = MockLoanRepository());

  blocTest<LoanSimulatorCubit, LoanSimulatorState>(
    'loads products, selects the first, simulates with values from the API',
    setUp: () {
      when(() => repo.products('fr')).thenAnswer((_) async => [business, agri]);
      when(
        () => repo.simulate(
          productId: 'business_loan',
          amount: 5000000,
          termMonths: 24,
          lang: 'fr',
          conversationId: null,
        ),
      ).thenAnswer((_) async => sim);
    },
    build: () => LoanSimulatorCubit(repo),
    act: (c) async {
      await c.load('fr');
      await c.simulate(amount: 5000000, termMonths: 24, lang: 'fr');
    },
    expect: () => [
      const LoanSimulatorState(),
      const LoanSimulatorState(status: LoanStatus.ready, products: [business, agri], selected: business),
      const LoanSimulatorState(
        status: LoanStatus.ready,
        products: [business, agri],
        selected: business,
        simulating: true,
      ),
      const LoanSimulatorState(
        status: LoanStatus.ready,
        products: [business, agri],
        selected: business,
        simulation: sim,
      ),
    ],
  );

  blocTest<LoanSimulatorCubit, LoanSimulatorState>(
    'select another product clears the previous simulation',
    seed: () => const LoanSimulatorState(
      status: LoanStatus.ready,
      products: [business, agri],
      selected: business,
      simulation: sim,
    ),
    build: () => LoanSimulatorCubit(repo),
    act: (c) => c.select(agri),
    expect: () => [
      const LoanSimulatorState(status: LoanStatus.ready, products: [business, agri], selected: agri),
    ],
  );

  const outOfRange = ApiError(
    code: 'out_of_range',
    message: 'Le montant maximum pour ce crédit est 50 000 000 FBu.',
    details: {'field': 'amount'},
    status: 422,
  );
  blocTest<LoanSimulatorCubit, LoanSimulatorState>(
    'out_of_range keeps the backend message',
    seed: () => const LoanSimulatorState(status: LoanStatus.ready, products: [business], selected: business),
    setUp: () => when(
      () => repo.simulate(
        productId: any(named: 'productId'),
        amount: any(named: 'amount'),
        termMonths: any(named: 'termMonths'),
        lang: any(named: 'lang'),
        conversationId: any(named: 'conversationId'),
      ),
    ).thenThrow(outOfRange),
    build: () => LoanSimulatorCubit(repo),
    act: (c) => c.simulate(amount: 90000000, termMonths: 12, lang: 'fr'),
    expect: () => [
      const LoanSimulatorState(status: LoanStatus.ready, products: [business], selected: business, simulating: true),
      const LoanSimulatorState(status: LoanStatus.ready, products: [business], selected: business, error: outOfRange),
    ],
  );

  blocTest<LoanSimulatorCubit, LoanSimulatorState>(
    'product load failure → loadError',
    setUp: () => when(() => repo.products(any())).thenThrow(ApiError.network),
    build: () => LoanSimulatorCubit(repo),
    act: (c) => c.load('rn'),
    expect: () => [
      const LoanSimulatorState(),
      const LoanSimulatorState(status: LoanStatus.loadError, error: ApiError.network),
    ],
  );
}
