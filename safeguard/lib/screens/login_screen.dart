import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'register_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _otpSent = false;
  bool _isPhoneLogin = true;
  bool _obscurePassword = true;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _phoneController.text = '+91 ';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1A237E),
              const Color(0xFF0D47A1),
              const Color(0xFF01579B),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                Text(
                  'Welcome Back!',
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Sign in to continue to SafeGuard',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),

                const SizedBox(height: 40),

                // Login Method Toggle
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isPhoneLogin = true;
                              _otpSent = false;
                              _otpController.clear();
                              authProvider.resetPhoneVerification();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _isPhoneLogin
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'Phone Login',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: _isPhoneLogin
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isPhoneLogin = false;
                              _otpSent = false;
                              _otpController.clear();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_isPhoneLogin
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'Email Login',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: !_isPhoneLogin
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // ============ PHONE LOGIN ============
                if (_isPhoneLogin) ...[
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            enabled: !_otpSent,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              labelStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              prefixIcon: const Icon(
                                Icons.phone,
                                color: Colors.white,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(16),
                              hintText: '+91 XXXXX XXXXX',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your phone number';
                              }
                              final cleaned = value.replaceAll(
                                RegExp(r'[^0-9]'),
                                '',
                              );
                              if (cleaned.length < 10) {
                                return 'Enter a valid 10-digit phone number';
                              }
                              return null;
                            },
                          ),
                        ),

                        const SizedBox(height: 16),

                        if (!_otpSent) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _checkAndSendOTP,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF0D47A1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF0D47A1),
                                      ),
                                    )
                                  : Text(
                                      'SEND OTP',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // OTP Section
                  if (_otpSent) ...[
                    const SizedBox(height: 16),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Enter OTP',
                          labelStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          prefixIcon: const Icon(
                            Icons.security,
                            color: Colors.white,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                          counterText: '',
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _verifyOTPAndLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'VERIFY & LOGIN',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _otpSent = false;
                                  _otpController.clear();
                                  final authProvider =
                                      Provider.of<AuthProvider>(
                                        context,
                                        listen: false,
                                      );
                                  authProvider.resetPhoneVerification();
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('BACK'),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _otpSent = false;
                          _otpController.clear();
                        });
                        _resendOTP();
                      },
                      child: Text(
                        'Resend OTP?',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ],

                // ============ EMAIL LOGIN ============
                if (!_isPhoneLogin) ...[
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              labelStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              prefixIcon: const Icon(
                                Icons.email,
                                color: Colors.white,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(16),
                              hintText: 'your@email.com',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!value.contains('@') ||
                                  !value.contains('.')) {
                                return 'Enter a valid email address';
                              }
                              return null;
                            },
                          ),
                        ),

                        const SizedBox(height: 16),

                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              prefixIcon: const Icon(
                                Icons.lock,
                                color: Colors.white,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                        ),

                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _loginWithEmail,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0D47A1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF0D47A1),
                                    ),
                                  )
                                : Text(
                                    'LOGIN',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Error Message
                if (authProvider.error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            authProvider.error!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Register Option
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'New user? ',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Register',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============ PHONE LOGIN METHODS ============

  void _checkAndSendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.clearError();

    try {
      // Clean phone number
      String phone = _phoneController.text.trim();
      phone = phone.replaceAll('+91 ', '');
      phone = phone.replaceAll('+91', '');
      phone = phone.replaceAll(' ', '');
      phone = phone.replaceAll('-', '');
      phone = '+91$phone';

      // Check if phone exists
      final exists = await authProvider.checkPhoneExists(phone);

      if (!exists) {
        setState(() => _isLoading = false);
        _showSnackBar('Phone not registered. Please register first.');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const RegisterScreen()),
        );
        return;
      }

      // Send OTP via Firebase
      final success = await authProvider.sendOTP(phone);

      setState(() => _isLoading = false);

      if (success) {
        setState(() => _otpSent = true);
        _showSnackBar('✅ OTP sent to your phone!');
      } else if (authProvider.error != null) {
        _showSnackBar(authProvider.error!);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error: ${e.toString()}');
    }
  }

  void _verifyOTPAndLogin() async {
    if (_otpController.text.isEmpty) {
      _showSnackBar('Please enter the OTP');
      return;
    }

    if (_otpController.text.length != 6) {
      _showSnackBar('Please enter a 6-digit OTP');
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.clearError();

    try {
      // Verify OTP with Firebase
      final verified = await authProvider.verifyOTP(_otpController.text);

      if (verified && authProvider.isPhoneVerified) {
        // Login with phone
        final phone = authProvider.pendingPhone;
        if (phone != null) {
          final success = await authProvider.loginWithPhone(phone);

          setState(() => _isLoading = false);

          if (success && mounted) {
            _showSnackBar('✅ Login successful!', isSuccess: true);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          } else if (authProvider.error != null) {
            _showSnackBar(authProvider.error!);
          }
        } else {
          setState(() => _isLoading = false);
          _showSnackBar('Phone number not found');
        }
      } else if (authProvider.error != null) {
        setState(() => _isLoading = false);
        _showSnackBar(authProvider.error!);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Verification failed: ${e.toString()}');
    }
  }

  void _resendOTP() async {
    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.clearError();

    try {
      // Clean phone number
      String phone = _phoneController.text.trim();
      phone = phone.replaceAll('+91 ', '');
      phone = phone.replaceAll('+91', '');
      phone = phone.replaceAll(' ', '');
      phone = phone.replaceAll('-', '');
      phone = '+91$phone';

      final success = await authProvider.sendOTP(phone);

      setState(() => _isLoading = false);

      if (success) {
        setState(() => _otpSent = true);
        _showSnackBar('✅ OTP resent to your phone!');
      } else if (authProvider.error != null) {
        _showSnackBar(authProvider.error!);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error: ${e.toString()}');
    }
  }

  // ============ EMAIL LOGIN METHOD ============

  void _loginWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.clearError();

    try {
      final success = await authProvider.loginWithEmail(
        _emailController.text.trim().toLowerCase(),
        _passwordController.text,
      );

      setState(() => _isLoading = false);

      if (success && mounted) {
        _showSnackBar('✅ Login successful!', isSuccess: true);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else if (authProvider.error != null) {
        _showSnackBar(authProvider.error!);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Login failed: ${e.toString()}');
    }
  }

  // ============ HELPER ============

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess || message.contains('sent')
            ? Colors.green
            : Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isSuccess ? 2 : 3),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
