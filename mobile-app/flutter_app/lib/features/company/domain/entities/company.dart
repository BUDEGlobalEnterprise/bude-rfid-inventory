import 'package:equatable/equatable.dart';

class Company extends Equatable {
  final String name;
  final String companyName;
  final String? defaultCurrency;
  final String? country;

  const Company({
    required this.name,
    required this.companyName,
    this.defaultCurrency,
    this.country,
  });

  @override
  List<Object?> get props => [name, companyName, defaultCurrency, country];
}
