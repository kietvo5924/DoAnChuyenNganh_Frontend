class ApiConfig {
  // Thay đổi IP tùy theo môi trường của bạn
  // 10.0.2.2 cho Android Emulator
  // localhost cho iOS simulator / web
  // IP thật của máy tính (ví dụ: 192.168.1.10) cho thiết bị vật lý
  static const String baseUrl = 'http://192.168.1.6:8080/api';

  // Endpoints cho Authentication
  static const String signInEndpoint = '/auth/signin';
  static const String signUpEndpoint = '/auth/signup';

  // Các endpoints khác có thể thêm ở đây...
  // static const String tasksEndpoint = '/tasks';
}
