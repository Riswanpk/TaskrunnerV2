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

  late AnimationController _fluidController;

  @override
  void initState() {
    super.initState();
    _loadSidePanelState();
    _listenForNewOrders();
    _fluidController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();
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
        SnackBar(content: Text("You need to be logged in to add messages.")),
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
            content: Text("Message added to orders"),
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
        SnackBar(content: Text("Please enter a message, select a priority, and choose a shop")),
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
                              color: Colors.white24,
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
          ),
        );
      },
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
  Widget _buildOrdersList() {
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
            bool isPhoneScreen = screenWidth < 600;
            double cardMaxWidth = isPhoneScreen ? (screenWidth / 2) - 20 : 250;

            return SingleChildScrollView(
              child: Wrap(
                spacing: 15,
                runSpacing: 15,
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
                        constraints: BoxConstraints(maxWidth: cardMaxWidth),
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
                                color: Colors.black.withOpacity(0.55),
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
                                        Icon(Icons.person, color: Colors.white54, size: 18),
                                        SizedBox(width: 6),
                                        Text(
                                          data['userName'],
                                          style: TextStyle(
                                            color: Colors.white70,
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
                                            color: Colors.white.withOpacity(isCompleted ? 0.5 : 0.95),
                                            letterSpacing: 0.1,
                                            height: 1.3,
                                            decoration: isCompleted
                                                ? TextDecoration.lineThrough
                                                : TextDecoration.none,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black.withOpacity(0.18),
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
                                        radius: 18,
                                        child: Image.asset(
                                          shopIconPath,
                                          fit: BoxFit.contain,
                                          width: 22,
                                          height: 22,
                                        ),
                                      ),
                                      Spacer(),
                                      // Time
                                      Text(
                                        formattedTime,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white60,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      // Edit button
                                      _glassIconButton(
                                        icon: Icons.edit_rounded,
                                        onTap: () => _editOrder(order),
                                        color: Colors.blueAccent,
                                        tooltip: "Edit",
                                      ),
                                      SizedBox(width: 4),
                                      // Delete button
                                      _glassIconButton(
                                        icon: Icons.delete_forever_rounded,
                                        onTap: () => _deleteOrder(order.id),
                                        color: Colors.redAccent,
                                        tooltip: "Delete",
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
                      if (isCompleted)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedBuilder(
                              animation: _fluidController,
                              builder: (context, child) {
                                return CustomPaint(
                                  painter: _FluidBorderPainter(_fluidController.value),
                                );
                              },
                            ),
                          ),
                        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Background image and blur
            Positioned.fill(
              child: Image.asset(
                'assets/lightwaves.png',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            // SidePanel (always on top, left)
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
              ),
            ),
            // Main content (shifted right by side panel width)
            Positioned.fill(
              left: _sidePanelExpanded ? 230 : 56,
              child: Column(
                children: [
                  SizedBox(height: 16),
                  Expanded(child: _buildOrdersList()),
                  OrderInputBar(
                    onSend: (message, priority, shop) {
                      _storeMessageToFirestore(message, priority, shop);
                    },
                  ),
                ],
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
  }) {
    return Tooltip(
      message: tooltip ?? "",
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
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
          child: Icon(icon, color: color, size: 20),
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

  const OrderInputBar({
    required this.onSend,
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
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            constraints: BoxConstraints(maxWidth: 700),
            margin: EdgeInsets.symmetric(vertical: 12),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                // Input field
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _controller,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Sora',
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: "Enter your order...",
                      hintStyle: TextStyle(
                        color: Colors.white70,
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
                      // Optionally clear input after send:
                       setState(() {
                        _controller.clear();
                      //   _selectedPriority = '';
                      //   _selectedShop = '';
                      });
                    },
                  ),
                ),
                SizedBox(width: 32),
                // Priority buttons (circular)
                _priorityCircle(Color(0xFFE74C3C), "High"),
                SizedBox(width: 18),
                _priorityCircle(Color(0xFFF7CA18), "Moderate"),
                SizedBox(width: 18),
                _priorityCircle(Color(0xFF2ECC71), "Low"),
                SizedBox(width: 28),
                // Divider
                Container(
                  width: 2,
                  height: 36,
                  color: Colors.white24,
                ),
                SizedBox(width: 28),
                // Shop icon (circular, white background)
                _shopCircle('assets/shop1.png', 'Shop 1'),
                SizedBox(width: 14),
                _shopCircle('assets/shop2.png', 'Shop 2'),
                SizedBox(width: 28),
                // Send button (circular gradient)
                GestureDetector(
                  onTap: () {
                    widget.onSend(
                      _controller.text,
                      _selectedPriority,
                      _selectedShop,
                    );
                    // Optionally clear input after send:
                    // setState(() {
                    //   _controller.clear();
                    //   _selectedPriority = '';
                    //   _selectedShop = '';
                    // });
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
      ),
    );
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