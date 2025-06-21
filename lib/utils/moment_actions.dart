import 'package:flutter/material.dart';

enum MomentAction {
  ritual,
  save,
  remove,
  share,
  cancel,
}

class MomentActionSpec {
  final MomentAction action;
  final IconData icon;
  final String label;

  const MomentActionSpec({
    required this.action,
    required this.icon,
    required this.label,
  });
}

/// Canonical action set used everywhere (dial, grid, future surfaces)
const List<MomentActionSpec> kMomentActions = [
  MomentActionSpec(
    action: MomentAction.ritual,
    icon: Icons.auto_awesome,
    label: 'RITUAL',
  ),
  MomentActionSpec(
    action: MomentAction.save,
    icon: Icons.bookmark_add_rounded, // Premium save icon
    label: 'SAVE',
  ),
  MomentActionSpec(
    action: MomentAction.share,
    icon: Icons.ios_share_rounded,
    label: 'SHARE',
  ),
  MomentActionSpec(
    action: MomentAction.cancel,
    icon: Icons.close_rounded,
    label: 'CANCEL',
  ),
];
