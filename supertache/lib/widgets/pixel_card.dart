import 'package:flutter/material.dart';
import '../theme/retro_theme.dart';

/// Card avec style pixelisé 8-bits
class PixelCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const PixelCard({
    Key? key,
    required this.child,
    this.color,
    this.padding,
    this.margin,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin ?? const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        border: Border.all(color: Colors.black, width: 3),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}

/// Bouton pixelisé avec effet d'ombre rétro
class PixelButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;

  const PixelButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.icon,
  }) : super(key: key);

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? Colors.black;
    final fgColor = widget.textColor ?? Colors.white;

    return GestureDetector(
      onTapDown: widget.onPressed != null ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: widget.onPressed != null ? (_) {
        setState(() => _isPressed = false);
        widget.onPressed!();
      } : null,
      onTapCancel: widget.onPressed != null ? () => setState(() => _isPressed = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: EdgeInsets.only(
          left: _isPressed ? 4 : 0,
          top: _isPressed ? 4 : 0,
          right: _isPressed ? 0 : 4,
          bottom: _isPressed ? 0 : 4,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: Colors.black, width: 3),
          boxShadow: _isPressed ? null : [
            const BoxShadow(
              color: Colors.black,
              offset: Offset(4, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: fgColor, size: 16),
              const SizedBox(width: 12),
            ],
            Text(
              widget.text,
              style: TextStyle(
                color: fgColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Conteneur avec bordure pixelisée et titre
class PixelSection extends StatelessWidget {
  final String title;
  final Widget child;
  final Color? backgroundColor;

  const PixelSection({
    Key? key,
    required this.title,
    required this.child,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: Colors.black, width: 3),
          ),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white,
            border: Border.all(color: Colors.black, width: 3),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(0),
              bottomRight: Radius.circular(0),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ],
    );
  }
}

/// Badge pixelisé
class PixelBadge extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color textColor;

  const PixelBadge({
    Key? key,
    required this.text,
    this.backgroundColor = Colors.black,
    this.textColor = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 7,
          fontWeight: FontWeight.bold,
          height: 1.5,
        ),
      ),
    );
  }
}

/// Indicateur de progression pixelisé
class PixelProgressBar extends StatelessWidget {
  final double value; // 0.0 à 1.0
  final double height;
  final Color? fillColor;
  final Color? backgroundColor;

  const PixelProgressBar({
    Key? key,
    required this.value,
    this.height = 20,
    this.fillColor,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        border: Border.all(color: Colors.black, width: 3),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              Container(
                width: constraints.maxWidth * value.clamp(0.0, 1.0),
                color: fillColor ?? Colors.black,
              ),
            ],
          );
        },
      ),
    );
  }
}

