import '../../domain/entities/company.dart';

class CompanyModel {
  final String name;
  final String companyName;
  final String? defaultCurrency;
  final String? country;

  const CompanyModel({
    required this.name,
    required this.companyName,
    this.defaultCurrency,
    this.country,
  });

  factory CompanyModel.fromJson(Map<String, dynamic> json) => CompanyModel(
        name: json['name'] as String,
        companyName: json['company_name'] as String,
        defaultCurrency: json['default_currency'] as String?,
        country: json['country'] as String?,
      );

  Company toEntity() => Company(
        name: name,
        companyName: companyName,
        defaultCurrency: defaultCurrency,
        country: country,
      );
}
