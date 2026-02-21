import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/firestore_service.dart';

class AddProductScreen extends StatefulWidget {
  final String barcode;
  const AddProductScreen({super.key, required this.barcode});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final priceController = TextEditingController();
  final gstController = TextEditingController();
  final weightController = TextEditingController(); // ⚖️ Weight Input
  final stockController = TextEditingController(text: '100');

  File? _selectedImage;
  bool isLoading = false;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _selectedImage = File(image.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Global Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // IMAGE
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  width: 150,
                  decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      image: _selectedImage != null
                          ? DecorationImage(
                              image: FileImage(_selectedImage!),
                              fit: BoxFit.cover)
                          : null),
                  child: _selectedImage == null
                      ? const Icon(Icons.add_a_photo, size: 40)
                      : null,
                ),
              ),
              const SizedBox(height: 20),

              // BARCODE DISPLAY
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.qr_code, color: Colors.blue),
                    const SizedBox(width: 10),
                    Text("Barcode: ${widget.barcode}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // NAME
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                    labelText: 'Product Name', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 15),

              // PRICE & GST
              Row(
                children: [
                  Expanded(
                      child: TextFormField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'MRP (₹)', border: OutlineInputBorder()),
                  )),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextFormField(
                    controller: gstController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'GST %', border: OutlineInputBorder()),
                  )),
                ],
              ),
              const SizedBox(height: 15),

              // WEIGHT & STOCK
              Row(
                children: [
                  Expanded(
                      // ⚖️ WEIGHT INPUT ADDED
                      child: TextFormField(
                    controller: weightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Weight (grams)',
                        hintText: "e.g. 100",
                        border: OutlineInputBorder()),
                  )),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextFormField(
                    controller: stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Stock Qty', border: OutlineInputBorder()),
                  )),
                ],
              ),
              const SizedBox(height: 30),

              // SAVE BUTTON
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white),
                  onPressed: isLoading ? null : _saveProduct,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("SAVE TO GLOBAL STORE",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (weightController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please enter Weight')));
      return;
    }

    setState(() => isLoading = true);

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await FirestoreService()
            .uploadProductImage(_selectedImage!, widget.barcode);
      }

      await FirestoreService().addProduct(
        barcode: widget.barcode,
        name: nameController.text.trim(),
        price: double.parse(priceController.text),
        gst: double.parse(gstController.text),
        weight: double.parse(weightController.text), // ⚖️ Passing Weight
        stock: int.parse(stockController.text),
        imageUrl: imageUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product Live Globally! 🌍')));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
}
