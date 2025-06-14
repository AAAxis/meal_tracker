import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

class IngredientsEditScreen extends StatefulWidget {
  final List<String> ingredients;
  final String mealId;
  final String language;
  final Function(List<String>)? onSave;
  const IngredientsEditScreen({
    Key? key,
    required this.mealId,
    required this.ingredients,
    required this.language,
    this.onSave,
  }) : super(key: key);

  @override
  State<IngredientsEditScreen> createState() => _IngredientsEditScreenState();
}

class _IngredientsEditScreenState extends State<IngredientsEditScreen> {
  late List<String> _ingredients;

  @override
  void initState() {
    super.initState();
    _ingredients = List<String>.from(widget.ingredients);
  }

  void _addIngredient() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('ingredients_edit.add_ingredient'.tr()),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(labelText: 'ingredients_edit.ingredient'.tr()),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('common.cancel'.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: Text('ingredients_edit.add'.tr()),
              ),
            ],
          ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() {
        _ingredients.add(result);
      });
    }
  }

  void _editIngredient(int index) async {
    final controller = TextEditingController(text: _ingredients[index]);
    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('ingredients_edit.edit_ingredient'.tr()),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(labelText: 'ingredients_edit.ingredient'.tr()),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('common.cancel'.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: Text('common.save'.tr()),
              ),
            ],
          ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() {
        _ingredients[index] = result;
      });
    }
  }

  void _deleteIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
    });
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && widget.mealId.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('analyzed_meals')
          .doc(widget.mealId)
          .update({'ingredients.${widget.language}': _ingredients});
    }
    if (widget.onSave != null) {
      widget.onSave!(_ingredients);
    }
    Navigator.pop(context, _ingredients);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ingredients_edit.title'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _submit,
        ),
      ),
      body: ListView.builder(
        itemCount: _ingredients.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(_ingredients[index]),
            onTap: () => _editIngredient(index),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteIngredient(index),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addIngredient,
        child: const Icon(Icons.add),
      ),
    );
  }
}
