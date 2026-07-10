// import 'dart:ui';
// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:google_fonts/google_fonts.dart';


// /// GLASS FOLDER CARD

// class GlassFolderCard extends StatelessWidget {
//   final String folderPath;
//   final int documentCount;
//   final VoidCallback? onTap;

//   const GlassFolderCard({
//     super.key,
//     required this.folderPath,
//     this.documentCount = 0,
//     this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final folderName = folderPath.split('/').where((e) => e.isNotEmpty).last;

//     return GestureDetector(
//       onTap: onTap,
//       child: SizedBox(
//         width: 160,
//         height: 200,
//         child: Stack(
//           children: [
//             // Glass folder body
//             Positioned(
//               top: 30,
//               left: 0,
//               right: 0,
//               bottom: 0,
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(20),
//                 child: BackdropFilter(
//                   filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
//                   child: Container(
//                     decoration: BoxDecoration(
//                       gradient: LinearGradient(
//                         begin: Alignment.topLeft,
//                         end: Alignment.bottomRight,
//                         colors: [
//                           Colors.white.withValues(alpha: 0.7),
//                           Colors.white.withValues(alpha: 0.3),
//                         ],
//                       ),
//                       borderRadius: BorderRadius.circular(20),
//                       border: Border.all(
//                         color: Colors.white.withValues(alpha: 0.5),
//                         width: 1.5,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),

//             // Folder tab
//             Positioned(
//               top: 15,
//               left: 15,
//               child: ClipRRect(
//                 borderRadius: const BorderRadius.only(
//                   topLeft: Radius.circular(8),
//                   topRight: Radius.circular(8),
//                 ),
//                 child: BackdropFilter(
//                   filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
//                   child: Container(
//                     width: 50,
//                     height: 25,
//                     decoration: BoxDecoration(
//                       gradient: LinearGradient(
//                         begin: Alignment.topLeft,
//                         end: Alignment.bottomRight,
//                         colors: [
//                           Colors.white.withValues(alpha: 0.6),
//                           Colors.white.withValues(alpha: 0.4),
//                         ],
//                       ),
//                       borderRadius: const BorderRadius.only(
//                         topLeft: Radius.circular(8),
//                         topRight: Radius.circular(8),
//                       ),
//                       border: Border.all(
//                         color: Colors.white.withValues(alpha: 0.4),
//                         width: 1,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),

//             // Document count badge (if > 0)
//             if (documentCount > 0)
//               Positioned(
//                 top: 45,
//                 right: 15,
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 8,
//                     vertical: 4,
//                   ),
//                   decoration: BoxDecoration(
//                     color: Colors.blue.withValues(alpha: 0.8),
//                     borderRadius: BorderRadius.circular(12),
//                     border: Border.all(
//                       color: Colors.white.withValues(alpha: 0.3),
//                       width: 1,
//                     ),
//                   ),
//                   child: Text(
//                     documentCount.toString(),
//                     style: GoogleFonts.instrumentSans(
//                       fontSize: 11.sp,
//                       fontWeight: FontWeight.w600,
//                       color: Colors.white,
//                     ),
//                   ),
//                 ),
//               ),

//             // Folder icon with glass effect
//             Positioned(
//               top: 60,
//               left: 0,
//               right: 0,
//               child: Center(
//                 child: Container(
//                   width: 60,
//                   height: 60,
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     gradient: LinearGradient(
//                       begin: Alignment.topLeft,
//                       end: Alignment.bottomRight,
//                       colors: [
//                         Colors.white.withValues(alpha: 0.4),
//                         Colors.white.withValues(alpha: 0.1),
//                       ],
//                     ),
//                     border: Border.all(
//                       color: Colors.white.withValues(alpha: 0.3),
//                       width: 1.5,
//                     ),
//                   ),
//                   child: Icon(
//                     Icons.folder_rounded,
//                     size: 30,
//                     color: Colors.grey.shade700,
//                   ),
//                 ),
//               ),
//             ),

//             // Decorative accent line
//             Positioned(
//               bottom: 60,
//               left: 20,
//               right: 20,
//               child: Container(
//                 height: 1,
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     colors: [
//                       Colors.transparent,
//                       Colors.white.withValues(alpha: 0.3),
//                       Colors.transparent,
//                     ],
//                   ),
//                 ),
//               ),
//             ),

//             // Folder name and subtitle
//             Positioned(
//               bottom: 20,
//               left: 15,
//               right: 15,
//               child: Column(
//                 children: [
//                   Text(
//                     folderName,
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     textAlign: TextAlign.center,
//                     style: GoogleFonts.instrumentSans(
//                       fontSize: 15.sp,
//                       fontWeight: FontWeight.w600,
//                       color: Colors.grey.shade800,
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     'Documents',
//                     style: GoogleFonts.instrumentSans(
//                       fontSize: 12.sp,
//                       color: Colors.grey.shade600,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


// /// GLASS ADD FOLDER CARD

// class GlassAddFolderCard extends StatelessWidget {
//   final VoidCallback onTap;

//   const GlassAddFolderCard({super.key, required this.onTap});

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: SizedBox(
//         width: 160,
//         height: 200,
//         child: Stack(
//           children: [
//             // Glass body
//             Positioned(
//               top: 30,
//               left: 0,
//               right: 0,
//               bottom: 0,
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(20),
//                 child: BackdropFilter(
//                   filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
//                   child: Container(
//                     decoration: BoxDecoration(
//                       gradient: LinearGradient(
//                         begin: Alignment.topLeft,
//                         end: Alignment.bottomRight,
//                         colors: [
//                           Colors.white.withValues(alpha: 0.5),
//                           Colors.white.withValues(alpha: 0.2),
//                         ],
//                       ),
//                       borderRadius: BorderRadius.circular(20),
//                       border: Border.all(
//                         color: Colors.grey.shade300.withValues(alpha: 0.5),
//                         width: 1.5,
//                       ),
//                     ),
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Container(
//                           width: 50,
//                           height: 50,
//                           decoration: BoxDecoration(
//                             shape: BoxShape.circle,
//                             gradient: LinearGradient(
//                               begin: Alignment.topLeft,
//                               end: Alignment.bottomRight,
//                               colors: [
//                                 Colors.white.withValues(alpha: 0.6),
//                                 Colors.white.withValues(alpha: 0.3),
//                               ],
//                             ),
//                             border: Border.all(
//                               color: Colors.grey.shade400.withValues(alpha: 0.5),
//                               width: 1.5,
//                             ),
//                           ),
//                           child: Icon(
//                             Icons.add,
//                             size: 26,
//                             color: Colors.grey.shade700,
//                           ),
//                         ),
//                         const SizedBox(height: 12),
//                         Text(
//                           'Add Folder',
//                           style: GoogleFonts.instrumentSans(
//                             fontSize: 14.sp,
//                             fontWeight: FontWeight.w500,
//                             color: Colors.grey.shade700,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
