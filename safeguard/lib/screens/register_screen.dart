import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _otpSent = false;
  bool _phoneVerified = false;

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
                const SizedBox(height: 20),

                // Back Button
                IconButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),

                const SizedBox(height: 10),

                Text(
                  'Create Profile',
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Set up your safety profile',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),

                const SizedBox(height: 40),

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Name
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: TextFormField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            labelStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                            prefixIcon: const Icon(
                              Icons.person,
                              color: Colors.white,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your name';
                            }
                            if (value.length < 2) {
                              return 'Name must be at least 2 characters';
                            }
                            return null;
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Email
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
                            if (!value.contains('@') || !value.contains('.')) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Phone with OTP
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Container(
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
                                enabled: !_phoneVerified,
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
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 56,
                              child: _phoneVerified
                                  ? Container(
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.green),
                                      ),
                                      child: const Center(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              color: Colors.green,
                                              size: 20,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Verified',
                                              style: TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : ElevatedButton(
                                      onPressed: _isLoading ? null : _sendOTP,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: const Color(
                                          0xFF0D47A1,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
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
                                              _otpSent ? 'RESEND' : 'SEND OTP',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                    ),
                            ),
                          ),
                        ],
                      ),

                      // OTP Input
                      if (_otpSent && !_phoneVerified) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Container(
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
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _verifyOTP,
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
                                      : const Text('VERIFY'),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _otpSent = false;
                              _otpController.clear();
                              final authProvider = Provider.of<AuthProvider>(
                                context,
                                listen: false,
                              );
                              authProvider.resetPhoneVerification();
                            });
                          },
                          child: Text(
                            'Change phone number?',
                            style: GoogleFonts.poppins(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Password
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
                              return 'Please enter a password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Confirm Password
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            labelStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: Colors.white,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

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

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed:
                        _isLoading || authProvider.isLoading || !_phoneVerified
                        ? null
                        : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0D47A1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 5,
                    ),
                    child: _isLoading || authProvider.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF0D47A1),
                            ),
                          )
                        : Text(
                            _phoneVerified ? 'REGISTER' : 'VERIFY PHONE FIRST',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Login',
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

  // ============ PHONE OTP METHODS ============

  void _sendOTP() async {
    if (_phoneController.text.isEmpty) {
      _showSnackBar('Please enter your phone number');
      return;
    }

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

      // Check if phone already exists
      final exists = await authProvider.checkPhoneExists(phone);
      if (exists) {
        setState(() => _isLoading = false);
        _showSnackBar('Phone already registered. Please login.');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
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

  void _verifyOTP() async {
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
      final success = await authProvider.verifyOTP(_otpController.text);

      setState(() => _isLoading = false);

      if (success && authProvider.isPhoneVerified) {
        setState(() => _phoneVerified = true);
        _showSnackBar('✅ Phone verified successfully!', isSuccess: true);
      } else if (authProvider.error != null) {
        _showSnackBar(authProvider.error!);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Verification failed: ${e.toString()}');
    }
  }

  // ============ REGISTER METHOD ============

  void _handleRegister() async {
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

      final success = await authProvider.registerUser(
        name: _nameController.text.trim(),
        phone: phone,
        email: _emailController.text.trim().toLowerCase(),
        password: _passwordController.text,
      );

      setState(() => _isLoading = false);

      if (success && mounted) {
        _showSnackBar('✅ Registration successful!', isSuccess: true);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else if (authProvider.error != null) {
        _showSnackBar(authProvider.error!);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Registration failed: ${e.toString()}');
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
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }
}
