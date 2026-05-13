import 'package:json_annotation/json_annotation.dart';

part 'favorite_item.g.dart';

@JsonSerializable()
class FavoriteItem {
  final int questionId;
  final DateTime dateAdded;
  final String note;
  final String dislikeFeedback;
  final bool isDislike;

  FavoriteItem({
    required this.questionId,
    required this.dateAdded,
    this.note = '',
    this.dislikeFeedback = '',
    this.isDislike = false,
  });

  FavoriteItem copyWith({
    int? questionId,
    DateTime? dateAdded,
    String? note,
    String? dislikeFeedback,
    bool? isDislike,
  }) {
    return FavoriteItem(
      questionId: questionId ?? this.questionId,
      dateAdded: dateAdded ?? this.dateAdded,
      note: note ?? this.note,
      dislikeFeedback: dislikeFeedback ?? this.dislikeFeedback,
      isDislike: isDislike ?? this.isDislike,
    );
  }

  factory FavoriteItem.fromJson(Map<String, dynamic> json) =>
      _$FavoriteItemFromJson(json);

  Map<String, dynamic> toJson() => _$FavoriteItemToJson(this);
}
