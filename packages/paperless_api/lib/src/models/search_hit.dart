import 'package:json_annotation/json_annotation.dart';

part 'search_hit.g.dart';

@JsonSerializable()
class SearchHit {
  final double? score;
  final String? highlights;
  final int? rank;

  SearchHit({this.score, required this.highlights, required this.rank});

  factory SearchHit.fromJson(Map<String, dynamic> json) =>
      _$SearchHitFromJson(json);

  Map<String, dynamic> toJson() => _$SearchHitToJson(this);
}
