sealed class HomeState {}

final class HomeInitial extends HomeState {}

final class HomeNavigationRequested extends HomeState {
  final String route;
  HomeNavigationRequested(this.route);
}