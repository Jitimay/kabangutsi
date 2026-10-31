import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabangutsi/data/models/models.dart';
import 'package:kabangutsi/data/repositories/repositories.dart';
import 'package:kabangutsi/features/branch_finder/bloc/branch_finder_cubit.dart';
import 'package:mocktail/mocktail.dart';

class MockBranchRepository extends Mock implements BranchRepository {}

Branch branch(String id, String province) => Branch(
  id: id,
  name: 'Agence $province (fictive)',
  province: province,
  town: province,
  address: 'Adresse fictive',
  phone: '+25779000201',
  hours: const {
    'mon': DayHours('08:00', '17:00'),
    'tue': null,
    'wed': null,
    'thu': null,
    'fri': null,
    'sat': null,
    'sun': null,
  },
  hoursText: 'Lundi 08:00–17:00',
  services: const ['cash'],
  isOpenNow: true,
);

void main() {
  final ngozi = branch('br-ngozi', 'Ngozi');
  final gitega = branch('br-gitega', 'Gitega');
  late MockBranchRepository repo;
  setUp(() => repo = MockBranchRepository());

  blocTest<BranchFinderCubit, BranchFinderState>(
    'loads all branches and builds the sorted province list, then filters by province',
    setUp: () {
      when(() => repo.list(province: null, q: '', lang: 'fr')).thenAnswer((_) async => [ngozi, gitega]);
      when(() => repo.list(province: 'Ngozi', q: '', lang: 'fr')).thenAnswer((_) async => [ngozi]);
    },
    build: () => BranchFinderCubit(repo),
    act: (c) async {
      await c.load('fr');
      await c.selectProvince('Ngozi');
    },
    expect: () => [
      const BranchFinderState(),
      BranchFinderState(status: BranchStatus.ready, branches: [ngozi, gitega], provinces: const ['Gitega', 'Ngozi']),
      BranchFinderState(
        status: BranchStatus.ready,
        branches: [ngozi, gitega],
        provinces: const ['Gitega', 'Ngozi'],
        province: 'Ngozi',
      ),
      BranchFinderState(branches: [ngozi, gitega], provinces: const ['Gitega', 'Ngozi'], province: 'Ngozi'),
      BranchFinderState(
        status: BranchStatus.ready,
        branches: [ngozi],
        provinces: const ['Gitega', 'Ngozi'],
        province: 'Ngozi',
      ),
    ],
  );

  blocTest<BranchFinderCubit, BranchFinderState>(
    'search is debounced: only the last query hits the repository',
    setUp: () => when(
      () => repo.list(
        province: null,
        q: any(named: 'q'),
        lang: 'fr',
      ),
    ).thenAnswer((_) async => [gitega]),
    build: () => BranchFinderCubit(repo, debounce: const Duration(milliseconds: 20)),
    act: (c) async {
      c
        ..search('G')
        ..search('Gi')
        ..search('Gitega');
      await Future<void>.delayed(const Duration(milliseconds: 60));
    },
    // G, Gi, Gitega (the loading emit equals the last one, so bloc drops it), then the result.
    skip: 3,
    expect: () => [
      BranchFinderState(status: BranchStatus.ready, branches: [gitega], query: 'Gitega'),
    ],
    verify: (_) {
      verify(() => repo.list(province: null, q: 'Gitega', lang: 'fr')).called(1);
      verifyNever(() => repo.list(province: null, q: 'G', lang: 'fr'));
    },
  );

  blocTest<BranchFinderCubit, BranchFinderState>(
    'error → error state, retry recovers',
    setUp: () {
      var calls = 0;
      when(
        () => repo.list(
          province: any(named: 'province'),
          q: any(named: 'q'),
          lang: any(named: 'lang'),
        ),
      ).thenAnswer((_) async {
        if (calls++ == 0) throw ApiError.network;
        return [ngozi];
      });
    },
    build: () => BranchFinderCubit(repo),
    act: (c) async {
      await c.load('en');
      await c.retry();
    },
    expect: () => [
      const BranchFinderState(),
      const BranchFinderState(status: BranchStatus.error, error: ApiError.network),
      const BranchFinderState(),
      BranchFinderState(status: BranchStatus.ready, branches: [ngozi], provinces: const ['Ngozi']),
    ],
  );
}
