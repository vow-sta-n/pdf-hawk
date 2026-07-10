// import 'package:flutter/material.dart';

// class RecentlyViewedCard extends StatelessWidget {
//   final String title;
//   final String author;
//   final String progressPercent;
//   final String lastPage;
//   final String openCount;
//   const RecentlyViewedCard(
//       {super.key,
//       required this.title,
//       required this.author,
//       required this.progressPercent,
//       required this.lastPage,
//       required this.openCount});

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);

//     return Container(
//       width: 260,
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: theme.colorScheme.surface,
//         borderRadius: BorderRadius.circular(24),
//         boxShadow: const [
//           BoxShadow(
//             // color: Colors.black.withOpacity(0.04),
//             offset: Offset(0, 8),
//             blurRadius: 16,
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           // Text & stats
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   title,
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                   style: theme.textTheme.titleMedium?.copyWith(
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   author,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: theme.textTheme.bodySmall?.copyWith(
//                     color: Colors.grey[600],
//                   ),
//                 ),
//                 const SizedBox(height: 12),
//                 _InfoRow(
//                   icon: Icons.percent_rounded,
//                   label: '$progressPercent% read',
//                 ),
//                 const SizedBox(height: 6),
//                 _InfoRow(
//                   icon: Icons.bookmark_border_rounded,
//                   label: 'Last page $lastPage',
//                 ),
//                 const SizedBox(height: 6),
//                 _InfoRow(
//                   icon: Icons.history_rounded,
//                   label: '$openCount times opened',
//                 ),
//                 const Spacer(),
//                 SizedBox(
//                   height: 36,
//                   child: OutlinedButton(
//                     onPressed: () {
//                       // TODO: open reader at last page
//                     },
//                     style: OutlinedButton.styleFrom(
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(18),
//                       ),
//                     ),
//                     child: const Text('Read now'),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(width: 12),
//           // Thumbnail placeholder
//           Container(
//             width: 90,
//             height: 140,
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(18),
//               color: Colors.grey[200],
//             ),
//             child: const Center(
//               child: Icon(Icons.picture_as_pdf_rounded, size: 32),
//             ),
//             // Later: replace with PDF thumbnail using pdf_render
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _InfoRow extends StatelessWidget {
//   const _InfoRow({required this.icon, required this.label});

//   final IconData icon;
//   final String label;

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         Icon(icon, size: 16, color: Colors.grey[600]),
//         const SizedBox(width: 6),
//         Flexible(
//           child: Text(
//             label,
//             style: Theme.of(
//               context,
//             ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
//           ),
//         ),
//       ],
//     );
//   }
// }
