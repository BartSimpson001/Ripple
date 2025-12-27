import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../Repository/user_repository.dart';
part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final UserRepository userRepository;

  HomeBloc({required this.userRepository}) : super(HomeInitial()) {
    on<FetchUserData>(_onFetchUserData);
  }
  Future<void> _onFetchUserData(FetchUserData event, Emitter<HomeState> emit) async {
    emit(UserLoading());
    try {
      final user = await userRepository.getCurrentUser();
      if (user != null) {
        final profile = await userRepository.getUserProfile(user.uid);
        if (profile != null) {
          emit(UserLoaded(
            name: profile.fullName,
            email: profile.email,
            uid: profile.uid,
          ));
        } else {
          emit(UserError("User profile not found"));
        }
      } else {
        emit(UserError("No user signed in"));
      }
    } catch (e) {
      emit(UserError("Error: ${e.toString()}"));
    }
  }
}