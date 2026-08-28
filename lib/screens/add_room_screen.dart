import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';

class AddRoomScreen extends StatefulWidget {
  const AddRoomScreen({super.key});

  @override
  State<AddRoomScreen> createState() => _AddRoomScreenState();
}

class _AddRoomScreenState extends State<AddRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomNumberController = TextEditingController();
  final _floorController = TextEditingController();
  int _capacity = 2;
  final List<TextEditingController> _bedNameControllers = [];


  @override
  void initState() {
    super.initState();
    _updateBedControllers();
  }

  void _updateBedControllers() {
    while (_bedNameControllers.length < _capacity) {
      _bedNameControllers.add(TextEditingController(text: 'Bed ${_bedNameControllers.length + 1}'));
    }
    while (_bedNameControllers.length > _capacity) {
      _bedNameControllers.removeLast();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Add Room'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _roomNumberController,
                decoration: const InputDecoration(labelText: 'Room Number *', hintText: 'e.g. 104'),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _floorController,
                decoration: const InputDecoration(labelText: 'Floor *', hintText: 'e.g. 1st Floor, Ground Floor'),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _capacity,
                decoration: const InputDecoration(labelText: 'Room Capacity'),
                items: [1, 2, 3, 4, 5, 6].map((c) => DropdownMenuItem(value: c, child: Text('$c Beds'))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _capacity = val;
                      _updateBedControllers();
                    });
                  }
                },
              ),
              const SizedBox(height: 24),
              const Text('Bed Names', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...List.generate(_capacity, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: TextFormField(
                    controller: _bedNameControllers[index],
                    decoration: InputDecoration(labelText: 'Bed ${index + 1} Name'),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                );
              }),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final provider = Provider.of<AppProvider>(context, listen: false);
                      
                      final newRoom = Room(
                        id: 'r_${DateTime.now().millisecondsSinceEpoch}',
                        number: _roomNumberController.text,
                        floor: _floorController.text,
                        capacity: _capacity,
                        beds: List.generate(_capacity, (i) => Bed(
                          id: 'b_${DateTime.now().millisecondsSinceEpoch}_$i',
                          name: _bedNameControllers[i].text,
                        )),
                      );
                      
                      provider.addRoom(newRoom);
                      context.pop();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room Added Successfully!')));
                    }
                  },
                  child: const Text('Add Room'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
