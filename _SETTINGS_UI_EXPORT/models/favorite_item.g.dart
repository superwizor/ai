// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorite_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FavoriteItem _$FavoriteItemFromJson(Map<String, dynamic> json) => FavoriteItem(
  questionId: (json['questionId'] as num).toInt(),
  dateAdded: DateTime.parse(json['dateAdded'] as String),
  note: json['note'] as String? ?? '',
  dislikeFeedback: json['dislikeFeedback'] as String? ?? '',
  isDislike: json['isDislike'] as bool? ?? false,
);

Map<String, dynamic> _$FavoriteItemToJson(FavoriteItem instance) =>
    <String, dynamic>{
      'questionId': instance.questionId,
      'dateAdded': instance.dateAdded.toIso8601String(),
      'note': instance.note,
      'dislikeFeedback': instance.dislikeFeedback,
      'isDislike': instance.isDislike,
    };
