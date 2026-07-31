import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileHeader extends StatelessWidget {
  final String rolLabel;

  const ProfileHeader({super.key, this.rolLabel = "Cliente"});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 30),
      decoration: const BoxDecoration(
        color: Color(0xFF27272A),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(25),
          bottomRight: Radius.circular(25),
        ),
      ),
      child: Column(
        children: [

          const CircleAvatar(
            radius: 42,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.person,
              size: 45,
              color: Color(0xFF27272A),
            ),
          ),

          const SizedBox(height: 15),

          FutureBuilder<DocumentSnapshot>(
            future: user == null
                ? null
                : FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .get(),
            builder: (context, snapshot) {
              String nombre = "Usuario";

              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                if ((data['nombre'] ?? '').toString().isNotEmpty) {
                  nombre = data['nombre'];
                }
              }

              return Text(
                nombre,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),

          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              rolLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}