import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:taskrunnerv2/signpage.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  String _selectedPriority = '';
  String _typedMessage = '';
  String _selectedShop = ''; 
  // Initialize with an empty string or a default value

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FocusNode _focusNode = FocusNode();
  
  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // Show priority selection dialog
void _showPriorityDialog() {
  showDialog(
    context: context,
    builder: (context) {
      String selectedPriority = _selectedPriority; // Local variable for priority
      String selectedShop = _selectedShop; // Local variable for shop

      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text("Select Priority and Shop"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Priority selection (unchanged)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _priorityTile(Colors.red, "High", selectedPriority, (newPriority) {
                      setDialogState(() {
                        selectedPriority = newPriority;
                      });
                    }),
                    _priorityTile(Colors.yellow, "Moderate", selectedPriority, (newPriority) {
                      setDialogState(() {
                        selectedPriority = newPriority;
                      });
                    }),
                    _priorityTile(Colors.green, "Low", selectedPriority, (newPriority) {
                      setDialogState(() {
                        selectedPriority = newPriority;
                      });
                    }),
                  ],
                ),
                SizedBox(height: 10),
                Text("Select Priority by tapping on the color"),
                SizedBox(height: 10),

                // Shop selection with custom icons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _shopTile('assets/shop1.png', 'Shop 1', selectedShop,
                        (newShop) {
                      setDialogState(() {
                        selectedShop = newShop;
                      });
                    }),
                    _shopTile('assets/shop2.png', 'Shop 2', selectedShop,
                        (newShop) {
                      setDialogState(() {
                        selectedShop = newShop;
                      });
                    }),
                  ],
                ),
                SizedBox(height: 10),

                // Submit button with validation
                ElevatedButton(
                  onPressed: () {
                    if (selectedPriority.isNotEmpty && selectedShop.isNotEmpty) {
                      setState(() {
                        _selectedPriority = selectedPriority;
                        _selectedShop = selectedShop;
                      });
                      Navigator.pop(context);
                      _storeMessageToFirestore(); // Store data after submitting
                    } else {
                      // Show a message if priority or shop is not selected
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please select both priority and shop')),
                      );
                    }
                  },
                  child: Text("Submit"),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text("Cancel"),
              ),
            ],
          );
        },
      );
    },
  );
}

// Priority tile widget (unchanged)
Widget _priorityTile(Color color, String label, String selectedPriority,
    Function(String) onTap) {
  return GestureDetector(
    onTap: () {
      onTap(label); // Call the callback with the selected priority
    },
    child: Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 6,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: selectedPriority == label
                ? Icon(Icons.check, color: Colors.white) // Show checkmark
                : Container(),
          ),
        ),
        SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    ),
  );
}

// Shop tile widget with icons
Widget _shopTile(String iconPath, String shopName, String selectedShop,
    Function(String) onTap) {
  return GestureDetector(
    onTap: () {
      onTap(shopName); // Call the callback with the selected shop
    },
    child: Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selectedShop == shopName ? Colors.purple : Colors.transparent,
          width: 3,
        ),
      ),
      child: CircleAvatar(
        backgroundColor: Colors.transparent,
        radius: 30,
        child: Image.asset(
          iconPath,
          fit: BoxFit.contain,
        ),
      ),
    ),
  );
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
  void _storeMessageToFirestore() async {
  User? user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("You need to be logged in to add messages.")),
    );
    return;
  }

  if (_controller.text.isNotEmpty && _selectedPriority.isNotEmpty && _selectedShop.isNotEmpty) {
    try {
      await _firestore.collection('orders').add({
        'message': _controller.text,
        'priority': _selectedPriority,
        'shopId': _selectedShop,  // Ensure the field is named correctly and is being stored
        'timestamp': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'completed': false,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Message added to orders"),
          duration: Duration(seconds: 1),
        ),
      );

      _controller.clear();
      setState(() {
        _selectedPriority = '';
        _selectedShop = '';  // Clear the shop selection
      });
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



  // Display orders in a wrapping list
  void _editOrder(DocumentSnapshot order) {
  TextEditingController _editController = TextEditingController(text: order['message']);
  String selectedPriority = order['priority'];
  String selectedShop = order['shopId']; // Get existing shop selection

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text("Edit Order"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _editController,
                  decoration: InputDecoration(labelText: "Order Message"),
                ),
                SizedBox(height: 10),

                // Priority Selection
                DropdownButtonFormField<String>(
                  value: selectedPriority,
                  onChanged: (newValue) {
                    setState(() {
                      selectedPriority = newValue!;
                    });
                  },
                  items: ['High', 'Moderate', 'Low']
                      .map((priority) => DropdownMenuItem(
                            value: priority,
                            child: Text(priority),
                          ))
                      .toList(),
                  decoration: InputDecoration(labelText: "Priority"),
                ),
                SizedBox(height: 10),

                // Shop Selection (Now Updates Correctly)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _shopTile("assets/shop1.png", "Shop 1", selectedShop, (shop) {
                      setState(() {
                        selectedShop = shop;
                      });
                    }),
                    SizedBox(width: 20),
                    _shopTile("assets/shop2.png", "Shop 2", selectedShop, (shop) {
                      setState(() {
                        selectedShop = shop;
                      });
                    }),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _firestore.collection('orders').doc(order.id).update({
                    'message': _editController.text,
                    'priority': selectedPriority,
                    'shopId': selectedShop, // Now properly updates
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Order updated successfully")),
                  );
                },
                child: Text("Submit"),
              ),
            ],
          );
        },
      );
    },
  );
}



// 🟢 Updated _buildOrdersList with Edit Button
Widget _buildOrdersList() {
  return StreamBuilder<QuerySnapshot>(
    stream: _firestore
        .collection('orders')
        .orderBy('timestamp', descending: false)
        .limit(20)
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

      return SingleChildScrollView(
        child: Wrap(
          spacing: 15,
          runSpacing: 15,
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

            return Stack(
              children: [
                // Order Container
                Container(
                  constraints: BoxConstraints(maxWidth: 250),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),

                    // 🔥 Even Thicker Border for Maximum Visibility
                    border: Border.all(color: borderColor, width: 6), 

                    // 🔥 More Intense Glow Effect
                    boxShadow: [
                      BoxShadow(
                        color: borderColor.withOpacity(0.9), // Stronger color impact
                        blurRadius: 40, // Increased blur for a bolder glow
                        spreadRadius: 8, // Expands the glow effect further
                        offset: Offset(0, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Order Row with Checkbox and Message
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: isCompleted,
                            onChanged: (newValue) {
                              _updateOrderCompletion(order.id, newValue!);
                            },
                            activeColor: borderColor,
                          ),
                          Expanded(
                            child: Text(
                              message,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isCompleted ? Colors.grey : Colors.black87,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                              ),
                              softWrap: true,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 5),
                      // Timestamp
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          formattedTime,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Delete & Edit Buttons
                Positioned(
                  top: 0,
                  right: 0,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          _editOrder(order); // Open edit dialog
                        },
                        icon: Icon(Icons.edit),
                        color: const Color.fromARGB(255, 0, 0, 0),
                      ),
                      IconButton(
                        onPressed: () {
                          _deleteOrder(order.id);
                        },
                        icon: Icon(Icons.close),
                        color: Colors.redAccent,
                      ),
                    ],
                  ),
                ),

                // Shop Icon at Bottom Left
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: CircleAvatar(
                    backgroundColor: Colors.transparent,
                    radius: 20,
                    child: Image.asset(
                      shopIconPath,
                      fit: BoxFit.contain,
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



  // Method to delete the order from Firestore
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

  // Method to delete all orders
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

  // Method to log out the user
  void _logOut() async {
  await FirebaseAuth.instance.signOut();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text("Logged out successfully"),
      duration: Duration(seconds: 1),
    ),
  );

  // Navigate to SignPage after logout
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (context) => SignPage()),
    (route) => false, // Remove all previous routes from the stack
  );
}




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(80),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.purple,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TaskRunner V2',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _deleteAllOrders,
                    icon: Icon(Icons.delete_forever),
                    color: Colors.white,
                    iconSize: 28,
                  ),
                  SizedBox(width: 10),
                  IconButton(
                    onPressed: _logOut,
                    icon: Icon(Icons.logout),
                    color: Colors.white,
                    iconSize: 28,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 16),
            Expanded(child: _buildOrdersList()), // Ensures proper scrolling
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _controller,
                        onChanged: (text) {
                          setState(() {
                            _typedMessage = text;
                          });
                        },
                        onSubmitted: (value) {
                          if (_typedMessage.isNotEmpty) {
                            _showPriorityDialog();
                          }
                        },
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.all(16),
                          hintText: "Enter your order here...",
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.purple,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: _showPriorityDialog,
                      icon: Text(
                        '+',
                        style: TextStyle(
                          fontSize: 28,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
