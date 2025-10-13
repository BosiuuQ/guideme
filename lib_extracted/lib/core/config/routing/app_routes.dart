class AppRoutes {
  // Auth
  static const String loginView = '/loginView';
  static const String registerView = '/registerView';
  static const String emailConfirmationView = '/email-confirmation';
  static const String regulationsView = '/regulations';
  static const String resetPasswordView = '/reset-password';

  // Main
  static const String mainView = '/mainView';

  // Profile
  static const String profileView = '/profileView';

  // Garage
  static const String garageView = '/garageView';
  static const String vehicleDetailsView = '/vehicleDetailsView';
  static const String addNewVehicleView = '/garage/add-new-vehicle'; // <- zmieniono

  // Panel
  static const String panelView = '/panel-view';

  // Viewpoints
  static const String viewpointView = 'viewpointView';
  static const String viewpointDetailsView = '/viewpointDetailsView';
  static const String viewpointAddView = '/viewpointAddView';

  // Friends
  static const String znajomiView = '/znajomiView';
  static const String chatView = '/chatView';
  static const String premiumChat = '/premium-chat';
  static const String searchUser = '/searchUser';
  static const String userProfile = '/profile/:userId';

  // Ranking
  static const String rankingView = '/rankingView';

  // Settings
  static const String settingsView = '/settingsView';

  // Shop
  static const String shopHomeView = '/shopHomeView';

  // Posts
  static const String postDetailsView = '/postDetailsView';
  static const String postAddView = '/postAddView';
  static const String instagramPosty = '/instagramPosty';

  // Achievements
  static const String achievementsDetailsView = '/achievementsDetailsView';

  // Image viewer
  static const String imageView = '/imageView';

  // Clubs
  static const String clubsHome = '/clubsHome';
  static const String clubsList = '/clubs/list';
  static const String createClub = '/clubs/create';
  static const String myClub = '/clubs/my';
}
