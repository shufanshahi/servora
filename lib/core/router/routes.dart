/// Route paths in one place so screens never hard-code strings.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';

  static const home = '/home';
  static const bookings = '/bookings';
  static const assistant = '/assistant';
  static const profile = '/profile';

  /// A service's detail page, and the start of booking it.
  static String serviceDetail(String id) => '/services/$id';
  static String serviceBook(String id) => '/services/$id/book';

  /// Shown after a successful booking. Needs the new appointment as `extra`.
  static const bookingConfirmation = '/booking-confirmation';

  /// One booking's detail page.
  static String bookingDetail(String id) => '/bookings/$id';

  /// Routes a signed-out user may open.
  static const publicRoutes = {splash, login, register};
}
