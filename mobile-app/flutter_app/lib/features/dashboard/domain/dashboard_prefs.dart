import 'dart:convert';

class DashboardPrefs {
  final List<String> cardOrder;
  final Set<String> hiddenCards;
  final Set<String> hiddenActions;
  final Set<String> collapsedCards;

  const DashboardPrefs({
    required this.cardOrder,
    required this.hiddenCards,
    required this.hiddenActions,
    required this.collapsedCards,
  });

  static const List<String> defaultOrder = [
    'ops',
    'assets',
    'quick_actions',
    'recent_activity',
    'system_status',
  ];

  static const DashboardPrefs defaults = DashboardPrefs(
    cardOrder: defaultOrder,
    hiddenCards: {},
    hiddenActions: {},
    collapsedCards: {},
  );

  DashboardPrefs copyWith({
    List<String>? cardOrder,
    Set<String>? hiddenCards,
    Set<String>? hiddenActions,
    Set<String>? collapsedCards,
  }) =>
      DashboardPrefs(
        cardOrder: cardOrder ?? this.cardOrder,
        hiddenCards: hiddenCards ?? this.hiddenCards,
        hiddenActions: hiddenActions ?? this.hiddenActions,
        collapsedCards: collapsedCards ?? this.collapsedCards,
      );

  Map<String, dynamic> toJson() => {
        'cardOrder': cardOrder,
        'hiddenCards': hiddenCards.toList(),
        'hiddenActions': hiddenActions.toList(),
        'collapsedCards': collapsedCards.toList(),
      };

  factory DashboardPrefs.fromJson(Map<String, dynamic> json) {
    final saved = List<String>.from(json['cardOrder'] as List? ?? []);
    // Ensure any newly added default cards appear at the end for existing users.
    final order = [
      ...saved,
      for (final id in defaultOrder)
        if (!saved.contains(id)) id,
    ];
    return DashboardPrefs(
      cardOrder: order,
      hiddenCards: Set<String>.from(json['hiddenCards'] as List? ?? []),
      hiddenActions: Set<String>.from(json['hiddenActions'] as List? ?? []),
      collapsedCards: Set<String>.from(json['collapsedCards'] as List? ?? []),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory DashboardPrefs.fromJsonString(String s) =>
      DashboardPrefs.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
