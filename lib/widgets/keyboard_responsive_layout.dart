import 'package:flutter/material.dart';

/// Dismisses the keyboard when the user taps outside any active input field.
///
/// Wraps the child in a [GestureDetector] with [HitTestBehavior.translucent]
/// so it doesn't block buttons, sliders, or other interactive elements.
class KeyboardDismissOnTap extends StatelessWidget {
  final Widget child;

  const KeyboardDismissOnTap({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        final currentFocus = FocusManager.instance.primaryFocus;
        if (currentFocus != null && currentFocus.hasFocus) {
          currentFocus.unfocus();
        }
      },
      child: child,
    );
  }
}

/// Automatically scrolls the currently focused input field into view
/// whenever the keyboard opens or when focus changes between inputs.
class KeyboardAutoScroll extends StatefulWidget {
  final Widget child;
  final ScrollController? controller;
  final double extraBottomPadding;

  const KeyboardAutoScroll({
    super.key,
    required this.child,
    this.controller,
    this.extraBottomPadding = 64.0,
  });

  @override
  State<KeyboardAutoScroll> createState() => _KeyboardAutoScrollState();
}

class _KeyboardAutoScrollState extends State<KeyboardAutoScroll>
    with WidgetsBindingObserver {
  double _lastBottomInset = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FocusManager.instance.removeListener(_onFocusChange);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Schedule check after the frame layout to obtain the updated keyboard height
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
      if (bottomInset > 0 && bottomInset != _lastBottomInset) {
        _lastBottomInset = bottomInset;
        _scrollToFocusedField();
      } else if (bottomInset == 0) {
        _lastBottomInset = 0.0;
      }
    });
  }

  void _onFocusChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToFocusedField();
    });
  }

  void _scrollToFocusedField() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    final focusContext = primaryFocus?.context;

    if (focusContext == null || !focusContext.mounted) return;

    // Verify the focused widget is a descendant of this auto-scroll container
    final renderObject = focusContext.findRenderObject();
    if (renderObject == null || !renderObject.attached) return;

    final myBox = context.findRenderObject();
    if (myBox == null || !myBox.attached) return;

    // Only scroll if the focused widget is inside our subtree
    bool isDescendant = false;
    focusContext.visitAncestorElements((element) {
      if (element == context) {
        isDescendant = true;
        return false;
      }
      return true;
    });

    if (!isDescendant) return;

    // Use Scrollable.ensureVisible with alignment and bottom margin
    try {
      Scrollable.ensureVisible(
        focusContext,
        alignment: 0.5,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } catch (_) {
      // Fallback if Scrollable is not immediately ready
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// A preconfigured, keyboard-aware scrollable container for forms and screens.
///
/// Features:
/// 1. Auto-dismiss on drag (`keyboardDismissBehavior: onDrag`).
/// 2. Auto-dismiss on tap outside interactive fields.
/// 3. Auto-scrolls the active focused field into view with comfortable bottom clearance.
/// 4. Accommodates keyboard view insets and safe areas smoothly.
class KeyboardAwareScrollView extends StatelessWidget {
  final Widget child;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics physics;
  final bool enableAutoScroll;
  final double extraBottomPadding;

  const KeyboardAwareScrollView({
    super.key,
    required this.child,
    this.controller,
    this.padding,
    this.physics = const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
    this.enableAutoScroll = true,
    this.extraBottomPadding = 32.0,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final effectivePadding = (padding ?? EdgeInsets.zero).add(
      EdgeInsets.only(bottom: bottomInset > 0 ? extraBottomPadding : 0),
    );

    Widget scrollView = SingleChildScrollView(
      controller: controller,
      physics: physics,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: effectivePadding,
      child: child,
    );

    if (enableAutoScroll) {
      scrollView = KeyboardAutoScroll(
        controller: controller,
        child: scrollView,
      );
    }

    return KeyboardDismissOnTap(
      child: scrollView,
    );
  }
}

/// Wrapper for dialogs containing input fields, ensuring the dialog never
/// overflows when the keyboard opens and automatically scrolls focused fields.
class KeyboardAwareDialog extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets? insetPadding;
  final ShapeBorder? shape;
  final Color? backgroundColor;

  const KeyboardAwareDialog({
    super.key,
    required this.child,
    this.maxWidth = 480,
    this.insetPadding,
    this.shape,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final totalHeight = mediaQuery.size.height;
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final availableHeight = totalHeight - keyboardHeight - (keyboardHeight > 0 ? 32 : 64);

    return Dialog(
      shape: shape ?? RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: backgroundColor ?? Colors.white,
      clipBehavior: Clip.antiAlias,
      insetPadding: insetPadding ??
          EdgeInsets.symmetric(
            horizontal: 18,
            vertical: keyboardHeight > 0 ? 12 : 24,
          ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: availableHeight.clamp(200.0, totalHeight * 0.9),
        ),
        child: KeyboardDismissOnTap(
          child: KeyboardAutoScroll(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Standardized helper for modal bottom sheets containing forms or inputs.
/// Ensures the sheet fits above the keyboard without clipping,
/// supports drag dismissal, and automatically keeps the focused input visible.
class KeyboardAwareBottomSheet extends StatelessWidget {
  final Widget child;
  final double maxScreenRatio;
  final EdgeInsetsGeometry? padding;
  final BoxDecoration? decoration;

  const KeyboardAwareBottomSheet({
    super.key,
    required this.child,
    this.maxScreenRatio = 0.88,
    this.padding,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final maxHeight = mediaQuery.size.height * maxScreenRatio;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        padding: padding ?? const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: decoration ??
            const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 28,
                  offset: Offset(0, -6),
                ),
              ],
            ),
        child: KeyboardDismissOnTap(
          child: KeyboardAutoScroll(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
