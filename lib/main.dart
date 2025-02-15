import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:taskrunnerv2/shared/constant.dart';
import 'signpage.dart'; // Import the new SignPage
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: Constants.apiKey,
            appId: Constants.appId,
            messagingSenderId: Constants.messagingSenderId,
            projectId: Constants.projectId));
  } else {
    await Firebase.initializeApp();
  }
  
  runApp(MyApp()); // Remove const here since the constructor is not const
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taskrunner V2',
      debugShowCheckedModeBanner: false, // Removes the debug banner
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: SignPage(), // You can keep this non-const if the constructor is not const
    );
  }
}
