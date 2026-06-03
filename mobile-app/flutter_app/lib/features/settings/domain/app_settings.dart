import 'package:equatable/equatable.dart';

class AppSettings extends Equatable {
  final String? apiBaseUrl;

  const AppSettings({this.apiBaseUrl});

  AppSettings copyWith({String? apiBaseUrl}) =>
      AppSettings(apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl);

  @override
  List<Object?> get props => [apiBaseUrl];
}
