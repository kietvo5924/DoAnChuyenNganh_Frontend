import 'package:flutter/material.dart';

// toàn cục (GlobalKey) để có thể truy cập vào Navigator của MaterialApp từ bất cứ đâu.
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
}
