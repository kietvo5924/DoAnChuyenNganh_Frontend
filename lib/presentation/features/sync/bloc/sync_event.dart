import 'package:equatable/equatable.dart';

abstract class SyncEvent extends Equatable {
  const SyncEvent();
  @override
  List<Object> get props => [];
}

class StartInitialSync extends SyncEvent {
  final bool forceUserRemote;
  const StartInitialSync({this.forceUserRemote = false});
  @override
  List<Object> get props => [forceUserRemote];
}
