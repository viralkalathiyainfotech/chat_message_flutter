class NetworkConstants {
  // static const String apiRoot = 'http://192.168.29.189:5000';
  static const String apiRoot = 'https://chat-message-0fml.onrender.com';
  static const String apiPrefix = '/api';
  static const String baseUrl = '$apiRoot$apiPrefix';
  static const String socketUrl = apiRoot;
  static const String uploadsUrl = '$apiRoot/uploads';

  // Auth endpoints
  static const String mobileOtp = '/mobile-otp';
  static const String verifyMobileOtp = '/verify-mobile-otp';
  static const String verifyOtp = verifyMobileOtp;
  static const String userLogin = '/usrLogin';
  static const String googleLogin = '/google-login';
  static const String forgotPassword = '/forgotPassword';
  static const String verifyEmailOtp = '/verifyOtp';
  static const String changePassword = '/changePassword';
  static const String profileInfo = '/profile-info';
  static const String generateNewTokens = '/generateNewTokens';
  static const String logoutUser = '/logoutUser';
  static const String qrLogin = '/qr-login';
  static String sessionStatus(String sessionId) => '/session/$sessionId';

  // User endpoints
  static const String createUser = '/createUser';
  static const String allUsers = '/allUsers';
  static const String allMessageUsers = '/allMessageUsers';
  static const String allCallUsers = '/allCallUsers';
  static String editUser(String id) => '/editUser/$id';
  static String singleUser(String id) => '/singleUser/$id';
  static const String archiveUser = '/archiveUser';
  static const String blockUser = '/blockUser';
  static const String deleteChat = '/deleteChat';
  static const String pinChat = '/pinChat';
  static const String muteChat = '/muteChat';
  static String updateUserGroupToJoin(String id) =>
      '/updateUserGroupToJoin/$id';
  static String updateUserProfilePhotoPrivacy(String id) =>
      '/updateUserProfilePhotoPrivacy/$id';
  static const String addContactList = '/addContactList';
  static const String allContactUsers = '/allContactUsers';

  // Group endpoints
  static const String createGroup = '/createGroup';
  static String updateGroup(String groupId) => '/updateGroup/$groupId';
  static String deleteGroup(String groupId) => '/deleteGroup/$groupId';
  static const String allGroups = '/allGroups';
  static String getGroupById(String groupId) => '/getGroupById/$groupId';
  static const String leaveGroup = '/leaveGroup';
  static const String addParticipants = '/addParticipants';

  // Message endpoints
  static String messages(String userId) => '/messages/$userId';
  static const String onlineUsers = '/online-users';
  static const String allMessages = '/allMessages';
  static const String messagesSync = '/messages/sync';
  static String messageById(String messageId) => '/messages/message/$messageId';
  static const String deliveredReceipts = '/messages/receipts/delivered';
  static const String readReceipts = '/messages/receipts/read';
  static const String replyFromNotification =
      '/messages/reply-from-notification';
  static String deleteMessage(String messageId) => '/deleteMessage/$messageId';
  static String updateMessage(String messageId) => '/updateMessage/$messageId';
  static const String clearChat = '/clearChat';

  // Upload endpoints
  static const String upload = '/upload';

  // Device endpoints
  static const String devices = '/devices';
  static String device(String deviceId) => '/devices/$deviceId';
  static const String logoutDevice = '/logout-device';
  static const String devicesRegister = '/devices/register';
  static const String devicesUnregister = '/devices/unregister';
  static const String devicesRefreshToken = '/devices/refresh-token';

  // Electron endpoints
  static const String checkElectronInstalled = '/check-electron-installed';
  static String downloadHostControl(String platform) =>
      '/download/host-control-$platform';

  // Call endpoints
  static const String callHistory = '/call-history';
}
