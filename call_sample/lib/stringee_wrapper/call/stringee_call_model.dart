import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

class StringeeCallModel {
  final StringeeCall? call;
  final StringeeCall2? call2;

  StringeeCallModel({this.call, this.call2});

  bool get isCall => call != null;
  bool get isCall2 => call2 != null;
}
