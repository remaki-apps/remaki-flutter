import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_expandable_dropdown.dart';
import '../widgets/fancy_toast.dart';

class AddRoomScreen extends StatefulWidget {
  const AddRoomScreen({super.key});

  @override
  State<AddRoomScreen> createState() => _AddRoomScreenState();
}

class _AddRoomScreenState extends State<AddRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomNumberController = TextEditingController();
  String _selectedFloor = 'Ground Floor';
  int _capacity = 2;
  final List<TextEditingController> _bedNameControllers = [];
  final List<bool> _isPrefilled = [];

  final List<String> _floorOptions = [
    'Ground Floor',
    '1st Floor',
    '2nd Floor',
    '3rd Floor',
    '4th Floor',
  ];

  @override
  void initState() {
    super.initState();
    _updateBedControllers();
  }

  void _updateBedControllers() {
    while (_bedNameControllers.length < _capacity) {
      final index = _bedNameControllers.length;
      _bedNameControllers.add(TextEditingController(text: 'Bed ${index + 1}'));
      _isPrefilled.add(true);
    }
    while (_bedNameControllers.length > _capacity) {
      _bedNameControllers.removeLast();
      if (_isPrefilled.isNotEmpty) {
        _isPrefilled.removeLast();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                          boxShadow: const [
                            BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
                          ],
                        ),
                        child: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Add Room',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Enter room details and bed information',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Card 1: Floor
                CustomExpandableDropdown<String>(
                  label: 'Floor *',
                  value: _selectedFloor,
                  hintText: 'Select Floor',
                  icon: Icons.domain_outlined,
                  iconColor: AppTheme.primaryColor,
                  iconBgColor: const Color(0xFFEEF2FF),
                  items: _floorOptions.map((f) => DropdownOption(value: f, label: f)).toList(),
                  onChanged: (val) {
                    setState(() => _selectedFloor = val);
                  },
                ),
                const SizedBox(height: 12),

                // Card 2: Room Number or Name
                _buildCardWrapper(
                  icon: Icons.door_sliding_outlined,
                  label: 'Room Number or Name',
                  isRequired: true,
                  child: TextFormField(
                    controller: _roomNumberController,
                    decoration: _inputDecoration(hintText: 'Enter room number or name'),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Please enter room number or name' : null,
                  ),
                ),
                const SizedBox(height: 12),

                // Bed Names Section (Expanded, only bed list scrolls)
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Bed Names',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Enter names for each bed in this room',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _capacity++;
                                  _updateBedControllers();
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFC7D2FE)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.add_rounded, color: AppTheme.primaryColor, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'Add Bed',
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            children: List.generate(_capacity, (index) {
                              final bedRow = Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEEF2FF),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildLabelText('Bed ${index + 1} Name', isRequired: true),
                                          const SizedBox(height: 6),
                                          TextFormField(
                                            controller: _bedNameControllers[index],
                                            onTap: () {
                                              if (index < _isPrefilled.length && _isPrefilled[index]) {
                                                _bedNameControllers[index].clear();
                                                _isPrefilled[index] = false;
                                              }
                                            },
                                            onChanged: (val) {
                                              if (index < _isPrefilled.length) {
                                                _isPrefilled[index] = false;
                                              }
                                            },
                                            decoration: _inputDecoration(
                                              suffixIcon: const Icon(Icons.bed_outlined, color: Color(0xFF94A3B8), size: 20),
                                            ),
                                            validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              if (_capacity <= 1) return bedRow;

                              return Dismissible(
                                key: ObjectKey(_bedNameControllers[index]),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 16),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                      SizedBox(width: 4),
                                      Icon(Icons.delete_outline, color: Colors.white, size: 20),
                                    ],
                                  ),
                                ),
                                onDismissed: (direction) {
                                  setState(() {
                                    _bedNameControllers.removeAt(index);
                                    if (index < _isPrefilled.length) {
                                      _isPrefilled.removeAt(index);
                                    }
                                    _capacity--;
                                  });
                                },
                                child: bedRow,
                              );
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ),
                const SizedBox(height: 16),

                // Submit Button (Static at bottom)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _submitForm,
                    icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                    label: const Text(
                      'Add Room',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      shadowColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardWrapper({
    required IconData icon,
    required String label,
    required bool isRequired,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabelText(label, isRequired: isRequired),
                const SizedBox(height: 6),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelText(String label, {bool isRequired = false}) {
    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF475569),
          fontSize: 13,
        ),
        children: isRequired
            ? const [
                TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ]
            : [],
      ),
    );
  }

  InputDecoration _inputDecoration({String? hintText, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final provider = Provider.of<AppProvider>(context, listen: false);

      final newRoom = Room(
        id: 'r_${DateTime.now().millisecondsSinceEpoch}',
        number: _roomNumberController.text.trim(),
        floor: _selectedFloor,
        capacity: _capacity,
        beds: List.generate(_capacity, (i) => Bed(
          id: 'b_${DateTime.now().millisecondsSinceEpoch}_$i',
          name: _bedNameControllers[i].text.trim(),
        )),
      );

      final roomNum = _roomNumberController.text.trim();
      final flr = _selectedFloor;

      provider.addRoom(newRoom);
      context.pop();
      FancyToast.showSuccess(
        context,
        'Room Added Successfully!',
        message: 'Room $roomNum has been added to $flr.',
      );
    }
  }
}

