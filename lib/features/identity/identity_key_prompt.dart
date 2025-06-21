// import 'package:flutter/material.dart';

// Future<String?> promptForIdentityKey(BuildContext context) async {
//   final controller = TextEditingController();

//   return showDialog<String>(
//     context: context,
//     barrierDismissible: false,
//     builder: (_) {
//       return AlertDialog(
//         backgroundColor: Colors.black,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(20),
//         ),
//         title: const Text(
//           'Confirm your key',
//           style: TextStyle(color: Colors.white),
//         ),
//         content: TextField(
//           controller: controller,
//           obscureText: true,
//           style: const TextStyle(color: Colors.white),
//           decoration: const InputDecoration(
//             hintText: 'Enter your Ataraxia key',
//             hintStyle: TextStyle(color: Colors.white38),
//             enabledBorder: UnderlineInputBorder(
//               borderSide: BorderSide(color: Colors.white24),
//             ),
//             focusedBorder: UnderlineInputBorder(
//               borderSide: BorderSide(color: Colors.white),
//             ),
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text(
//               'Cancel',
//               style: TextStyle(color: Colors.white54),
//             ),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               final value = controller.text.trim();
//               if (value.isEmpty) return;
//               Navigator.pop(context, value);
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.white,
//               foregroundColor: Colors.black,
//             ),
//             child: const Text('Continue'),
//           ),
//         ],
//       );
//     },
//   );
// }
