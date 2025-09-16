import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskrunnerv2/sidepanel.dart';
import 'package:taskrunnerv2/signpage.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  String? _lastOrderId;
  bool _sidePanelExpanded = true;
  DateTime? _selectedDate;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FocusNode _focusNode = FocusNode();
  final AudioPlayer _audioPlayer = AudioPlayer();
  // Add inside _HomeScreenState
  bool get isPhoneView => MediaQuery.of(context).size.width < 600;
    Map<String, int> _getOrderSummary(List<QueryDocumentSnapshot> orders) {
    int total = orders.length;
    int completed = 0;
    int red = 0;
    int yellow = 0;
    int green = 0;

    for (var order in orders) {
      final isCompleted = order['completed'] == true;
      if (isCompleted) completed++;
      // Only count priorities for open (not completed) orders
      if (!isCompleted) {
        if (order['priority'] == 'High') red++;
        if (order['priority'] == 'Moderate') yellow++;
        if (order['priority'] == 'Low') green++;
      }
    }

    return {
      'total': total,
      'completed': completed,
      'red': red,
      'yellow': yellow,
      'green': green,
    };
  }

  late AnimationController _fluidController;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    _loadSidePanelState();
    _listenForNewOrders();
    _fluidController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();
    _loadThemePreference(); // Load theme preference on startup
  }

  Future<void> _loadSidePanelState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sidePanelExpanded = prefs.getBool('sidePanelExpanded') ?? true;
    });
  }

  Future<void> _saveSidePanelState(bool expanded) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('sidePanelExpanded', expanded);
  }

  Future<void> _saveThemePreference(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkTheme', isDark);
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkTheme = prefs.getBool('isDarkTheme') ?? true;
    });
  }

  @override
  void dispose() {
    _fluidController.dispose();
    _focusNode.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // Show priority selection dialog (unchanged)
  void _showPriorityDialog() {
    // ...your dialog code...
  }

  // Priority tile widget (unchanged)
  Widget _priorityTile(Color color, String label, String selectedPriority, Function(String) onTap) {
    // ...your code...
    return Container(); // placeholder
  }

  // Shop tile widget with icons (unchanged)
  Widget _shopTile(String iconPath, String shopName, String selectedShop, Function(String) onTap) {
    // ...your code...
    return Container(); // placeholder
  }

  void _toggleOrderCompletion(String orderId, bool isCompleted) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'completed': isCompleted,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Order updated successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating order: $e")),
      );
    }
  }

  // Store the message to Firestore
  void _storeMessageToFirestore(String message, String priority, String shop) async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("You need to be logged in to add Order.")),
      );
      return;
    }

    if (message.isNotEmpty && priority.isNotEmpty && shop.isNotEmpty) {
      try {
        await _firestore.collection('orders').add({
          'message': message,
          'priority': priority,
          'shopId': shop,
          'timestamp': FieldValue.serverTimestamp(),
          'userId': user.uid,
          'userName': user.displayName ?? user.email ?? "Unknown",
          'completed': false,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Order added to orders"),
            duration: Duration(seconds: 1),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error adding message: $e")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a Order, select a priority, and choose a shop")),
      );
    }
  }

  void _listenForNewOrders() {
    _firestore
        .collection('orders')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((QuerySnapshot snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final newOrder = change.doc;
          final String newOrderId = newOrder.id;

          // 🟢 Play sound only when a new order is added
          if (_lastOrderId != null && _lastOrderId != newOrderId) {
            _playDingSound();
          }

          _lastOrderId = newOrderId; // Store last known order ID
        }
      }
    });
  }

  // 🟢 Function to play the ding sound
  void _playDingSound() async {
    try {
      await _audioPlayer.play(AssetSource('ding.mp3')); // Add 'ding.mp3' in assets
    } catch (e) {
      print("Error playing sound: $e");
    }
  }

  // Display orders in a wrapping list
  void _editOrder(DocumentSnapshot order) {
    final TextEditingController editController =
        TextEditingController(text: order['message']);
    String editPriority = order['priority'];
    String editShop = order['shopId'];

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  constraints: BoxConstraints(maxWidth: 500),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 24,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: StatefulBuilder(
                    builder: (context, setState) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: editController,
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Sora',
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: "Edit your order...",
                            hintStyle: TextStyle(
                              color: Colors.white70,
                              fontFamily: 'Sora',
                              fontSize: 18,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                          ),
                          autofocus: true,
                          onSubmitted: (_) {
                            _updateOrder(order.id, editController.text, editPriority, editShop);
                            Navigator.pop(context);
                          },
                        ),
                        SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Priority buttons
                            _editPriorityCircle(Color(0xFFE74C3C), "High", editPriority, (p) {
                              setState(() => editPriority = p);
                            }),
                            SizedBox(width: 18),
                            _editPriorityCircle(Color(0xFFF7CA18), "Moderate", editPriority, (p) {
                              setState(() => editPriority = p);
                            }),
                            SizedBox(width: 18),
                            _editPriorityCircle(Color(0xFF2ECC71), "Low", editPriority, (p) {
                              setState(() => editPriority = p);
                            }),
                            SizedBox(width: 28),
                            // Divider
                            Container(
                              width: 2,
                              height: 36,
                              color: _isDarkTheme ? Colors.white24 : Colors.black26, // <-- Theme adaptive divider
                            ),
                            SizedBox(width: 28),
                            // Shop icons
                            _editShopCircle('assets/shop1.png', 'Shop 1', editShop, (s) {
                              setState(() => editShop = s);
                            }),
                            SizedBox(width: 14),
                            _editShopCircle('assets/shop2.png', 'Shop 2', editShop, (s) {
                              setState(() => editShop = s);
                            }),
                          ],
                        ),
                        SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text("Cancel", style: TextStyle(color: Colors.white70)),
                            ),
                            SizedBox(width: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFB16CEA),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              onPressed: () {
                                _updateOrder(order.id, editController.text, editPriority, editShop);
                                Navigator.pop(context);
                              },
                              child: Row(
                                children: [
                                  Icon(Icons.check, color: Colors.white),
                                  SizedBox(width: 6),
                                  Text("Save", style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ));
        },
    );
  }

  Widget _appBarSummaryItem(IconData icon, int count, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 15),
        SizedBox(width: 2),
        Text(
          "$count",
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  Widget _appBarColorSummary(Color color, int count) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Center(
        child: Text(
          "$count",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  // Add these helper widgets inside your _HomeScreenState:

  Widget _editPriorityCircle(Color color, String label, String selectedPriority, Function(String) onTap) {
    final bool selected = selectedPriority == label;
    return GestureDetector(
      onTap: () => onTap(label),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: color.withOpacity(0.35),
                blurRadius: 8,
              ),
          ],
        ),
        child: selected
            ? Icon(Icons.check, color: Colors.white, size: 22)
            : null,
      ),
    );
  }

  Widget _editShopCircle(String iconPath, String shopName, String selectedShop, Function(String) onTap) {
    final bool selected = selectedShop == shopName;
    return GestureDetector(
      onTap: () => onTap(shopName),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.purpleAccent : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: Colors.purpleAccent.withOpacity(0.18),
                blurRadius: 8,
              ),
          ],
        ),
        child: Center(
          child: Image.asset(iconPath, fit: BoxFit.contain, width: 36, height: 36),
        ),
      ),
    );
  }

  // And this update method if not present:
  void _updateOrder(String orderId, String message, String priority, String shop) async {
    await _firestore.collection('orders').doc(orderId).update({
      'message': message,
      'priority': priority,
      'shopId': shop,
    });
  }

  // 🟢 Updated _buildOrdersList with Edit Button
  Widget _buildOrdersList({bool phone = false}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('orders')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              "No orders available",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        var orders = snapshot.data!.docs;

        // Filter by selected date if not null
        if (_selectedDate != null) {
          final selectedStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
          orders = orders.where((order) {
            final ts = order['timestamp'];
            if (ts == null) return false;
            final dt = ts.toDate();
            return DateFormat('yyyy-MM-dd').format(dt) == selectedStr;
          }).toList();
        } else {
          // Today
          final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
          orders = orders.where((order) {
            final ts = order['timestamp'];
            if (ts == null) return false;
            final dt = ts.toDate();
            return DateFormat('yyyy-MM-dd').format(dt) == todayStr;
          }).toList();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            double screenWidth = constraints.maxWidth;
            bool isPhoneScreen = phone;
            double cardMaxWidth = isPhoneScreen ? (screenWidth / 2) - 8 : 250; // reduced spacing
            double cardMinWidth = isPhoneScreen ? 120 : 180; // allow smaller cards on phone
            return SingleChildScrollView(
              child: Wrap(
                spacing: isPhoneScreen ? 6 : 10, // less spacing for phone
                runSpacing: isPhoneScreen ? 6 : 10,
                alignment: WrapAlignment.start,
                children: orders.map((order) {
                  var message = order['message'];
                  var priority = order['priority'];
                  var isCompleted = order['completed'] ?? false;
                  var timestamp = order['timestamp'] != null
                      ? order['timestamp'].toDate()
                      : DateTime.now();
                  var shopId = order['shopId'];

                  String formattedTime = DateFormat('h:mm a').format(timestamp);

                  Color priorityColor = (priority == 'High')
                      ? Colors.redAccent
                      : (priority == 'Moderate')
                          ? const Color.fromARGB(255, 224, 247, 17)
                          : Colors.greenAccent;

                  Color borderColor = isCompleted ? Colors.grey : priorityColor;

                  // Determine shop icon path based on shopId
                  String shopIconPath = (shopId == 'Shop 1')
                      ? 'assets/shop1.png'
                      : 'assets/shop2.png';

                  // Safe userName extraction
                  final data = order.data();
                  final hasUserName = data != null &&
                      data is Map &&
                      data.containsKey('userName') &&
                      (data['userName'] ?? '').toString().trim().isNotEmpty;

                  return Stack(
                    children: [
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: cardMaxWidth,
                          minWidth: cardMinWidth,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: borderColor,
                            width: 4.5,
                          ),
                          boxShadow: [
                            if (!isCompleted)
                              BoxShadow(
                                color: borderColor.withOpacity(0.45),
                                blurRadius: 18,
                                spreadRadius: 2,
                                offset: Offset(0, 6),
                              ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _isDarkTheme
                                  ? Colors.black.withOpacity(0.55)
                                  : Colors.white.withOpacity(0.85), 
                              ),
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Only show user name if it exists and is not empty
                                  if (hasUserName)
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.person,
                                          color: _isDarkTheme ? Colors.white54 : Colors.black54, // <-- Theme adaptive
                                          size: 18,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          data['userName'],
                                          style: TextStyle(
                                            color: _isDarkTheme ? Colors.white70 : Colors.black87, // <-- Theme adaptive
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (hasUserName)
                                    SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Checkbox(
                                        value: isCompleted,
                                        onChanged: (newValue) {
                                          _updateOrderCompletion(order.id, newValue!);
                                        },
                                        activeColor: isCompleted ? Colors.blueAccent : borderColor,
                                        checkColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        side: BorderSide(
                                          color: isCompleted ? Colors.blueAccent : borderColor,
                                          width: 2.5,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          message,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: _isDarkTheme
                                                ? Colors.white.withOpacity(isCompleted ? 0.5 : 0.95)
                                                : Colors.black.withOpacity(isCompleted ? 0.5 : 0.95), // <-- Theme adaptive
                                            letterSpacing: 0.1,
                                            height: 1.3,
                                            decoration: isCompleted
                                                ? TextDecoration.lineThrough
                                                : TextDecoration.none,
                                            shadows: [
                                              Shadow(
                                                color: _isDarkTheme
                                                    ? Colors.black.withOpacity(0.18)
                                                    : Colors.grey.withOpacity(0.10), // <-- Theme adaptive
                                                blurRadius: 2,
                                              ),
                                            ],
                                          ),
                                          softWrap: true,
                                          overflow: TextOverflow.visible,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    children: [
                                      // Shop logo
                                      CircleAvatar(
                                        backgroundColor: Colors.white.withOpacity(0.10),
                                        radius: phone ? 14 : 18,
                                        child: Image.asset(
                                          shopIconPath,
                                          fit: BoxFit.contain,
                                          width: phone ? 16 : 22,
                                          height: phone ? 16 : 22,
                                        ),
                                      ),
                                      Spacer(),
                                      // Time
                                      Text(
                                        formattedTime,
                                        style: TextStyle(
                                          fontSize: phone ? 11 : 13,
                                          color: _isDarkTheme ? Colors.white60 : Colors.black54, // <-- Theme adaptive
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(width: phone ? 4 : 8),
                                      // Edit button
                                      _glassIconButton(
                                        icon: Icons.edit_rounded,
                                        onTap: () => _editOrder(order),
                                        color: Colors.blueAccent,
                                        tooltip: "Edit",
                                        size: phone ? 18 : 20,
                                      ),
                                      SizedBox(width: phone ? 2 : 4),
                                      // Delete button
                                      _glassIconButton(
                                        icon: Icons.delete_forever_rounded,
                                        onTap: () => _deleteOrder(order.id),
                                        color: Colors.redAccent,
                                        tooltip: "Delete",
                                        size: phone ? 18 : 20,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Fluid animated border overlay (only when completed)
                      
                    ],
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  void _updateOrderCompletion(String orderId, bool isCompleted) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'completed': isCompleted,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCompleted
              ? "Order marked as completed"
              : "Order marked as not completed"),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error updating order: $e"),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _deleteOrder(String orderId) async {
    try {
      await _firestore.collection('orders').doc(orderId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Order deleted successfully"),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error deleting order: $e"),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _deleteAllOrders() async {
    try {
      var orders = await _firestore.collection('orders').get();
      for (var order in orders.docs) {
        await _firestore.collection('orders').doc(order.id).delete();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("All orders deleted successfully"),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error deleting all orders: $e"),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _logOut() async {
    await FirebaseAuth.instance.signOut();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Logged out successfully"),
        duration: Duration(seconds: 1),
      ),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => SignPage()),
      (route) => false,
    );
  }

  bool _isDarkTheme = true; // <-- Add this

  @override
  Widget build(BuildContext context) {
    final bool phone = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      drawer: phone
        ? Drawer(
            child: SafeArea(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('orders')
                    .orderBy('timestamp', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  var orders = snapshot.hasData ? snapshot.data!.docs : <QueryDocumentSnapshot>[];
                  // Filter by selected date if needed
                  if (_selectedDate != null) {
                    final selectedStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
                    orders = orders.where((order) {
                      final ts = order['timestamp'];
                      if (ts == null) return false;
                      final dt = ts.toDate();
                      return DateFormat('yyyy-MM-dd').format(dt) == selectedStr;
                    }).toList();
                  } else {
                    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
                    orders = orders.where((order) {
                      final ts = order['timestamp'];
                      if (ts == null) return false;
                      final dt = ts.toDate();
                      return DateFormat('yyyy-MM-dd').format(dt) == todayStr;
                    }).toList();
                  }
                  final summary = _getOrderSummary(orders);

                  return SidePanel(
                    expanded: true,
                    onExpandToggle: (_) {},
                    onDateSelected: (date) {
                      setState(() => _selectedDate = date);
                      Navigator.pop(context); // close drawer after selection
                    },
                    selectedDate: _selectedDate,
                    onLogout: _logOut,
                    onDeleteAll: _deleteAllOrders,
                    summaryBar: OrderSummaryBar(
                      total: summary['total']!,
                      completed: summary['completed']!,
                      red: summary['red']!,
                      yellow: summary['yellow']!,
                      green: summary['green']!,
                      compact: true, 
                      isDarkTheme: _isDarkTheme,
                    ),
                    isDarkTheme: _isDarkTheme, // <-- Add this argument
                    onThemeToggle: () {
                      setState(() => _isDarkTheme = !_isDarkTheme);
                      _saveThemePreference(_isDarkTheme); // <-- Save theme preference
                    }, // <-- Add this argument
                  );
                },
              ),
            ),
          )
        : null,
      appBar: phone
        ? PreferredSize(
            preferredSize: Size.fromHeight(90),
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              title: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center, // <-- Center column contents
                  children: [
                    Center( // <-- Center the logo horizontally
                      child: SizedBox(
                        height: 40,
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    SizedBox(height: 2),
                    StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('orders')
                          .orderBy('timestamp', descending: false)
                          .snapshots(),
                      builder: (context, snapshot) {
                        var orders = snapshot.hasData ? snapshot.data!.docs : <QueryDocumentSnapshot>[];
                        // Filter by selected date if needed
                        if (_selectedDate != null) {
                          final selectedStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
                          orders = orders.where((order) {
                            final ts = order['timestamp'];
                            if (ts == null) return false;
                            final dt = ts.toDate();
                            return DateFormat('yyyy-MM-dd').format(dt) == selectedStr;
                          }).toList();
                        } else {
                          final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
                          orders = orders.where((order) {
                            final ts = order['timestamp'];
                            if (ts == null) return false;
                            final dt = ts.toDate();
                            return DateFormat('yyyy-MM-dd').format(dt) == todayStr;
                          }).toList();
                        }
                        final summary = _getOrderSummary(orders);

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _appBarSummaryItem(Icons.list_alt, summary['total']!, Colors.white),
                            SizedBox(width: 8),
                            _appBarSummaryItem(Icons.check_circle, summary['completed']!, Colors.greenAccent),
                            SizedBox(width: 8),
                            _appBarColorSummary(Colors.redAccent, summary['red']!),
                            SizedBox(width: 4),
                            _appBarColorSummary(Color(0xFFF7CA18), summary['yellow']!),
                            SizedBox(width: 4),
                            _appBarColorSummary(Colors.greenAccent, summary['green']!),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              leading: Builder(
                builder: (context) => IconButton(
                  icon: Icon(Icons.menu, color: Colors.white, size: 28),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ),
          )
        : null,
      extendBodyBehindAppBar: true,
      body: SafeArea(
        top: !phone,
        child: Stack(
          children: [
            // Background image and blur
            Positioned.fill(
              child: Image.asset(
                _isDarkTheme ? 'assets/waveblue.png' : 'assets/lightbg.png', // <-- Switch background
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: _isDarkTheme
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.04), // <-- Lighter overlay
                ),
              ),
            ),
            // SidePanel for desktop only
            if (!phone)
              Positioned(
                top: 0,
                left: 0,
                bottom: 0,
                child: SidePanel(
                  expanded: _sidePanelExpanded,
                  onExpandToggle: (val) {
                    setState(() => _sidePanelExpanded = val);
                    _saveSidePanelState(val);
                  },
                  onDateSelected: (date) => setState(() => _selectedDate = date),
                  selectedDate: _selectedDate,
                  onLogout: _logOut,
                  onDeleteAll: _deleteAllOrders,
                  isDarkTheme: _isDarkTheme, // <-- Pass theme state
                  onThemeToggle: () {
                    setState(() => _isDarkTheme = !_isDarkTheme);
                    _saveThemePreference(_isDarkTheme); // <-- Pass toggle callback
                  },
                ),
              ),
            // Main content
            Positioned.fill(
              left: (!phone && _sidePanelExpanded) ? 230 : (!phone ? 56 : 0),
              child: Builder(
                builder: (context) => Column(
                  children: [
                    if (phone)
                      Align(
                        alignment: Alignment.topLeft,
                        child: IconButton(
                          icon: Icon(Icons.menu, color: const Color.fromARGB(0, 255, 255, 255), size: 32),
                          onPressed: () => Scaffold.of(context).openDrawer(),
                        ),
                      ),
                    SizedBox(height: phone ? 8 : 16),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: phone ? 4 : 0, vertical: phone ? 4 : 0),
                        child: _buildOrdersList(phone: phone),
                      ),
                    ),
                    if (!phone)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: OrderInputBar(
                                isPhone: phone,
                                isDarkTheme: _isDarkTheme, 
                                onSend: (message, priority, shop) {
                                  _storeMessageToFirestore(message, priority, shop);
                                },
                              ),
                            ),
                            SizedBox(width: 18),
                            StreamBuilder<QuerySnapshot>(
                              stream: _firestore
                                  .collection('orders')
                                  .orderBy('timestamp', descending: false)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return SizedBox();
                                var orders = snapshot.data!.docs;

                                // Filter by selected date if needed
                                if (_selectedDate != null) {
                                  final selectedStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
                                  orders = orders.where((order) {
                                    final ts = order['timestamp'];
                                    if (ts == null) return false;
                                    final dt = ts.toDate();
                                    return DateFormat('yyyy-MM-dd').format(dt) == selectedStr;
                                  }).toList();
                                } else {
                                  final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
                                  orders = orders.where((order) {
                                    final ts = order['timestamp'];
                                    if (ts == null) return false;
                                    final dt = ts.toDate();
                                    return DateFormat('yyyy-MM-dd').format(dt) == todayStr;
                                  }).toList();
                                }

                                final summary = _getOrderSummary(orders);

                                return OrderSummaryBar(
                                  total: summary['total']!,
                                  completed: summary['completed']!,
                                  red: summary['red']!,
                                  yellow: summary['yellow']!,
                                  green: summary['green']!,
                                  isDarkTheme: _isDarkTheme,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    if (phone)
                      OrderInputBar(
                        isPhone: phone,
                        isDarkTheme: _isDarkTheme, // <-- Add this
                        onSend: (message, priority, shop) {
                          _storeMessageToFirestore(message, priority, shop);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    String? tooltip,
    double size = 20,
  }) {
    return Tooltip(
      message: tooltip ?? "",
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: size + 12,
          height: size + 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.18),
                Colors.white.withOpacity(0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.18),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: color.withOpacity(0.35),
              width: 1.2,
            ),
          ),
          child: Icon(icon, color: color, size: size),
        ),
      ),
    );
  }
}

// --- Fluid Border Painter ---
class _FluidBorderPainter extends CustomPainter {
  final double progress;
  _FluidBorderPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final borderWidth = 4.5;
    final rect = Rect.fromLTWH(
      borderWidth / 2,
      borderWidth / 2,
      size.width - borderWidth,
      size.height - borderWidth,
    );
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.blueAccent.withOpacity(0.7),
          Colors.lightBlueAccent.withOpacity(0.7),
          Colors.blueAccent.withOpacity(0.7),
        ],
        stops: [
          (progress + 0.0) % 1.0,
          (progress + 0.5) % 1.0,
          (progress + 1.0) % 1.0,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        tileMode: TileMode.mirror,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(22)),
      paint,
    );
  }
  @override
  bool shouldRepaint(_FluidBorderPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// --- OrderInputBar Widget ---
class OrderInputBar extends StatefulWidget {
  final void Function(String message, String priority, String shop) onSend;
  final bool isPhone;
  final bool isDarkTheme; // <-- Add this

  const OrderInputBar({
    required this.onSend,
    this.isPhone = false,
    required this.isDarkTheme, // <-- Add this
    super.key,
  });

  @override
  State<OrderInputBar> createState() => _OrderInputBarState();
}

class _OrderInputBarState extends State<OrderInputBar> {
  final TextEditingController _controller = TextEditingController();
  String _selectedPriority = '';
  String _selectedShop = '';

  @override
  Widget build(BuildContext context) {
    final bool phone = widget.isPhone;
    final bool isDarkTheme = widget.isDarkTheme; // <-- Use this

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            constraints: BoxConstraints(maxWidth: phone ? double.infinity : 700),
            margin: EdgeInsets.symmetric(vertical: phone ? 4 : 12, horizontal: phone ? 4 : 0),
            padding: EdgeInsets.symmetric(horizontal: phone ? 8 : 16, vertical: phone ? 6 : 10),
            decoration: BoxDecoration(
              color: isDarkTheme
                  ? Colors.black.withOpacity(0.55)
                  : Colors.white.withOpacity(0.85), // <-- Theme background
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: isDarkTheme
                      ? Colors.black.withOpacity(0.18)
                      : Colors.grey.withOpacity(0.10), // <-- Theme shadow
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: phone
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              style: TextStyle(
                                color: isDarkTheme ? Colors.white : Colors.black, // <-- Theme text
                                fontFamily: 'Sora',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: "Enter your order...",
                                hintStyle: TextStyle(
                                  color: isDarkTheme ? Colors.white70 : Colors.black54, // <-- Theme hint
                                  fontFamily: 'Sora',
                                  fontSize: 16,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                              ),
                              onSubmitted: (_) {
                                widget.onSend(
                                  _controller.text,
                                  _selectedPriority,
                                  _selectedShop,
                                );
                                setState(() {
                                  _controller.clear();
                                });
                              },
                            ),
                          ),
                          SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              widget.onSend(
                                _controller.text,
                                _selectedPriority,
                                _selectedShop,
                              );
                              setState(() {
                                _controller.clear();
                              });
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [Color(0xFFB16CEA), Color(0xFF5F52D6)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.purple.withOpacity(0.18),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 28),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _priorityCircle(Color(0xFFE74C3C), "High"),
                          SizedBox(width: 10),
                          _priorityCircle(Color(0xFFF7CA18), "Moderate"),
                          SizedBox(width: 10),
                          _priorityCircle(Color(0xFF2ECC71), "Low"),
                          SizedBox(width: 18),
                          _shopCircle('assets/shop1.png', 'Shop 1'),
                          SizedBox(width: 8),
                          _shopCircle('assets/shop2.png', 'Shop 2'),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      // Input field
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _controller,
                          style: TextStyle(
                            color: isDarkTheme ? Colors.white : Colors.black, // <-- Theme text
                            fontFamily: 'Sora',
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: "Enter your order...",
                            hintStyle: TextStyle(
                              color: isDarkTheme ? Colors.white70 : Colors.black54, // <-- Theme hint
                              fontFamily: 'Sora',
                              fontSize: 18,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                          ),
                          onSubmitted: (_) {
                            widget.onSend(
                              _controller.text,
                              _selectedPriority,
                              _selectedShop,
                            );
                            setState(() {
                              _controller.clear();
                            });
                          },
                        ),
                      ),
                      SizedBox(width: 32),
                      _priorityCircle(Color(0xFFE74C3C), "High"),
                      SizedBox(width: 18),
                      _priorityCircle(Color(0xFFF7CA18), "Moderate"),
                      SizedBox(width: 18),
                      _priorityCircle(Color(0xFF2ECC71), "Low"),
                      SizedBox(width: 28),
                      Container(
                        width: 2,
                        height: 36,
                        color: isDarkTheme ? Colors.white24 : Colors.black26, // <-- Theme adaptive divider
                      ),
                      SizedBox(width: 28),
                      _shopCircle('assets/shop1.png', 'Shop 1'),
                      SizedBox(width: 14),
                      _shopCircle('assets/shop2.png', 'Shop 2'),
                      SizedBox(width: 28),
                      GestureDetector(
                        onTap: () {
                          widget.onSend(
                            _controller.text,
                            _selectedPriority,
                            _selectedShop,
                          );
                          setState(() {
                            _controller.clear();
                          });
                        },
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFFB16CEA), Color(0xFF5F52D6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purple.withOpacity(0.18),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 32),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
    ));
  }

  

  Widget _priorityCircle(Color color, String label) {
    final bool selected = _selectedPriority == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedPriority = label),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: color.withOpacity(0.35),
                blurRadius: 8,
              ),
          ],
        ),
        child: selected
            ? Icon(Icons.check, color: Colors.white, size: 22)
            : null,
      ),
    );
  }

  Widget _shopCircle(String iconPath, String shopName) {
    final bool selected = _selectedShop == shopName;
    return GestureDetector(
      onTap: () => setState(() => _selectedShop = shopName),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.purpleAccent : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: Colors.purpleAccent.withOpacity(0.18),
                blurRadius: 8,
              ),
          ],
        ),
        child: Center(
          child: Image.asset(iconPath, fit: BoxFit.contain, width: 36, height: 36),
        ),
      ),
    );
  }

  
}
class OrderSummaryBar extends StatelessWidget {
  final int total;
  final int completed;
  final int red;
  final int yellow;
  final int green;
  final bool compact;
  final bool isDarkTheme; // <-- Add this

  const OrderSummaryBar({
    required this.total,
    required this.completed,
    required this.red,
    required this.yellow,
    required this.green,
    this.compact = false,
    required this.isDarkTheme, // <-- Add this
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDarkTheme = this.isDarkTheme; // <-- Use the passed value

    final double iconSize = compact ? 16 : 22;
    final double circleSize = compact ? 18 : 28;
    final double fontSize = compact ? 12 : 18;
    final double labelSize = compact ? 10 : 14;
    final double paddingV = compact ? 8 : 18;
    final double paddingH = compact ? 8 : 24;

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: paddingH, vertical: paddingV),
          decoration: BoxDecoration(
            color: isDarkTheme
                ? Colors.black.withOpacity(0.55)
                : Colors.white.withOpacity(0.85), // <-- Theme adaptive background
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: isDarkTheme
                    ? Colors.black.withOpacity(0.10)
                    : Colors.grey.withOpacity(0.10), // <-- Theme adaptive shadow
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _summaryItem(Icons.list_alt, "Total", total, isDarkTheme ? Colors.white : Colors.black, iconSize, fontSize, labelSize, isDarkTheme),
              SizedBox(width: compact ? 8 : 18),
              _summaryItem(Icons.check_circle, "Completed", completed, Colors.greenAccent, iconSize, fontSize, labelSize, isDarkTheme),
              SizedBox(width: compact ? 8 : 18),
              _colorSummary(Colors.redAccent, red, circleSize, fontSize),
              SizedBox(width: compact ? 4 : 8),
              _colorSummary(Color(0xFFF7CA18), yellow, circleSize, fontSize),
              SizedBox(width: compact ? 4 : 8),
              _colorSummary(Colors.greenAccent, green, circleSize, fontSize),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryItem(IconData icon, String label, int count, Color color, double iconSize, double fontSize, double labelSize, bool isDarkTheme) {
    return Row(
      children: [
        Icon(icon, color: color, size: iconSize),
        SizedBox(width: 3),
        Text("$count", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: fontSize)),
        SizedBox(width: 2),
        Text(label, style: TextStyle(color: isDarkTheme ? Colors.white70 : Colors.black54, fontSize: labelSize)), // <-- Theme adaptive label
      ],
    );
  }

  Widget _colorSummary(Color color, int count, double size, double fontSize) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Center(
        child: Text(
          "$count",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: fontSize - 2,
          ),
        ),
      ),
    );
  }
}