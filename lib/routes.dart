// lib/routes.dart
import 'package:flutter/material.dart';

// General Screens
// import 'screens/role_screen.dart';
import 'screens/login_screen.dart' as auth_login;
import 'screens/register_screen.dart' as auth_register;
// import 'screens/email_verification_screen.dart';
import 'screens/login_otp_screen.dart';
// import 'screens/loginwithphone_screen.dart';
import 'screens/home_screen.dart';
import 'screens/blood_request_screen.dart';
import 'screens/find_nearby_donors_screen.dart';
import 'screens/notifications.dart';
import 'screens/forget_password.dart';
import 'screens/incoming_blood_requests_screen.dart';

// 🩺 PATIENT Screens
// import 'screens/Patient/patient_login_screen.dart';
// import 'screens/Patient/patient_home_screen.dart';
// import 'screens/Patient/patient_register_screen.dart';
// import 'screens/Patient/Patient_phonelogin_screen.dart';
// import 'screens/Patient/Patient_otp_screen.dart';
// import 'screens/forget_password.dart';
import 'screens/Patient/patient_edit_profile.dart';
import 'screens/Patient/Patient_Profile_Screen.dart';
import 'screens/Patient/Patient_Notification_Screen.dart';
import 'screens/Patient/Patient_View_Donate_Screen.dart';
// import 'screens/Patient/patient_verify_email_screen.dart';

// 🩸 DONOR Screens
import 'screens/splash_screen.dart';
// import 'screens/Donor/Donor_login_screen.dart';
import 'screens/Donor/donor_home_screen.dart';
// import 'screens/Donor/Donor_Register_Screen.dart';
import 'screens/Donor/Donor_phonelogin_screen.dart';
import 'screens/Donor/Donor_otp_screen.dart';
import 'screens/Donor/Donor_Forget_Password.dart';
import 'screens/Donor/Donor_Edit_profile.dart';
import 'screens/Donor/Donor_Profile_Screen.dart';
import 'screens/Donor/donor_notification_screen.dart';
import 'screens/Donor/Donor_Donation_Request_Screen.dart';
// import 'screens/Donor/donor_verify_email_screen.dart';

// 🤝 VOLUNTEER screens
import 'screens/Volunteer/Volunteer_Dashboard.dart';
// import 'screens/Volunteer/Blood_Request_Management_Screen.dart';
import 'screens/Volunteer/volunteer_evet_screen.dart';
// import 'screens/Volunteer/Certificate_Generation_Screen.dart';
import 'screens/Volunteer/Volunteer_Profile_Screen.dart';
import 'screens/Volunteer/Help_Support_Page.dart';
// import 'screens/Volunteer/Volunteer_Register.dart';
// import 'screens/Volunteer/Volunteer_Login_Screen.dart';
import 'screens/Volunteer/contact_admin.dart';
import 'screens/Volunteer/Volunteer_Notification_Screen.dart';
// import 'screens/Volunteer/volunteer_verify_email_screen.dart';
import 'screens/Volunteer/Volunteer_phonelogin_screen.dart';
import 'screens/Volunteer/Volunteer_otp_screen.dart';

class AppRoutes {
  // General Routes
  static const String roleSelection = '/role-selection';
  static const String volunteerRegister = '/volunteer_register';
  static const String volunteerDashboard = '/volunteer_dashboard';
  static const String bloodRequestManagement = '/blood-request-management';
  static const String contactAdmin = '/contact-admin';
  static const String login = '/login';
  static const String loginOtp = '/login-otp';
  static const String register = '/register';
  static const String home = '/home';
  static const String bloodRequest = '/blood-request';
  static const String findNearbyDonors = '/find-nearby-donors';
  static const String notifications = '/notifications';
  static const String Forgetpassword = '/forget-password';
  static const String incomingBloodRequests = '/incoming-blood-requests';

  // static const String volunteerHome = '/volunteer_dashboard';
  // static const String emailVerification = '/email-verification';

  // Donor Routes
  static const String donorData = '/donor-data';
  // static const String certificateGeneration = '/certificate-generation';
  static const String volunteerProfile = '/volunteer-profile';
  static const String volunteerSettings = '/volunteer-settings';
  static const String helpSupport = '/help-support';
  static const String volunteerContactAdmin = '/volunteer-contact-admin';
  static const String volunteerNotifications = '/volunteer-notifications';
  static const String volunteerEvents = '/volunteer-events';
  static const String volunteerBloodRequestManagement =
      '/blood-request-management';
  static const String volunteerCertificateGeneration =
      '/certificate-generation';
  // static const String volunteerLogin = '/volunteer-login';
  static const String volunteerVerifyEmail = '/volunteer-verify-email';
  static const String volunteerEvetScreen = '/volunteer-events';
  static const String volunteerPhoneLogin = '/volunteer-phone-login';
  static const String volunteerOtp = '/volunteer-otp';

  // 🏥 Patient Routes
  // static const String patientLogin = '/patient-login';
  // static const String patientHome = '/patient-home';
  // static const String patientRegister = '/patient-register';
  // static const String patientPhoneLogin = '/patient-phone-login';
  // static const String patientOtp = '/patient-otp';
  static const String patientForgetPassword = '/patient-forget-password';
  static const String patientEditProfile = '/patient-edit-profile';
  static const String patientProfile = '/patient-profile';
  static const String patientNotifications = '/patient-notifications';
  static const String patientViewDonate = '/patient-view-donate';
  // static const String patientBloodRequest = '/patient-blood-request';
  static const String patientVerifyEmail = '/patient-verify-email';

  // 🎒 Donor Specific Named Routes
  static const String splash = '/splash';
  // static const String donorLogin = '/donor-login';
  static const String donorHome = '/donor-home';
  // static const String donorRegister = '/donor-register';
  static const String donorPhoneLogin = '/donor-phone-login';
  static const String donorOtp = '/donor-otp';
  static const String donorForgetPassword = '/donor-forget-password';
  static const String donorEditProfile = '/donor-edit-profile';
  static const String donorProfile = '/donor-profile';
  static const String donorNotifications = '/donor-notifications';
  static const String donorDonationRequests = '/donor-donation-requests';
  static const String donorVerifyEmail = '/donor-verify-email';

  // 🗺️ ROUTE SWITCH ENGINE
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      // case roleSelection:
      //   return MaterialPageRoute(builder: (_) => const RoleSelectionScreen());

      case login:
        return MaterialPageRoute(builder: (_) => const auth_login.login());

      case register:
        return MaterialPageRoute(
          builder: (_) => const auth_register.register(),
        );

      // case emailVerification:
      //   return MaterialPageRoute(
      //     builder: (_) => const EmailVerificationScreen(),
      //   );

      case AppRoutes.loginOtp:
        final args = settings.arguments as Map<String, dynamic>;

        return MaterialPageRoute(
          builder: (_) => LoginOtpScreen(
            uid: args['uid'] as String,
            phoneNumber: args['phoneNumber'] as String,
            verificationId: args['verificationId'] as String,
            resendToken: args['resendToken'] as int?,
          ),
        );


      case notifications:
        return MaterialPageRoute(
          builder: (_) => const DonorNotificationScreen(),
        );  
      // ==================== GENERAL HOME ====================

      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());

      case bloodRequest:
        return MaterialPageRoute(builder: (_) => const BloodRequestScreen());

      case findNearbyDonors:
        return MaterialPageRoute(builder: (_) => const FindNearbyDonorsScreen());

      case incomingBloodRequests:
        return MaterialPageRoute( 
          builder: (_) => const IncomingBloodRequestsScreen(),
        );  
          
      // ==================== PATIENT OLD ROUTES COMMENTED ====================
      // case patientLogin:
      //   return MaterialPageRoute(builder: (_) => const PatientLoginScreen());

      // case patientHome:
      //   return MaterialPageRoute(builder: (_) => const PatientHomeScreen());

      // case patientRegister:
      //   return MaterialPageRoute(builder: (_) => const PatientRegisterScreen());

      // case patientPhoneLogin:
      //   final String role = settings.arguments as String? ?? 'Patient';
      //   return MaterialPageRoute(builder: (_) => PhoneLoginPage(role: role));

      // case patientOtp:
      //   final args = settings.arguments;

      //   String phoneNumber = '';
      //   String verificationId = '';
      //   int? resendToken;

      //   if (args is Map) {
      //     phoneNumber =
      //         args['phoneNumber']?.toString() ??
      //         args['phone_number']?.toString() ??
      //         '';

      //     verificationId =
      //         args['verificationId']?.toString() ??
      //         args['verification_id']?.toString() ??
      //         '';

      //     final dynamic rawResendToken =
      //         args['resendToken'] ?? args['resend_token'];

      //     if (rawResendToken is int) {
      //       resendToken = rawResendToken;
      //     } else if (rawResendToken != null) {
      //       resendToken = int.tryParse(rawResendToken.toString());
      //     }
      //   } else if (args is String) {
      //     phoneNumber = args;
      //   }

      //   return MaterialPageRoute(
      //     builder: (_) => OtpScreen(
      //       phoneNumber: phoneNumber,
      //       verificationId: verificationId,
      //       resendToken: resendToken,
      //     ),
      //   );

      case patientForgetPassword:
        return MaterialPageRoute(
          builder: (_) => const ForgetPasswordScreen(),
        );

      case patientEditProfile:
        return MaterialPageRoute(
          builder: (_) => const PatientEditProfileScreen(),
        );

      case patientProfile:
        return MaterialPageRoute(
          builder: (_) => const PatientProfileTabContent(),
        );

      case patientNotifications:
        return MaterialPageRoute(
          builder: (_) => const PatientNotificationsScreen(),
        );

      case patientViewDonate:
        return MaterialPageRoute(builder: (_) => const ViewDonorsScreen());

      // ==================== DONOR ====================

      // case donorLogin:
      //   return MaterialPageRoute(
      //     builder: (_) => const DonorLoginScreen(role: 'donor'),
      //   );

      case donorHome:
        return MaterialPageRoute(builder: (_) => const DonorHomeScreen());

      // case donorRegister:
      //   return MaterialPageRoute(builder: (_) => const DonorRegisterScreen());

      // case AppRoutes.donorVerifyEmail:
      //   return MaterialPageRoute(
      //     builder: (_) => const DonorVerifyEmailScreen(),
      //   );

      case donorPhoneLogin:
        final String role = settings.arguments as String? ?? 'Donor';
        return MaterialPageRoute(
          builder: (_) => DonorPhoneLoginPage(role: role),
        );

      case donorOtp:
        final args = settings.arguments;

        String phoneNumber = '';
        String verificationId = '';
        int? resendToken;

        if (args is Map) {
          phoneNumber =
              args['phoneNumber']?.toString() ??
              args['phone_number']?.toString() ??
              '';

          verificationId =
              args['verificationId']?.toString() ??
              args['verification_id']?.toString() ??
              '';

          final dynamic rawResendToken =
              args['resendToken'] ?? args['resend_token'];

          if (rawResendToken is int) {
            resendToken = rawResendToken;
          } else if (rawResendToken != null) {
            resendToken = int.tryParse(rawResendToken.toString());
          }
        } else if (args is String) {
          phoneNumber = args;
        }

        return MaterialPageRoute(
          builder: (_) => DonorOtpScreen(
            phoneNumber: phoneNumber,
            verificationId: verificationId,
            resendToken: resendToken,
          ),
        );

      case donorForgetPassword:
        return MaterialPageRoute(
          builder: (_) => const DonorForgetPasswordScreen(),
        );

      case donorEditProfile:
        return MaterialPageRoute(
          builder: (_) => const DonorEditProfileScreen(),
        );

      case donorProfile:
        return MaterialPageRoute(
          builder: (_) => const DonorProfileTabContent(),
        );

      case donorNotifications:
        return MaterialPageRoute(
          builder: (_) => const DonorNotificationScreen(),
        );

      case donorDonationRequests:
        return MaterialPageRoute(
          builder: (_) => const DonorDonationRequestScreen(),
        );

      // ==================== VOLUNTEER VIEW REDIRECTS ====================

      case volunteerPhoneLogin:
        final String role = settings.arguments as String? ?? 'Volunteer';

        return MaterialPageRoute(
          builder: (_) => VolunteerPhoneLoginPage(role: role),
        );

      case volunteerOtp:
        final args = settings.arguments;

        String phoneNumber = '';
        String verificationId = '';
        int? resendToken;

        if (args is Map) {
          phoneNumber =
              args['phoneNumber']?.toString() ??
              args['phone_number']?.toString() ??
              '';

          verificationId =
              args['verificationId']?.toString() ??
              args['verification_id']?.toString() ??
              '';

          final dynamic rawResendToken =
              args['resendToken'] ?? args['resend_token'];

          if (rawResendToken is int) {
            resendToken = rawResendToken;
          } else if (rawResendToken != null) {
            resendToken = int.tryParse(rawResendToken.toString());
          }
        } else if (args is String) {
          phoneNumber = args;
        }

        return MaterialPageRoute(
          builder: (_) => VolunteerOtpScreen(
            phoneNumber: phoneNumber,
            verificationId: verificationId,
            resendToken: resendToken,
          ),
        );

      // case volunteerLogin:
      //   return MaterialPageRoute(builder: (_) => const VolunteerLoginScreen());

      case volunteerDashboard:
        return MaterialPageRoute(
          builder: (_) => const VolunteerDashboardScreen(),
        );

      // case volunteerRegister:
      //   return MaterialPageRoute(
      //     builder: (_) => const VolunteerRegisterScreen(),
      //   );

      // case bloodRequestManagement:
      //   return MaterialPageRoute(
      //     builder: (_) => const BloodRequestManagementScreen(),
      //   );

      case donorData:
        return MaterialPageRoute(builder: (_) => const ContactAdmin());

      // case certificateGeneration:
      //   return MaterialPageRoute(
      //     builder: (_) => const CertificateGenerationScreen(),
      //   );

      case volunteerProfile:
        return MaterialPageRoute(
          builder: (_) => const VolunteerProfileScreen(),
        );

      case volunteerNotifications:
        return MaterialPageRoute(
          builder: (_) => const VolunteerNotificationScreen(),
        );

      case volunteerEvents:
        return MaterialPageRoute(builder: (_) => const VolunteerEvetScreen());

      case contactAdmin:
        return MaterialPageRoute(builder: (_) => const ContactAdmin());

      case volunteerSettings:
      case helpSupport:
        return MaterialPageRoute(builder: (_) => const HelpSupportScreen());

      default:
        return MaterialPageRoute(builder: (_) => const UnknownScreen());
    }
  }

  // 🧭 QUICK NAVIGATION HELPER ACTION HOOKS
  // static void goToPatientRegister(BuildContext context) =>
  //     Navigator.pushNamed(context, patientRegister);
  // static void goToDonorRegister(BuildContext context) =>
  //     Navigator.pushNamed(context, donorRegister);

  // static void goToPatientPhoneLogin(BuildContext context, String role) =>
  //     Navigator.pushNamed(context, patientPhoneLogin, arguments: role);

  static void goToDonorPhoneLogin(BuildContext context, String role) =>
      Navigator.pushNamed(context, donorPhoneLogin, arguments: role);

  // static void goToPatientOtp(BuildContext context, String phoneNumber) =>
  //     Navigator.pushNamed(context, patientOtp, arguments: phoneNumber);

  static void goToDonorOtp(BuildContext context, String phoneNumber) =>
      Navigator.pushNamed(context, donorOtp, arguments: phoneNumber);

  static void replaceWithHome(BuildContext context) =>
      Navigator.pushReplacementNamed(context, home);

  static void replaceWithPatientHome(BuildContext context) =>
      Navigator.pushReplacementNamed(context, home);

  static void replaceWithDonorHome(BuildContext context) =>
      Navigator.pushReplacementNamed(context, donorHome);

  static void replaceWithVolunteerDashboard(BuildContext context) =>
      Navigator.pushReplacementNamed(context, volunteerDashboard);
}

// Global Custom Fallback Route Catch
class UnknownScreen extends StatelessWidget {
  const UnknownScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Page Not Found')));
  }
}