import 'package:flutter/material.dart';
import 'package:tecnigo/theme/app_colors.dart';

class MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  const MenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 5,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [

                Icon(
                  icon,
                  color: color ?? AppColors.text,
                ),

                const SizedBox(width: 18),

                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      color: color ?? AppColors.text,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                Icon(
                  Icons.chevron_right,
                  color: AppColors.subtitle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}