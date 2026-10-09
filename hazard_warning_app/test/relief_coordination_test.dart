
import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/repositories/local_data_repository.dart';

void main() {
  late LocalDataRepository repository;

  setUp(() {
    repository = LocalDataRepository();
  });

  Future<List<Shelter>> getShelters() async {
    return repository.watchShelters().first;
  }

  group('Shelter tests', () {
    const shelter = Shelter(
      id: 'test-shelter',
      name: 'Test Shelter',
      district: 'Colombo',
      address: 'Test Address',
      capacity: 100,
      occupancy: 40,
    );

    test('registers a shelter', () async {
      await repository.registerShelter(shelter);

      final shelters = await getShelters();
      expect(shelters.any((s) => s.id == shelter.id), isTrue);
    });

    test('updates shelter occupancy', () async {
      await repository.registerShelter(shelter);
      await repository.updateShelterOccupancy(shelter.id, 90);

      final shelters = await getShelters();
      final updated = shelters.firstWhere((s) => s.id == shelter.id);

      expect(updated.occupancy, 90);
      expect(updated.fillRatio, 0.9);
    });

    test('detects a shelter over capacity', () {
      const fullShelter = Shelter(
        id: 'full-shelter',
        name: 'Full Shelter',
        district: 'Colombo',
        address: 'Test Address',
        capacity: 100,
        occupancy: 110,
      );

      expect(fullShelter.isOverCapacity, isTrue);
      expect(fullShelter.overflow, 10);
    });

    test('deletes a shelter', () async {
      await repository.registerShelter(shelter);
      await repository.deleteShelter(shelter.id);

      final shelters = await getShelters();
      expect(shelters.any((s) => s.id == shelter.id), isFalse);
    });
  });

  group('Rescue team tests', () {
    const team = ReliefTeam(
      id: 'test-team',
      name: 'Test Rescue Team',
      lead: 'Team Leader',
      members: ['Member One', 'Member Two'],
      responseArea: 'Colombo',
      status: 'Available',
      currentLocation: 'Station',
      dispatchLocation: '',
    );

    test('adds and retrieves a rescue team', () async {
      await repository.addReliefTeam(team);

      final teams = await repository.getReliefTeams();
      expect(teams.any((t) => t.id == team.id), isTrue);
    });

    test('updates team status and dispatch location', () async {
      await repository.addReliefTeam(team);

      const updated = ReliefTeam(
        id: 'test-team',
        name: 'Test Rescue Team',
        lead: 'Team Leader',
        members: ['Member One', 'Member Two'],
        responseArea: 'Colombo',
        status: 'Dispatched',
        currentLocation: 'Station',
        dispatchLocation: 'Flood area',
      );

      await repository.updateReliefTeam(updated);

      final teams = await repository.getReliefTeams();
      final saved = teams.firstWhere((t) => t.id == team.id);

      expect(saved.status, 'Dispatched');
      expect(saved.dispatchLocation, 'Flood area');
    });

    test('does not add a missing team during update', () async {
      await repository.updateReliefTeam(team);

      final teams = await repository.getReliefTeams();
      expect(teams.any((t) => t.id == team.id), isFalse);
    });

    test('deletes a rescue team', () async {
      await repository.addReliefTeam(team);
      await repository.deleteReliefTeam(team.id);

      final teams = await repository.getReliefTeams();
      expect(teams.any((t) => t.id == team.id), isFalse);
    });
  });

  group('Relief stock tests', () {
    const stock = ReliefStock(
      district: 'Test District',
      items: {'Food': 100, 'Water': 200, 'Medicine': 50},
    );

    test('adds and retrieves relief stock', () async {
      await repository.addReliefStock(stock);

      final records = await repository.getReliefStock();
      expect(records.any((r) => r.district == stock.district), isTrue);
    });

    test('updates relief stock quantities', () async {
      await repository.addReliefStock(stock);

      const updated = ReliefStock(
        district: 'Test District',
        items: {'Food': 150, 'Water': 250, 'Medicine': 75},
      );

      await repository.updateReliefStock(updated);

      final records = await repository.getReliefStock();
      final saved = records.firstWhere(
        (r) => r.district == stock.district,
      );

      expect(saved.foodUnits, 150);
      expect(saved.waterUnits, 250);
      expect(saved.medicineUnits, 75);
    });

    test('does not add stock during an update for a missing district',
        () async {
      await repository.updateReliefStock(stock);

      final records = await repository.getReliefStock();
      expect(records.any((r) => r.district == stock.district), isFalse);
    });

    test('deletes relief stock', () async {
      await repository.addReliefStock(stock);
      await repository.deleteReliefStock(stock.district);

      final records = await repository.getReliefStock();
      expect(records.any((r) => r.district == stock.district), isFalse);
    });
  });

  group('Rescue team leader status reminder rules', () {
    bool shouldShowReminder(String status) {
      return ['Dispatched', 'En route', 'On site'].contains(status);
    }

    test('shows reminder for active rescue statuses', () {
      expect(shouldShowReminder('Dispatched'), isTrue);
      expect(shouldShowReminder('En route'), isTrue);
      expect(shouldShowReminder('On site'), isTrue);
    });

    test('hides reminder for inactive or completed statuses', () {
      expect(shouldShowReminder('Available'), isFalse);
      expect(shouldShowReminder('Completed'), isFalse);
    });
  });
}
