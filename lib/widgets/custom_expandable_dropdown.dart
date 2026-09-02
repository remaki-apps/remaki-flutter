import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DropdownOption<T> {
  final T value;
  final String label;
  DropdownOption({required this.value, required this.label});
}

class CustomExpandableDropdown<T> extends StatefulWidget {
  final String label;
  final T? value;
  final String hintText;
  final IconData icon;
  final Color? iconColor;
  final Color? iconBgColor;
  final List<DropdownOption<T>> items;
  final ValueChanged<T> onChanged;

  const CustomExpandableDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.hintText,
    required this.icon,
    this.iconColor,
    this.iconBgColor,
    required this.items,
    required this.onChanged,
  });

  @override
  State<CustomExpandableDropdown<T>> createState() => _CustomExpandableDropdownState<T>();
}

class _CustomExpandableDropdownState<T> extends State<CustomExpandableDropdown<T>> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final selectedOption = widget.items.cast<DropdownOption<T>?>().firstWhere(
          (item) => item?.value == widget.value,
          orElse: () => null,
        );

    final itemCount = widget.items.length;
    const itemHeight = 44.0;
    const maxVisibleItems = 4;
    final listHeight = (itemCount > maxVisibleItems ? maxVisibleItems : itemCount) * itemHeight;

    final color = widget.iconColor ?? AppTheme.primaryColor;
    final bgColor = widget.iconBgColor ?? const Color(0xFFEEF2FF);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isExpanded ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
            width: _isExpanded ? 1.5 : 1.0,
          ),
          boxShadow: _isExpanded
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Bar (Click to Expand / Collapse container)
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(widget.icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.label,
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            selectedOption?.label ?? widget.hintText,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: selectedOption != null ? FontWeight.bold : FontWeight.normal,
                              color: selectedOption != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ),

            // Expanding Dropdown Container (Inline List displaying max 4 items, scrollable if > 4)
            if (_isExpanded) ...[
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              SizedBox(
                height: listHeight,
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: itemCount > maxVisibleItems ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  itemCount: widget.items.length,
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    final isSelected = item.value == widget.value;

                    return InkWell(
                      onTap: () {
                        setState(() => _isExpanded = false);
                        widget.onChanged(item.value);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        color: isSelected ? const Color(0xFFEEF2FF) : Colors.transparent,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? AppTheme.primaryColor : const Color(0xFF334155),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_rounded, color: AppTheme.primaryColor, size: 18),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
