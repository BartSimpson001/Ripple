part of 'home_bloc.dart';

abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {}

class UserLoading extends HomeState {}

class UserLoaded extends HomeState {
  final String name;
  final String email;
  final String uid;





  const UserLoaded({required this.name, required this.email, required this.uid});

  @override
  List<Object?> get props => [name, email, uid];
}

class UserError extends HomeState {
  final String message;

  const UserError(this.message);

  @override
  List<Object?> get props => [message];
}