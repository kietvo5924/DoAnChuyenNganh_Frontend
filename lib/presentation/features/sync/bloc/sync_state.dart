import 'package:equatable/equatable.dart';

abstract class SyncState extends Equatable {
  const SyncState();
  @override
  List<Object> get props => [];
}

class SyncInitial extends SyncState {}

class SyncInProgress extends SyncState {
  final double progress;
  final String message;
  const SyncInProgress({required this.progress, required this.message});

  @override
  List<Object> get props => [progress, message];
}

class SyncSuccess extends SyncState {}

class SyncFailure extends SyncState {
  final String message;
  const SyncFailure({required this.message});
}
