import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'splash/splash_screen.dart';
import 'onboarding/onboarding_screen.dart';
import 'login/login_screen.dart';
import 'signup/signup_screen.dart';
import 'home/home_screen.dart';
import 'medications/medications_screen.dart';
import 'appointments/appointments_screen.dart';
import 'appointments/appointment_form_screen.dart';
import 'reminders/reminders_screen.dart';
import 'reminders/add_reminder_screen.dart';
import 'health_information/health_information_screen.dart';
import 'health_information/edit_health_information_screen.dart';
import 'health_facilities/health_facilities_screen.dart';
import 'health_facilities/facility_map_screen.dart';
import 'emergency/emergency_screen.dart';
import 'emergency/share_location_screen.dart';
import 'messages/messages_screen.dart';
import 'calendar/calendar_screen.dart';
import 'password/reset_password_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',

  routes: [
    // ============================================================
    // SPLASH
    // ============================================================
    GoRoute(
      path: '/splash',
      builder: (context, state) => SplashScreen(),
    ),

    // ============================================================
    // ONBOARDING
    // ============================================================
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => OnboardingScreen(),
    ),

    // ============================================================
    // LOGIN
    // ============================================================
    GoRoute(
      path: '/login',
      builder: (context, state) => LoginScreen(),
    ),

    // ============================================================
    // RESET PASSWORD
    // ============================================================
    GoRoute(
      path: '/reset-password',
      builder: (context, state) => const ResetPasswordScreen(),
    ),

    // ============================================================
    // SIGN UP
    // ============================================================
    GoRoute(
      path: '/signup',
      builder: (context, state) => SignupScreen(),
    ),

    // ============================================================
    // HOME
    // ============================================================
    GoRoute(
      path: '/home',
      builder: (context, state) => HomeScreen(),
    ),

    // ============================================================
    // MEDICATIONS
    // ============================================================
    GoRoute(
      path: '/medications',
      builder: (context, state) => MedicationsScreen(),
    ),

    // ============================================================
    // ADD MEDICATION
    // ============================================================
    GoRoute(
      path: '/medications/add',
      builder: (context, state) => AddMedicationScreen(),
    ),

    // ============================================================
    // MESSAGES
    // ============================================================
    GoRoute(
      path: '/messages',
      builder: (context, state) => const MessagesScreen(),
    ),

    // ============================================================
    // CALENDAR
    // ============================================================
    GoRoute(
      path: '/calendar',
      builder: (context, state) => const CalendarScreen(),
    ),

    // ============================================================
    // HEALTH FACILITIES
    // ============================================================
    GoRoute(
      path: '/health-facilities',
      builder: (context, state) => const HealthFacilitiesScreen(),
    ),

    // ============================================================
    // HEALTH FACILITIES MAP
    // ============================================================
    GoRoute(
      path: '/health-facilities-map',
      builder: (context, state) => const FacilityMapScreen(),
    ),

    // ============================================================
    // EMERGENCY
    // ============================================================
    GoRoute(
      path: '/emergency',
      builder: (context, state) => const EmergencyScreen(),
    ),

    // ============================================================
    // SHARE LOCATION
    // ============================================================
    GoRoute(
      path: '/share-location',
      builder: (context, state) => const ShareLocationScreen(),
    ),

    // ============================================================
    // REMINDERS
    // ============================================================
    GoRoute(
      path: '/reminders',
      builder: (context, state) {
        return const RemindersScreen();
      },
    ),

    // ============================================================
    // ADD / EDIT REMINDER
    // ============================================================
    GoRoute(
      path: '/reminders/add',
      builder: (context, state) {
        final reminder = state.extra;

        return AddReminderScreen(
          reminder: reminder is Reminder ? reminder : null,
        );
      },
    ),

    // ============================================================
    // APPOINTMENTS
    // ============================================================
    GoRoute(
      path: '/appointments',
      builder: (context, state) => AppointmentsScreen(),
    ),

    // ============================================================
    // ADD APPOINTMENT
    // ============================================================
    GoRoute(
      path: '/appointments/add',
      builder: (context, state) => const AppointmentFormScreen(),
    ),

    // ============================================================
    // EDIT APPOINTMENT
    // ============================================================
    GoRoute(
      path: '/appointments/edit',
      builder: (context, state) {
        final appointment = state.extra as Appointment;

        return AppointmentFormScreen(
          appointment: appointment,
        );
      },
    ),

    // ============================================================
    // HEALTH INFORMATION
    // ============================================================
    GoRoute(
      path: '/health-information',
      builder: (context, state) {
        return const HealthInformationScreen();
      },
    ),

    // ============================================================
    // EDIT HEALTH INFORMATION
    // ============================================================
    GoRoute(
      path: '/edit-health-information',
      builder: (context, state) {
        final healthInformation =
        state.extra as HealthInformation;

        return EditHealthInformationScreen(
          healthInformation: healthInformation,
        );
      },
    ),

    // ============================================================
    // APPOINTMENT DETAILS
    // ============================================================
    GoRoute(
      path: '/appointment-details',
      builder: (context, state) {
        final appointment = state.extra as Appointment;

        return AppointmentDetailsScreen(
          appointment: appointment,
        );
      },
    ),
  ],
);

class MedNovaApp extends StatefulWidget {
  const MedNovaApp({super.key});

  @override
  State<MedNovaApp> createState() => _MedNovaAppState();
}

class _MedNovaAppState extends State<MedNovaApp> {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();

    _listenForAuthChanges();
  }

  void _listenForAuthChanges() {
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen(
              (AuthState data) {
            // ========================================================
            // PASSWORD RECOVERY
            // ========================================================

            if (data.event == AuthChangeEvent.passwordRecovery) {
              appRouter.go('/reset-password');
              return;
            }

            // ========================================================
            // EMAIL CONFIRMATION / SIGN IN
            // ========================================================

            if (data.event == AuthChangeEvent.signedIn) {
              final session =
                  Supabase.instance.client.auth.currentSession;

              if (session != null) {
                appRouter.go('/home');
              }
            }
          },
        );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'MedNova',
      routerConfig: appRouter,

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C3CE9),
        ),
        scaffoldBackgroundColor: const Color(0xFFF9F7FC),
      ),
    );
  }
}