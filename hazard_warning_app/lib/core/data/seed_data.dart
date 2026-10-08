import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/services/notification_gateway.dart';

class SeedData {
  static const defaultArea = 'Kelani river - Kolonnawa';

  static DateTime _ago({int hours = 0, int minutes = 0}) =>
      DateTime.now().subtract(Duration(hours: hours, minutes: minutes));

  /// Covers every state the officer UI shows: pending, verified (awaiting a
  /// warning), already warned, and rejected.
  static List<HazardReport> initialReports() => [
    HazardReport(
      id: 'GR-2481',
      category: HazardCategory.risingRiver,
      areaLabel: defaultArea,
      locationLabel: 'Kelani river bank, Kolonnawa',
      coordinates: const GeoCoordinate(latitude: 6.9382, longitude: 79.9012),
      status: ReportStatus.verified,
      submittedAt: _ago(hours: 5),
      verifiedAt: _ago(hours: 4, minutes: 20),
      verifiedBy: 'Duty officer',
      notes: 'Rising water level confirmed by 3 field volunteers.',
    ),
    HazardReport(
      id: 'GR-2488',
      category: HazardCategory.risingRiver,
      areaLabel: 'Kalu river - Ratnapura',
      locationLabel: 'Kalu Ganga bridge, Ratnapura',
      coordinates: const GeoCoordinate(latitude: 6.6828, longitude: 80.3992),
      status: ReportStatus.verified,
      submittedAt: _ago(hours: 3),
      verifiedAt: _ago(hours: 2, minutes: 10),
      verifiedBy: 'Duty officer',
      notes: 'Water within 0.5 m of the bridge deck.',
    ),
    HazardReport(
      id: 'GR-2476',
      category: HazardCategory.blockedRoad,
      areaLabel: 'Kolonnawa - Sedawatta',
      locationLabel: 'Sedawatta Road junction',
      coordinates: const GeoCoordinate(latitude: 6.9310, longitude: 79.8950),
      status: ReportStatus.pending,
      submittedAt: _ago(hours: 1, minutes: 15),
      notes: 'Fallen tree blocking both lanes.',
    ),
    HazardReport(
      id: 'GR-2490',
      category: HazardCategory.landslideCrack,
      areaLabel: 'Kegalle - Aranayake',
      locationLabel: 'Aranayake hillside road, Kegalle',
      coordinates: const GeoCoordinate(latitude: 7.1750, longitude: 80.4290),
      status: ReportStatus.pending,
      submittedAt: _ago(minutes: 35),
      notes: 'New 2 m crack across the slope above houses.',
    ),
    HazardReport(
      id: 'GR-2495',
      category: HazardCategory.coastalSurge,
      areaLabel: 'Negombo - Lewis Place',
      locationLabel: 'Negombo beach front, Lewis Place',
      coordinates: const GeoCoordinate(latitude: 7.2008, longitude: 79.8358),
      status: ReportStatus.verified,
      submittedAt: _ago(hours: 2),
      verifiedAt: _ago(hours: 1),
      verifiedBy: 'Duty officer',
      notes: 'Sea receding abnormally; fishing boats being pulled ashore.',
    ),
    HazardReport(
      id: 'GR-2491',
      category: HazardCategory.damOverflow,
      areaLabel: 'Kalu river - Kukule',
      locationLabel: 'Kukule Ganga reservoir spill gates',
      coordinates: const GeoCoordinate(latitude: 6.6350, longitude: 80.3560),
      status: ReportStatus.verified,
      submittedAt: _ago(hours: 4),
      verifiedAt: _ago(hours: 3, minutes: 30),
      verifiedBy: 'Duty officer',
      notes: 'Two spill gates opened; level at 98% of capacity.',
    ),
    HazardReport(
      id: 'GR-2493',
      category: HazardCategory.strongWinds,
      areaLabel: 'Galle - Unawatuna',
      locationLabel: 'Unawatuna coastal road, Galle',
      coordinates: const GeoCoordinate(latitude: 6.0094, longitude: 80.2497),
      status: ReportStatus.pending,
      submittedAt: _ago(minutes: 50),
      notes: 'Roof sheets and branches being blown onto the road.',
    ),
    HazardReport(
      id: 'GR-2465',
      category: HazardCategory.blockedRoad,
      areaLabel: 'Gampaha - Veyangoda',
      locationLabel: 'Veyangoda railway crossing',
      coordinates: const GeoCoordinate(latitude: 7.1530, longitude: 80.0980),
      status: ReportStatus.verified,
      submittedAt: _ago(hours: 30),
      verifiedAt: _ago(hours: 29),
      verifiedBy: 'Duty officer',
    ),
    HazardReport(
      id: 'GR-2440',
      category: HazardCategory.risingRiver,
      areaLabel: 'Kelani river - Hanwella',
      locationLabel: 'Hanwella town riverside',
      coordinates: const GeoCoordinate(latitude: 6.9020, longitude: 80.0840),
      status: ReportStatus.verified,
      submittedAt: _ago(hours: 52),
      verifiedAt: _ago(hours: 51),
      verifiedBy: 'Duty officer',
    ),
    HazardReport(
      id: 'GR-2459',
      category: HazardCategory.landslideCrack,
      areaLabel: 'Colombo - Kaduwela',
      locationLabel: 'Kaduwela roadside embankment',
      coordinates: const GeoCoordinate(latitude: 6.9330, longitude: 79.9840),
      status: ReportStatus.rejected,
      submittedAt: _ago(hours: 40),
      notes: 'Duplicate of an earlier report; no crack found on inspection.',
    ),
  ];

  /// Warnings already issued, so the citizen alerts list and officer home
  /// have history. GR-2465 and GR-2440 therefore don't appear as awaiting.
  static List<HazardWarning> initialWarnings() {
    const gateway = NotificationGateway();
    final retried = gateway.retryFailed(gateway.dispatch(12480));
    return [
      HazardWarning(
        id: 'HW-1042',
        sourceReportId: 'GR-2465',
        category: HazardCategory.blockedRoad,
        severity: WarningSeverity.moderate,
        scope: BroadcastScope.district,
        targetAreas: const ['Gampaha district'],
        recipientCount: 21300,
        issuedAt: _ago(hours: 28),
        level: WarningLevel.watch,
        deliveries: gateway.dispatch(21300),
      ),
      HazardWarning(
        id: 'HW-1031',
        sourceReportId: 'GR-2440',
        category: HazardCategory.risingRiver,
        severity: WarningSeverity.high,
        scope: BroadcastScope.riverBasin,
        targetAreas: const ['Kelani river basin', 'Attanagalu Oya basin'],
        recipientCount: 16780,
        issuedAt: _ago(hours: 50),
        level: WarningLevel.evacuate,
        escalations: 2,
        deliveries: retried,
      ),
    ];
  }

  static TargetAreaOption _area(
    BroadcastScope scope,
    String id,
    String label,
    int count,
  ) => TargetAreaOption(
    id: id,
    label: label,
    recipientCount: count,
    scope: scope,
  );

  /// Broadcast areas per scope. The first entry of each scope is the form's
  /// default, so keep the Kelani-scenario areas first. Mutwal harbour has no
  /// registered citizens on purpose, to demo the empty-recipient case.
  static List<TargetAreaOption> targetAreas(BroadcastScope scope) {
    const z = BroadcastScope.zone;
    const d = BroadcastScope.district;
    const b = BroadcastScope.riverBasin;
    return switch (scope) {
      BroadcastScope.zone => [
        _area(z, 'zone-kolonnawa', 'Kolonnawa zone', 4200),
        _area(z, 'zone-sedawatta', 'Sedawatta zone', 2650),
        _area(z, 'zone-mutwal', 'Mutwal harbour zone', 0),
        _area(z, 'zone-kaduwela', 'Kaduwela zone', 5100),
        _area(z, 'zone-hanwella', 'Hanwella zone', 3300),
        _area(z, 'zone-biyagama', 'Biyagama zone', 3900),
        _area(z, 'zone-kelaniya', 'Kelaniya zone', 4400),
        _area(z, 'zone-wattala', 'Wattala zone', 4600),
        _area(z, 'zone-ja-ela', 'Ja-Ela zone', 3800),
        _area(z, 'zone-negombo', 'Negombo lagoon zone', 4100),
        _area(z, 'zone-dehiwala', 'Dehiwala zone', 5200),
        _area(z, 'zone-panadura', 'Panadura zone', 3600),
        _area(z, 'zone-horana', 'Horana zone', 2900),
        _area(z, 'zone-ratnapura', 'Ratnapura town zone', 3100),
        _area(z, 'zone-aranayake', 'Aranayake zone', 1800),
        _area(z, 'zone-galle-fort', 'Galle Fort zone', 2400),
        _area(z, 'zone-matara', 'Matara town zone', 2700),
      ],
      BroadcastScope.district => [
        _area(d, 'district-colombo', 'Colombo district', 28400),
        _area(d, 'district-gampaha', 'Gampaha district', 21300),
        _area(d, 'district-kalutara', 'Kalutara district', 17600),
        _area(d, 'district-ratnapura', 'Ratnapura district', 15200),
        _area(d, 'district-kegalle', 'Kegalle district', 11800),
        _area(d, 'district-galle', 'Galle district', 14900),
        _area(d, 'district-matara', 'Matara district', 12700),
        _area(d, 'district-hambantota', 'Hambantota district', 9300),
        _area(d, 'district-kandy', 'Kandy district', 19800),
        _area(d, 'district-matale', 'Matale district', 7800),
        _area(d, 'district-nuwara-eliya', 'Nuwara Eliya district', 8900),
        _area(d, 'district-badulla', 'Badulla district', 10400),
        _area(d, 'district-kurunegala', 'Kurunegala district', 22500),
        _area(d, 'district-puttalam', 'Puttalam district', 8600),
        _area(d, 'district-anuradhapura', 'Anuradhapura district', 13100),
        _area(d, 'district-batticaloa', 'Batticaloa district', 9700),
        _area(d, 'district-trincomalee', 'Trincomalee district', 7200),
      ],
      BroadcastScope.riverBasin => [
        _area(b, 'basin-kelani', 'Kelani river basin', 12480),
        _area(b, 'basin-kalu', 'Kalu river basin', 9100),
        _area(b, 'basin-gin', 'Gin river basin', 5200),
        _area(b, 'basin-nilwala', 'Nilwala river basin', 6100),
        _area(b, 'basin-bentara', 'Bentara river basin', 5600),
        _area(b, 'basin-attanagalu', 'Attanagalu Oya basin', 4300),
        _area(b, 'basin-maha-oya', 'Maha Oya basin', 4900),
        _area(b, 'basin-deduru', 'Deduru Oya basin', 6800),
        _area(b, 'basin-mahaweli', 'Mahaweli river basin', 24800),
        _area(b, 'basin-walawe', 'Walawe river basin', 7400),
        _area(b, 'basin-kirindi', 'Kirindi Oya basin', 3900),
        _area(b, 'basin-malwathu', 'Malwathu Oya basin', 4100),
      ],
    };
  }

  static List<Shelter> initialShelters() => [
    const Shelter(
      id: 'SH-042',
      name: 'Sedawatta M.V.',
      district: 'Colombo district',
      address: 'Sedawatta Road, Kolonnawa',
      capacity: 240,
      occupancy: 260,
      nearestAlternativeId: 'SH-051',
    ),
    const Shelter(
      id: 'SH-051',
      name: 'Kelaniya Community Hall',
      district: 'Colombo district',
      address: 'Kelaniya Road',
      capacity: 300,
      occupancy: 90,
    ),
    const Shelter(
      id: 'SH-033',
      name: 'Kolonnawa Urban Council Hall',
      district: 'Colombo district',
      address: 'Kolonnawa',
      capacity: 180,
      occupancy: 120,
    ),
  ];

  static List<ReliefTeam> initialTeams() => [
    ReliefTeam(
      id: 'RT-12',
      name: 'Kolonnawa response unit',
      lead: 'Officer Nimal',
      members: const [
        'Nimal Perera',
        'Kasun Silva',
        'Dilan Fernando',
        'Chamod Perera',
        'Ruwan Silva',
        'Tharindu Jayasuriya',
        'Amal Fernando',
        'Sahan Perera',
      ],
      responseArea: 'Kelaniya',
      status: 'On site',
      currentLocation: 'Kolonnawa',
      dispatchLocation: 'Sedawatta M.V.',
    ),
    ReliefTeam(
      id: 'RT-18',
      name: 'Kelani basin logistics',
      lead: 'Officer Priya',
      members: const [
        'Priya Fernando',
        'Kamal Perera',
        'Rashmi Silva',
        'Nuwan Fernando',
        'Suresh Kumar',
        'Dinesh Perera',
      ],
      responseArea: 'Kelaniya',
      status: 'En route',
      currentLocation: 'Kelaniya',
      dispatchLocation: 'Kelani M.V.',
    ),
  ];

  static List<ReliefStock> initialRelief() => const [
    ReliefStock(
      district: 'Colombo',
      items: {'Food': 4200, 'Water': 6800, 'Medicine': 920},
    ),
    ReliefStock(
      district: 'Gampaha',
      items: {'Food': 3100, 'Water': 5200, 'Medicine': 640},
    ),
    ReliefStock(
      district: 'Kalutara',
      items: {'Food': 2800, 'Water': 4100, 'Medicine': 580},
    ),
  ];

  static PostEventReport kelaniFloodReport() {
    final days = List.generate(13, (i) => DateTime(2026, 6, 8 + i));
    return PostEventReport(
      id: 'PER-2026-KELANI',
      title: 'Kelani basin floods',
      subtitle: 'Kelani basin floods · 8–20 Jun 2026 · 3 districts',
      districtCount: 3,
      alertCount: 14,
      citizensReached: 128400,
      peakShelterOccupancy: 4120,
      hasIncompleteData: true,
      incompleteRangeLabel: '14–15 Jun',
      alertTimeline: [
        DateTime(2026, 6, 8),
        DateTime(2026, 6, 11),
        DateTime(2026, 6, 13),
        DateTime(2026, 6, 17),
        DateTime(2026, 6, 20),
      ],
      reachByDay: [
        for (var i = 0; i < days.length; i++)
          ReachPoint(
            day: days[i],
            count: 6000 + i * 4200 + (i % 3) * 800,
            partial: i == 6 || i == 7,
          ),
      ],
      shelterSeries: [
        for (var i = 0; i < days.length; i++)
          ShelterPoint(
            day: days[i],
            occupancy: 800 + i * 280 + (i > 5 ? 400 : 0),
            incomplete: i == 6 || i == 7,
          ),
      ],
      resourcesByDistrict: initialRelief(),
    );
  }
}
