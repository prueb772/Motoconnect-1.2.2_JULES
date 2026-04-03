import 'package:flutter_bloc/flutter_bloc.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc() : super(HomeInitial()) {
    on<HomeRouteSelected>((event, emit) {
      emit(HomeNavigationRequested(event.route));
      // Optionally reset to initial state if needed
      emit(HomeInitial());
    });

    on<HomeProfileSelected>((event, emit) {
      emit(HomeNavigationRequested('/perfil'));
      emit(HomeInitial());
    });
  }
}