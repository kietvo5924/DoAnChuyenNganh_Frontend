import 'package:equatable/equatable.dart';

abstract class SyncEvent extends Equatable {
  const SyncEvent();
  @override
  List<Object> get props => [];
}

class StartInitialSync extends SyncEvent {
  final bool forceUserRemote;
  final bool mergeGuest; // NEW
  const StartInitialSync({
    this.forceUserRemote = false,
    this.mergeGuest = false,
  });
  @override
  List<Object> get props => [forceUserRemote, mergeGuest];
}
