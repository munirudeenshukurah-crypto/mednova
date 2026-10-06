
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mednova/services/offline_database.dart';

class LoginScreen extends StatefulWidget {
const LoginScreen({super.key});

@override
State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
final emailController = TextEditingController();
final passwordController = TextEditingController();

bool obscurePassword = true;
bool isLoading = false;
bool isGoogleLoading = false;

final SupabaseClient supabase = Supabase.instance.client;

final OfflineDatabase offlineDatabase =
OfflineDatabase.instance;

@override
void dispose() {
emailController.dispose();
passwordController.dispose();
super.dispose();
}

// ============================================================
// LOGIN
// ============================================================

Future<void> login() async {
final email = emailController.text.trim();
final password = passwordController.text.trim();

if (email.isEmpty || password.isEmpty) {
_showMessage(
'Please enter your email and password.',
);
return;
}

setState(() {
isLoading = true;
});

try {
// ========================================================
// FIRST: TRY ONLINE LOGIN
// ========================================================

try {
final response =
await supabase.auth.signInWithPassword(
email: email,
password: password,
);

final user = response.user;

if (user == null) {
throw const AuthException(
'Unable to complete login.',
);
}

// ------------------------------------------------------
// SAVE LOGIN INFORMATION FOR FUTURE OFFLINE LOGIN
// ------------------------------------------------------

await offlineDatabase.saveOfflineAuth(
userId: user.id,
email: email,
password: password,
);

// ------------------------------------------------------
// SAVE USER PROFILE LOCALLY IF AVAILABLE
// ------------------------------------------------------

try {
final profileResponse = await supabase
    .from('profiles')
    .select()
    .eq('id', user.id)
    .maybeSingle();

if (profileResponse != null) {
await offlineDatabase.saveProfile(
profileResponse,
);
}
} catch (_) {
// Profile caching should not prevent login.
}

if (!mounted) return;

context.go('/home');
return;
} on AuthException {
// ------------------------------------------------------
// SUPABASE AUTH ERROR
// ------------------------------------------------------

final offlineAuth =
await offlineDatabase.getOfflineAuth(email);

if (offlineAuth == null) {
rethrow;
}

final validOfflineLogin =
await offlineDatabase.verifyOfflineLogin(
email: email,
password: password,
);

if (!validOfflineLogin) {
rethrow;
}

await offlineDatabase.updateOfflineLoginTime(
email,
);

if (!mounted) return;

_showMessage(
'You are offline. Using your saved MedNova account.',
);

await Future.delayed(
const Duration(milliseconds: 500),
);

if (!mounted) return;

context.go('/home');
return;
} catch (_) {
// ======================================================
// INTERNET / NETWORK ERROR
// ======================================================

final offlineAuth =
await offlineDatabase.getOfflineAuth(email);

if (offlineAuth == null) {
if (!mounted) return;

_showMessage(
'No internet connection. Please connect to the internet for your first login.',
);

return;
}

// ======================================================
// OFFLINE LOGIN
// ======================================================

final validOfflineLogin =
await offlineDatabase.verifyOfflineLogin(
email: email,
password: password,
);

if (!validOfflineLogin) {
if (!mounted) return;

_showMessage(
'Incorrect email or password.',
);

return;
}

await offlineDatabase.updateOfflineLoginTime(
email,
);

if (!mounted) return;

_showMessage(
'You are offline. Using your saved MedNova account.',
);

await Future.delayed(
const Duration(milliseconds: 500),
);

if (!mounted) return;

context.go('/home');
}
} on AuthException catch (error) {
if (!mounted) return;

_showMessage(
error.message,
);
} catch (error) {
if (!mounted) return;

_showMessage(
'Unable to log in. Please check your internet connection and try again.',
);
} finally {
if (mounted) {
setState(() {
isLoading = false;
});
}
}
}

// ============================================================
// GOOGLE LOGIN
// ============================================================

Future<void> continueWithGoogle() async {
if (isGoogleLoading || isLoading) return;

setState(() {
isGoogleLoading = true;
});

try {
final success =
await supabase.auth.signInWithOAuth(
OAuthProvider.google,
redirectTo: 'mednova://google-callback',
);

if (!success) {
if (!mounted) return;

_showMessage(
'Unable to start Google sign-in. Please try again.',
);
}
} on AuthException catch (error) {
if (!mounted) return;

_showMessage(
error.message,
);
} catch (error) {
if (!mounted) return;

_showMessage(
'Unable to sign in with Google. Please try again.',
);
} finally {
if (mounted) {
setState(() {
isGoogleLoading = false;
});
}
}
}

// ============================================================
// FORGOT PASSWORD
// ============================================================

Future<void> forgotPassword() async {
final email = emailController.text.trim();

if (email.isEmpty) {
_showMessage(
'Please enter your email address first.',
);
return;
}

try {
await supabase.auth.resetPasswordForEmail(
email,
redirectTo: 'mednova://reset-password',
);

if (!mounted) return;

_showMessage(
'Password reset link sent. Please check your email.',
);
} on AuthException catch (error) {
if (!mounted) return;

_showMessage(
error.message,
);
} catch (error) {
if (!mounted) return;

_showMessage(
'Unable to send password reset email. Please try again.',
);
}
}

// ============================================================
// MESSAGE
// ============================================================

void _showMessage(String message) {
ScaffoldMessenger.of(context)
    .hideCurrentSnackBar();

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(message),
behavior: SnackBarBehavior.floating,
),
);
}

// ============================================================
// UI
// ============================================================

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: Colors.white,
body: SafeArea(
child: SingleChildScrollView(
padding: const EdgeInsets.all(25),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
const SizedBox(height: 35),

const Text(
'Welcome Back!',
style: TextStyle(
fontSize: 30,
fontWeight: FontWeight.bold,
),
),

const SizedBox(height: 10),

const Text(
'Sign in to continue your healthcare journey.',
style: TextStyle(
color: Colors.grey,
fontSize: 15,
fontWeight: FontWeight.bold,
),
),

const SizedBox(height: 40),

const Text(
'Email Address',
style: TextStyle(
fontWeight: FontWeight.w600,
),
),

const SizedBox(height: 8),

TextField(
controller: emailController,
keyboardType:
TextInputType.emailAddress,
decoration: InputDecoration(
hintText: 'Enter your email',
prefixIcon: const Icon(
Icons.email_outlined,
),
border: OutlineInputBorder(
borderRadius:
BorderRadius.circular(15),
),
),
),

const SizedBox(height: 20),

const Text(
'Password',
style: TextStyle(
fontWeight: FontWeight.w600,
),
),

const SizedBox(height: 8),

TextField(
controller: passwordController,
obscureText: obscurePassword,
decoration: InputDecoration(
hintText: 'Enter your password',
prefixIcon: const Icon(
Icons.lock_outline,
),
suffixIcon: IconButton(
onPressed: () {
setState(() {
obscurePassword =
!obscurePassword;
});
},
icon: Icon(
obscurePassword
? Icons.visibility_off
    : Icons.visibility,
),
),
border: OutlineInputBorder(
borderRadius:
BorderRadius.circular(15),
),
),
),

Align(
alignment: Alignment.centerRight,
child: TextButton(
onPressed:
isLoading || isGoogleLoading
? null
    : forgotPassword,
child: const Text(
'Forgot Password?',
style: TextStyle(
color: Color(0xFF6C3CE9),
),
),
),
),

const SizedBox(height: 15),

SizedBox(
width: double.infinity,
height: 55,
child: ElevatedButton(
onPressed:
isLoading || isGoogleLoading
? null
    : login,
style:
ElevatedButton.styleFrom(
backgroundColor:
const Color(0xFF6C3CE9),
foregroundColor: Colors.white,
disabledBackgroundColor:
const Color(0xFF6C3CE9)
    .withValues(alpha: 0.6),
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(15),
),
),
child: isLoading
? const SizedBox(
height: 24,
width: 24,
child:
CircularProgressIndicator(
strokeWidth: 2.5,
color: Colors.white,
),
)
    : const Text(
'Login',
style: TextStyle(
fontSize: 16,
fontWeight:
FontWeight.bold,
),
),
),
),

const SizedBox(height: 25),

Row(
children: [
Expanded(
child: Divider(
color:
Colors.grey.shade300,
),
),
const Padding(
padding:
EdgeInsets.symmetric(
horizontal: 15,
),
child: Text(
'OR',
style: TextStyle(
color: Colors.grey,
),
),
),
Expanded(
child: Divider(
color:
Colors.grey.shade300,
),
),
],
),

const SizedBox(height: 25),

SizedBox(
width: double.infinity,
height: 55,
child: OutlinedButton.icon(
onPressed:
isLoading || isGoogleLoading
? null
    : continueWithGoogle,
icon: isGoogleLoading
? const SizedBox(
height: 22,
width: 22,
child:
CircularProgressIndicator(
strokeWidth: 2.2,
),
)
    : const Icon(
Icons.g_mobiledata,
),
label: Text(
isGoogleLoading
? 'Connecting to Google...'
    : 'Continue with Google',
),
style:
OutlinedButton.styleFrom(
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(15),
),
),
),
),

const SizedBox(height: 30),

Row(
mainAxisAlignment:
MainAxisAlignment.center,
children: [
const Text(
"Don't have an account? ",
),
GestureDetector(
onTap: () =>
context.push('/signup'),
child: const Text(
'Sign Up',
style: TextStyle(
color:
Color(0xFF6C3CE9),
fontWeight:
FontWeight.bold,
),
),
),
],
),
],
),
),
),
);
}
}
