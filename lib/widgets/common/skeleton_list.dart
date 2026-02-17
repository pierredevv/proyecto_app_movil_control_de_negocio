import 'package:flutter/material.dart';
import 'skeleton_list_item.dart';

class SkeletonList extends StatelessWidget {
  final int itemCount;
  final bool hasImage;
  final EdgeInsetsGeometry padding;

  const SkeletonList({
    super.key,
    this.itemCount = 6,
    this.hasImage = true,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => SkeletonListItem(hasImage: hasImage),
    );
  }
}
