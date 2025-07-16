import 'package:flutter/material.dart';

class ShimmerSaleCard extends StatefulWidget {
  const ShimmerSaleCard({Key? key}) : super(key: key);

  @override
  State<ShimmerSaleCard> createState() => _ShimmerSaleCardState();
}

class _ShimmerSaleCardState extends State<ShimmerSaleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: Colors.grey.shade300,
      end: Colors.grey.shade100,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: 120,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
            // boxShadow: [
            //   BoxShadow(
            //     color: Colors.black.withOpacity(0.05),
            //     blurRadius: 4,
            //     offset: const Offset(0, 2),
            //   ),
            // ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 15,
                      decoration: BoxDecoration(
                        color: _colorAnimation.value,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                  Container(
                    width: 60,
                    height: 15,
                    decoration: BoxDecoration(
                      color: _colorAnimation.value,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 12,
                width: 200,
                decoration: BoxDecoration(
                  color: _colorAnimation.value,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 12,
                width: 150,
                decoration: BoxDecoration(
                  color: _colorAnimation.value,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    height: 12,
                    width: 100,
                    decoration: BoxDecoration(
                      color: _colorAnimation.value,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Container(
                    height: 12,
                    width: 80,
                    decoration: BoxDecoration(
                      color: _colorAnimation.value,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
