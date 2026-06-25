// Schema for one editable master, mirrored from the backend registry
// (`bude_api.api.masters.list_masters`). Drives the generic list + form, so a
// new master added on the backend appears here with no Dart changes.

class MasterField {
  final String name;
  final String label;
  final String type; // text | number | date | check | select | link
  final bool required;
  final List<String> options; // for select
  final String? link; // target doctype for link

  const MasterField({
    required this.name,
    required this.label,
    required this.type,
    required this.required,
    this.options = const [],
    this.link,
  });

  factory MasterField.fromJson(Map<String, dynamic> json) => MasterField(
        name: json['name'] as String,
        label: json['label'] as String,
        type: json['type'] as String,
        required: json['required'] == true,
        options: (json['options'] as List?)
                ?.map((e) => e.toString())
                .toList(growable: false) ??
            const [],
        link: json['link'] as String?,
      );
}

class MasterDef {
  final String key;
  final String label;
  final String doctype;
  final bool canDisable;
  final List<MasterField> fields;

  const MasterDef({
    required this.key,
    required this.label,
    required this.doctype,
    required this.canDisable,
    required this.fields,
  });

  factory MasterDef.fromJson(Map<String, dynamic> json) => MasterDef(
        key: json['key'] as String,
        label: json['label'] as String,
        doctype: json['doctype'] as String,
        canDisable: json['can_disable'] == true,
        fields: (json['fields'] as List)
            .map((e) => MasterField.fromJson((e as Map).cast<String, dynamic>()))
            .toList(growable: false),
      );
}
