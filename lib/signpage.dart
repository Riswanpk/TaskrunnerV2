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
    clientId: "860390615871-embsj688kooiiubkkl8acfb403c4eajt.apps.googleusercontent.com", // Replace with your actual Web Client ID
  );

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkSignInStatus();
  }

  // Check if the user is already signed in
  Future<void> _checkSignInStatus() async {
    try {
      final GoogleSignInAccount? account = await googleSignIn.currentUser;
      if (account != null) {
        // If the user is already signed in, authenticate with Firebase
        _authenticateWithFirebase(account);
      } else {
        // If not signed in, try silent sign-in
        _trySilentSignIn();
      }
    } catch (error) {
      print("Error checking sign-in status: $error");
    }
  }

  // Attempt silent sign-in
  Future<void> _trySilentSignIn() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final GoogleSignInAccount? account = await googleSignIn.signInSilently();
      if (account != null) {
        _authenticateWithFirebase(account);
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (error) {
      print("Silent sign-in failed: $error");
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Handle sign-in success
  Future<void> _authenticateWithFirebase(GoogleSignInAccount account) async {
    try {
      // Authenticate with Firebase using the Google credentials
      final GoogleSignInAuthentication googleAuth = await account.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      print("Signed in as ${userCredential.user?.displayName}");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Welcome, ${userCredential.user?.displayName}!"),
          duration: Duration(seconds: 1), // Display the SnackBar for 1 second
        ),
      );


      // Navigate to HomeScreen after successful sign-in
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()), // Replace with your existing HomeScreen widget
      );
    } catch (error) {
      print("Firebase sign-in failed: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Sign-in failed: $error")),
      );
    }
  }

  // Render the Google Sign-In button
  Widget _buildGoogleSignInButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : () async {
        setState(() {
          _isLoading = true;
        });
        try {
          final account = await googleSignIn.signIn();
          if (account != null) {
            _authenticateWithFirebase(account);
          } else {
            setState(() {
              _isLoading = false;
            });
          }
        } catch (error) {
          print("Sign-in failed: $error");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Sign-in failed: $error")),
          );
          setState(() {
            _isLoading = false;
          });
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.purple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      child: _isLoading
          ? CircularProgressIndicator(
              color: Colors.white,
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/google.png',
                  height: 32,
                  width: 32,
                ),
                SizedBox(width: 12),
                Text(
                  'Sign in with Google',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Colors.purple,
            height: 60,
            width: double.infinity,
            child: Center(
              child: Text(
                'Taskrunner V2',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'RobotoCondensed',
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [Colors.purple, Colors.blue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              'Welcome to Taskrunner V2',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(height: 40),
          Expanded(
            child: Center(
              child: _buildGoogleSignInButton(),
            ),
          ),
        ],
      ),
    );
  }
}
