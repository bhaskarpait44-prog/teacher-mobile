class ApiConstants {
  static String _serverIp = '10.75.163.32'; 
  
  static String get serverIp => _serverIp;
  static String get baseUrl => 'http://$_serverIp:5000/api';
  static String get mediaUrl => 'http://$_serverIp:5000';

  static void setServerIp(String ip) {
    _serverIp = ip;
  }
}
