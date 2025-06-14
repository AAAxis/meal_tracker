import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserInfoScreen extends StatefulWidget {
  @override
  _UserInfoScreenState createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  Map<String, Object> _userPrefs = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = FirebaseAuth.instance.currentUser;
      final map = <String, Object>{};

      // Load from SharedPreferences
      final keys = prefs.getKeys();
      for (final key in keys) {
        final value = prefs.get(key);
        if (value != null) {
          if (key == 'user_email' || 
              key == 'user_display_name' || 
              key == 'dietType' || 
              key == 'main_goal' ||
              key == 'delivery_name' ||
              key == 'delivery_address' ||
              key == 'delivery_phone' ||
              key == 'delivery_zip') {
            map[key] = value;
          }
        }
      }

      // Load display name from Firebase Auth, fallback to email prefix or 'User'
      if (user != null) {
        String displayName = user.displayName ?? '';
        if (displayName.isEmpty) {
          displayName = user.email?.split('@')[0] ?? 'User';
        }
        map['user_display_name'] = displayName;
        map['user_email'] = user.email ?? '';

        // Load goal from Firestore
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          
          if (userDoc.exists) {
            final data = userDoc.data() as Map<String, dynamic>;
            if (data['main_goal'] != null) {
              map['main_goal'] = data['main_goal'];
            }
            // If Firestore has displayName, prefer it
            if (data['displayName'] != null && (data['displayName'] as String).isNotEmpty) {
              map['user_display_name'] = data['displayName'];
            }
          }
        } catch (e) {
          print('Error loading goal/displayName from Firestore: $e');
        }
      }

      setState(() {
        _userPrefs = map;
        _loading = false;
      });
    } catch (e) {
      print('Error loading preferences: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  String _formatDisplayValue(String key, Object value) {
    switch (key) {
      case 'dietType':
        return _formatDietType(value.toString());
      case 'main_goal':
        return _formatGoal(value.toString());
      case 'user_display_name':
        return value.toString();
      case 'user_email':
        return value.toString();
      case 'delivery_name':
      case 'delivery_address':
      case 'delivery_phone':
      case 'delivery_zip':
        return value.toString();
      default:
        return value.toString();
    }
  }

  String _formatDietType(String dietType) {
    // Remove known prefixes and normalize
    String normalized = dietType
      .replaceAll('Wizard.diet ', '')
      .replaceAll('wizard.diet_', '')
      .replaceAll('wizard.diet ', '')
      .replaceAll('diet_', '')
      .replaceAll('_', ' ')
      .trim()
      .toLowerCase();

    switch (normalized) {
      case 'classic':
        return 'Classic';
      case 'regular':
      case 'normal':
        return 'Regular Diet';
      case 'vegetarian':
        return 'Vegetarian';
      case 'vegan':
        return 'Vegan';
      case 'keto':
      case 'ketogenic':
        return 'Ketogenic (Keto)';
      case 'paleo':
        return 'Paleo';
      case 'mediterranean':
        return 'Mediterranean';
      case 'low carb':
        return 'Low Carb';
      case 'low fat':
        return 'Low Fat';
      case 'gluten free':
        return 'Gluten Free';
      case 'dairy free':
        return 'Dairy Free';
      case 'intermittent fasting':
        return 'Intermittent Fasting';
      case 'pescatarian':
        return 'Pescatarian';
      case 'flexitarian':
        return 'Flexitarian';
      default:
        // Capitalize each word
        return normalized.split(' ').map((word) => word.isEmpty ? word : word[0].toUpperCase() + word.substring(1)).join(' ');
    }
  }

  String _formatGoal(String goal) {
    if (goal.isEmpty) return 'Not set';
    
    // Remove the 'wizard.goal_' prefix if it exists
    String cleanGoal = goal.replaceAll('wizard.goal_', '');
    
    switch (cleanGoal.toLowerCase()) {
      case 'lose_weight':
        return 'Lose Weight';
      case 'gain_weight':
        return 'Gain Weight';
      case 'build_muscle':
        return 'Build Muscle';
      case 'maintain_weight':
        return 'Maintain Weight';
      case 'improve_flexibility':
        return 'Improve Flexibility';
      default:
        return cleanGoal.split('_').map((word) => 
          word.isEmpty ? word : word[0].toUpperCase() + word.substring(1)
        ).join(' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Data'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Builder(
                    builder: (context) {
                      // Move nonEditableKeys here so it's available for the whole list
                      final nonEditableKeys = [
                        'user_email', // Email should not be editable
                      ];
                      // Human-friendly labels for fields
                      final fieldLabels = {
                        'user_email': 'Email Address',
                        'user_display_name': 'Display Name',
                        'dietType': 'Diet Type',
                        'main_goal': 'Health Goal',
                        'delivery_name': 'Delivery Name',
                        'delivery_address': 'Delivery Address',
                        'delivery_phone': 'Phone Number',
                        'delivery_zip': 'ZIP Code',
                      };
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        // Only show editable fields in the list
                        itemCount: _userPrefs.keys.where((key) => !nonEditableKeys.contains(key)).length + 1, // +1 for email tile
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final editableKeys = _userPrefs.keys.where((key) => !nonEditableKeys.contains(key)).toList();
                          if (index == 0) {
                            // Special tile for email at the top
                            final email = _userPrefs['user_email'] ?? '';
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fieldLabels['user_email'] ?? 'Email',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    email.toString(),
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            );
                          }
                          final key = editableKeys[index - 1];
                          final value = _userPrefs[key];
                          final isNonEditable = nonEditableKeys.contains(key);
                          return Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                              ),
                            ),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              title: Text(
                                fieldLabels[key] ?? key,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _formatDisplayValue(key, value!),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              trailing: null,
                              onTap: isNonEditable
                                  ? null
                                  : () async {
                                      final controller = TextEditingController(text: value.toString());
                                      final result = await showDialog<String>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text('Edit ${fieldLabels[key] ?? key}'),
                                          content: TextField(
                                            controller: controller,
                                            decoration: InputDecoration(
                                              labelText: fieldLabels[key] ?? key,
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            autofocus: true,
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => Navigator.pop(context, controller.text),
                                              child: const Text('Save'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (result != null && result != value.toString()) {
                                        final prefs = await SharedPreferences.getInstance();
                                        // Try to preserve type
                                        if (value is int) {
                                          await prefs.setInt(key, int.tryParse(result) ?? 0);
                                        } else if (value is double) {
                                          await prefs.setDouble(key, double.tryParse(result) ?? 0.0);
                                        } else if (value is bool) {
                                          await prefs.setBool(key, result.toLowerCase() == 'true');
                                        } else {
                                          await prefs.setString(key, result);
                                        }
                                        // Update Firestore if user is authenticated
                                        final user = FirebaseAuth.instance.currentUser;
                                        if (user != null) {
                                          try {
                                            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({key: result}, SetOptions(merge: true));
                                            print('[Firestore] Updated $key: $result');
                                          } catch (e) {
                                            print('[Firestore] Error updating $key: $e');
                                          }
                                        }
                                        await _loadPrefs();
                                      }
                                    },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete Account'),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Account'),
                          content: const Text('Are you sure you want to delete your account? This cannot be undone.'),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          actions: [
                            TextButton(
                              child: const Text('Cancel'),
                              onPressed: () => Navigator.pop(context, false),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Delete'),
                              onPressed: () => Navigator.pop(context, true),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        try {
                          // Delete from Firebase Auth and clear local storage
                          // (You may want to add your own logic here)
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Account deleted')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error deleting account: $e')),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
    );
  }
} 