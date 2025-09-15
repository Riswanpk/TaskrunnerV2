import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'homescreen.dart';

class SignPage extends StatefulWidget {
  @override
  _SignPageState createState() => _SignPageState();
}

class _SignPageState extends State<SignPage> {
  final GoogleSignIn googleSignIn = GoogleSignIn(
    clientId: "860390615871-embsj688kooiiubkkl8acfb403c4eajt.apps.googleusercontent.com",
  );
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final account = await googleSignIn.signIn();
      if (account != null) {
        final googleAuth = await account.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sign-in failed: $e")));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _signInWithEmail() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sign-in failed: $e")));
    }
    setState(() => _isLoading = false);
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: 420,
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 36),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.18), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.08),
                blurRadius: 32,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSocialButton({required String label, required String asset, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.22)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              asset.isNotEmpty
                  ? Image.asset(asset, height: 22)
                  : Icon(Icons.apple, color: Colors.black, size: 22),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required String hint, required TextEditingController controller, bool obscure = false, VoidCallback? toggleObscure}) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          suffixIcon: toggleObscure != null
              ? IconButton(
                  icon: Icon(
                    obscure ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  onPressed: toggleObscure,
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/lightwaves.png',
              fit: BoxFit.cover,
            ),
          ),
          // Glass card
          Center(
            child: _buildGlassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Login with",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 24),
                  Row(
                    children: [
                      _buildSocialButton(
                        label: "Google",
                        asset: 'assets/google.png',
                        onTap: _signInWithGoogle,
                      ),
                      SizedBox(width: 16),
                      _buildSocialButton(
                        label: "Apple",
                        asset: '',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Apple sign-in not implemented")),
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Colors.white.withOpacity(0.22),
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          "or",
                          style: TextStyle(color: Colors.white.withOpacity(0.7)),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Colors.white.withOpacity(0.22),
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Email",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                  ),
                  _buildTextField(
                    hint: "Enter your email",
                    controller: _emailController,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Password",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                  ),
                  _buildTextField(
                    hint: "Enter your password",
                    controller: _passwordController,
                    obscure: _obscurePassword,
                    toggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signInWithEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.85),
                        foregroundColor: Colors.green.shade700,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          letterSpacing: 0.5,
                        ),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.green)
                          : Text("Login"),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // App name
          Positioned(
            top: 48,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "Task runner v2.3",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  shadows: [
                    Shadow(
                      color: Colors.green.withOpacity(0.4),
                      blurRadius: 12,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
