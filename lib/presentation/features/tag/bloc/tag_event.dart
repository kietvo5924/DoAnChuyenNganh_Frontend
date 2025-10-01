import 'package:equatable/equatable.dart';
import '../../../../domain/tag/entities/tag_entity.dart';

abstract class TagEvent extends Equatable {
  const TagEvent();
  @override
  List<Object?> get props => [];
}

class FetchTags extends TagEvent {
  final bool forceRemote;
  const FetchTags({this.forceRemote = false});
  @override
  List<Object?> get props => [forceRemote];
}

class SaveTagSubmitted extends TagEvent {
  final TagEntity tag;
  const SaveTagSubmitted({required this.tag});
}

class DeleteTagSubmitted extends TagEvent {
  final int tagId;
  const DeleteTagSubmitted({required this.tagId});
}
