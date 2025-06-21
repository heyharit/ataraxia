import 'dart:ui';
import 'package:flutter/material.dart';

class VoidConnectionBanner extends StatelessWidget {
  final bool isOffline;

  const VoidConnectionBanner({super.key, required this.isOffline});

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutQuint,
      top: isOffline ? MediaQuery.of(context).padding.top + 16 : -120,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              // decoration: BoxDecoration(
              //   color: Colors.black.withOpacity(0.75),
              //   borderRadius: BorderRadius.circular(24),
              //   border: Border.all(
              //     color: Colors.redAccent.withOpacity(0.25),
              //     width: 1.2,
              //   ),
              //   boxShadow: [
              //     BoxShadow(
              //       color: Colors.redAccent.withOpacity(0.12),
              //       blurRadius: 30,
              //       spreadRadius: 6,
              //     ),
              //   ],
              // ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.redAccent.withOpacity(0.25),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withOpacity(0.15),
                    blurRadius: 35,
                    spreadRadius: 8,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.redAccent.withOpacity(0.35),
                      ),
                    ),
                    child: const Icon(
                      Icons.public_off_rounded,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "SOUL DISCONNECTED",
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Courier',
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Offline is the bliss. Online is the era.",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontFamily: 'Serif',
                            fontStyle: FontStyle.italic,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
