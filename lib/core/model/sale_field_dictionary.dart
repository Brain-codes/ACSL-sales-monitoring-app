/// The sale field dictionary, as served by `GET /functions/v1/sale-dictionary`.
///
/// The paper User Agreement is the standard. The web app, the Data Center and
/// this app all read ONE dictionary of the sale record: the agreement's wording
/// for every field, the payload key that carries it, its options, and the day it
/// becomes mandatory.
///
/// The rule that makes this modular: **read the dictionary at run time, do not
/// copy it**. Labels, options and mandatory dates change without an app release.
/// Three things follow, and they are the whole contract:
///
///  1. Labels come from [SaleField.label]. No field name is typed into the app.
///  2. Required follows [SaleField.mandatoryFrom]. A field is required when its
///     date is on or before *the sale's own date*, so an old draft is never
///     refused for a rule that came later.
///  3. Choices come from [SaleField.options]. Show `label`, send `value`.
///
/// Manual fromJson/toJson, no codegen, per the project conventions.
library;

/// One selectable choice. Show [label], send [value].
///
/// The values are slugs, not the words on screen: `firewood`, `collect`,
/// `semi_indoor`. Sending the label instead of the value is the mistake this
/// class exists to prevent.
class SaleFieldOption {
  final String value;
  final String label;

  const SaleFieldOption({required this.value, required this.label});

  factory SaleFieldOption.fromJson(Map<String, dynamic> json) =>
      SaleFieldOption(
        value: json['value']?.toString() ?? '',
        label: json['label']?.toString() ?? json['value']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {'value': value, 'label': label};
}

/// A named section of the form ("The buyer", "Cooking", "CPA (Terms and
/// Conditions)"). Headings come from here, not from string literals.
class SaleFieldGroup {
  final String key;
  final String label;

  const SaleFieldGroup({required this.key, required this.label});

  factory SaleFieldGroup.fromJson(Map<String, dynamic> json) => SaleFieldGroup(
        key: json['key']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {'key': key, 'label': label};
}

/// One field of the sale record.
class SaleField {
  /// Stable identifier, e.g. `end_user_surname`. Never shown to a user.
  final String key;

  /// The agreement's wording. This is what the form renders.
  final String label;

  /// The key to send in the create-sale / update-sale payload.
  ///
  /// Null for a derived field the app does not send (serial number, the
  /// agreement photo, the first-instalment amount). `full_address` and `city`
  /// both carry `addressData`, because both live inside that nested object.
  final String? payload;

  /// `date`, `text`, `phone`, `select`, `boolean`, `money`, `number`,
  /// `consents`, `signature`, `image`.
  final String type;

  /// The group key this field belongs to.
  final String group;

  /// Display order within the whole form.
  final int order;

  /// The day this field becomes mandatory, or null if it never is.
  ///
  /// The server seeds this from JSON but the live answer comes from
  /// `public.sale_field_rules`, so an administrator can move a date without a
  /// release. Never hardcode a date against this — call [isRequiredOn].
  final DateTime? mandatoryFrom;

  /// Whether the Data Center may correct this field after the fact.
  final bool correctable;

  /// Whether the field appears on the printed agreement.
  final bool onAgreement;

  /// Choices for a `select`. Empty for every other type.
  final List<SaleFieldOption> options;

  /// For `consents` (the CPA block): the six consent keys, each sent true.
  final List<String> consents;

  const SaleField({
    required this.key,
    required this.label,
    required this.payload,
    required this.type,
    required this.group,
    required this.order,
    required this.mandatoryFrom,
    this.correctable = true,
    this.onAgreement = false,
    this.options = const [],
    this.consents = const [],
  });

  factory SaleField.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload']?.toString().trim();
    final rawMandatory = json['mandatoryFrom']?.toString().trim();
    return SaleField(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      payload: (rawPayload == null || rawPayload.isEmpty) ? null : rawPayload,
      type: json['type']?.toString() ?? 'text',
      group: json['group']?.toString() ?? '',
      order: json['order'] is int
          ? json['order'] as int
          : int.tryParse(json['order']?.toString() ?? '') ?? 0,
      // tryParse, never parse: one malformed date must not take down the form.
      mandatoryFrom: (rawMandatory == null || rawMandatory.isEmpty)
          ? null
          : DateTime.tryParse(rawMandatory),
      correctable: json['correctable'] == true,
      onAgreement: json['onAgreement'] == true,
      options: (json['options'] as List?)
              ?.whereType<Map>()
              .map((o) => SaleFieldOption.fromJson(o.cast<String, dynamic>()))
              .toList() ??
          const [],
      consents: (json['consents'] as List?)
              ?.map((c) => c.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        if (payload != null) 'payload': payload,
        'type': type,
        'group': group,
        'order': order,
        'mandatoryFrom': mandatoryFrom?.toIso8601String().substring(0, 10),
        'correctable': correctable,
        'onAgreement': onAgreement,
        if (options.isNotEmpty)
          'options': options.map((o) => o.toJson()).toList(),
        if (consents.isNotEmpty) 'consents': consents,
      };

  /// Whether this field is required for a sale dated [saleDate].
  ///
  /// A record is judged by the rules of its own day: a draft from before the
  /// rule came in is never refused for it. [saleDate] is compared by calendar
  /// day, so the handset's clock time cannot flip the answer.
  bool isRequiredOn(DateTime saleDate) {
    final from = mandatoryFrom;
    if (from == null) return false;
    final day = DateTime(saleDate.year, saleDate.month, saleDate.day);
    final start = DateTime(from.year, from.month, from.day);
    return !day.isBefore(start);
  }

  /// The label to show for a stored [value] of a `select`.
  ///
  /// A record holding a retired value keeps it: when the value is no longer on
  /// the list, the raw value is shown rather than blanked.
  String labelForValue(String? value) {
    if (value == null || value.isEmpty) return '';
    for (final o in options) {
      if (o.value == value) return o.label;
    }
    return value;
  }

  /// True when [value] is not on the current option list but is not empty —
  /// i.e. a retired choice held by an existing record.
  bool isRetiredValue(String? value) {
    if (value == null || value.isEmpty) return false;
    if (options.isEmpty) return false;
    return !options.any((o) => o.value == value);
  }
}

/// The whole dictionary: `{ version, source, groups, fields }`.
class SaleFieldDictionary {
  final String version;
  final String source;
  final List<SaleFieldGroup> groups;
  final List<SaleField> fields;

  /// The ETag the server served this body with, kept so the next fetch can
  /// revalidate cheaply with `If-None-Match`. Null for the bundled fallback.
  final String? etag;

  /// When this copy was fetched. Null for the bundled fallback.
  final DateTime? fetchedAt;

  const SaleFieldDictionary({
    required this.version,
    required this.source,
    required this.groups,
    required this.fields,
    this.etag,
    this.fetchedAt,
  });

  factory SaleFieldDictionary.fromJson(
    Map<String, dynamic> json, {
    String? etag,
    DateTime? fetchedAt,
  }) {
    return SaleFieldDictionary(
      version: json['version']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      groups: (json['groups'] as List?)
              ?.whereType<Map>()
              .map((g) => SaleFieldGroup.fromJson(g.cast<String, dynamic>()))
              .toList() ??
          const [],
      fields: (json['fields'] as List?)
              ?.whereType<Map>()
              .map((f) => SaleField.fromJson(f.cast<String, dynamic>()))
              .toList() ??
          const [],
      etag: etag ?? json['__etag']?.toString(),
      fetchedAt: fetchedAt ??
          DateTime.tryParse(json['__fetchedAt']?.toString() ?? ''),
    );
  }

  /// Serialised for the offline cache. The ETag and fetch time ride along under
  /// underscored keys so one stored blob restores the whole revalidation state.
  Map<String, dynamic> toJson() => {
        'version': version,
        'source': source,
        'groups': groups.map((g) => g.toJson()).toList(),
        'fields': fields.map((f) => f.toJson()).toList(),
        if (etag != null) '__etag': etag,
        if (fetchedAt != null) '__fetchedAt': fetchedAt!.toIso8601String(),
      };

  SaleFieldDictionary copyWith({String? etag, DateTime? fetchedAt}) =>
      SaleFieldDictionary(
        version: version,
        source: source,
        groups: groups,
        fields: fields,
        etag: etag ?? this.etag,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );

  /// Look up by dictionary key (`end_user_surname`). Null when absent, so a
  /// field added to the server but not yet known here simply does not render.
  SaleField? byKey(String key) {
    for (final f in fields) {
      if (f.key == key) return f;
    }
    return null;
  }

  /// Look up by payload key (`endUserSurname`).
  ///
  /// `addressData` is carried by two fields, so this returns the first; use
  /// [byKey] when the distinction between full address and city matters.
  SaleField? byPayload(String payload) {
    for (final f in fields) {
      if (f.payload == payload) return f;
    }
    return null;
  }

  /// The label for [key], falling back to [fallback] when the field is unknown.
  ///
  /// Every sale-form label goes through here, so no field name is typed into a
  /// widget. The fallback only shows if the server dropped a field entirely.
  String labelFor(String key, {String fallback = ''}) =>
      byKey(key)?.label ?? fallback;

  /// Whether [key] is required for a sale dated [saleDate].
  ///
  /// An unknown key is never required — a field this app does not know about
  /// cannot block a sale from being saved.
  bool isRequired(String key, DateTime saleDate) =>
      byKey(key)?.isRequiredOn(saleDate) ?? false;

  /// The options for [key], empty when the field is unknown or not a select.
  List<SaleFieldOption> optionsFor(String key) => byKey(key)?.options ?? const [];

  /// Fields of one group, in display order.
  List<SaleField> fieldsInGroup(String groupKey) {
    final list = fields.where((f) => f.group == groupKey).toList();
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  /// Every dictionary key that is mandatory for a sale dated [saleDate] and
  /// that the app actually sends. Used by the self-check in the create form.
  List<String> requiredKeysOn(DateTime saleDate) => fields
      .where((f) => f.payload != null && f.isRequiredOn(saleDate))
      .map((f) => f.key)
      .toList();
}
