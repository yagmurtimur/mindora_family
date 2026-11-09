import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class ChildProfileScreen extends StatelessWidget {
  const ChildProfileScreen({super.key});

  Future<Map<String, dynamic>?> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    return doc.data();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Profil')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _loadProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('Profil bilgisi yüklenemedi.'));
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ListTile(
                title: const Text('Ad'),
                subtitle: Text(data['name']?.toString() ?? '-'),
              ),
              ListTile(
                title: const Text('E-posta'),
                subtitle: Text(data['email']?.toString() ?? '-'),
              ),
              ListTile(
                title: const Text('Yaş'),
                subtitle: Text(data['age']?.toString() ?? '-'),
              ),
              ListTile(
                title: const Text('Rol'),
                subtitle: Text(data['role']?.toString() ?? '-'),
              ),
            ],
          );
        },
      ),
    );
  }
}
