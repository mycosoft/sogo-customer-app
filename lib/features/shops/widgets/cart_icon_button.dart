import 'package:flutter/material.dart';
import '../../../core/app_services.dart';
import '../screens/cart_screen.dart';

/// Cart icon with item-count badge. Pushes the cart screen and refreshes
/// the count on return. Drop into any AppBar actions.
class CartIconButton extends StatefulWidget {
  const CartIconButton({super.key, this.color});

  final Color? color;

  @override
  State<CartIconButton> createState() => _CartIconButtonState();
}

class _CartIconButtonState extends State<CartIconButton> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await shopApi.cart();
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final items = (data['items'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _count = items.fold<int>(
            0,
            (sum, it) =>
                sum + (((it as Map)['quantity'] as num?)?.toInt() ?? 0));
      });
    } catch (_) {}
  }

  Future<void> _open() async {
    final route = MaterialPageRoute(builder: (_) => const CartScreen());
    await Navigator.of(context).push(route);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      IconButton(
        onPressed: _open,
        icon: Icon(Icons.shopping_cart_outlined, size: 24, color: widget.color),
      ),
      if (_count > 0)
        Positioned(
          right: 6,
          top: 6,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration:
                const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            child: Text('$_count',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800)),
          ),
        ),
    ]);
  }
}
