sealed class HomeEvent {}

final class HomeRouteSelected extends HomeEvent {
  final String route;
  HomeRouteSelected(this.route);
}

final class HomeProfileSelected extends HomeEvent {}