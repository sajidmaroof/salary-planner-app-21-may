import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/app_auth_notifier.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../data/models/currency.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(userSettingsProvider);
    final currentCurrencyCode = ref.watch(currencyCodeProvider);
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? 'User';
    final email = user?.email ?? '';
    final initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('SETTINGS'),
        elevation: 0,
        backgroundColor: AppColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          // ── Profile Card ──────────────────────────────────────────
          GestureDetector(
            onTap: () => _showProfileSheet(context, displayName, email, initials, settings),
            child: Container(
              margin: const EdgeInsets.only(bottom: 28),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.7), size: 24),
                ],
              ),
            ),
          ),

          // ── Budget Settings ───────────────────────────────────────
          _SectionLabel(label: 'BUDGET SETTINGS'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.tune_rounded,
                iconColor: AppColors.primary,
                title: 'Edit Budget Setup',
                subtitle: 'Change salary, payday, or expenses',
                onTap: () => context.push('/setup?edit=true'),
              ),
              if (settings != null) ...[
                _Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.payments_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Currency',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      DropdownButton<String>(
                        value: currentCurrencyCode,
                        underline: const SizedBox(),
                        dropdownColor: AppColors.surface,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        items: AppCurrency.supportedCurrencies.map((c) {
                          return DropdownMenuItem(
                            value: c.code,
                            child: Text(c.code),
                          );
                        }).toList(),
                        onChanged: (newCode) {
                          if (newCode != null) {
                            settings.currencyCode = newCode;
                            settings.save();
                            // Update the dedicated currency provider (String value comparison
                            // guarantees Riverpod fires notifications even though the
                            // UserSettings object reference hasn't changed).
                            ref.read(currencyCodeProvider.notifier).state = newCode;
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // ── Account Settings ──────────────────────────────────────
          _SectionLabel(label: 'ACCOUNT'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.lock_outline_rounded,
                iconColor: const Color(0xFF4F46E5),
                title: 'Change Password',
                subtitle: 'Update your account password',
                onTap: () => _showChangePasswordDialog(context),
              ),
              _Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.notifications_outlined, color: Color(0xFF16A34A), size: 20),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notifications',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Daily spending reminders',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _notificationsEnabled,
                      onChanged: (val) => setState(() => _notificationsEnabled = val),
                      activeColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── About ─────────────────────────────────────────────────
          _SectionLabel(label: 'ABOUT'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.star_outline_rounded,
                iconColor: const Color(0xFFD97706),
                title: 'Rate the App',
                subtitle: 'Share your feedback on the store',
                onTap: () {},
              ),
              _Divider(),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                iconColor: AppColors.textSecondary,
                title: 'Privacy Policy',
                subtitle: 'Read our privacy practices',
                onTap: () {},
              ),
              _Divider(),
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                iconColor: AppColors.textSecondary,
                title: 'App Version',
                subtitle: 'v1.0.0',
                trailing: const SizedBox.shrink(),
                onTap: null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showProfileSheet(BuildContext context, String displayName, String email, String initials, dynamic settings) {
    final user = FirebaseAuth.instance.currentUser;
    final provider = user?.providerData.isNotEmpty == true
        ? user!.providerData.first.providerId
        : 'password';
    final providerLabel = provider == 'google.com' ? 'Google' : 'Email & Password';
    final providerIcon = provider == 'google.com' ? Icons.g_mobiledata_rounded : Icons.email_rounded;
    final createdAt = user?.metadata.creationTime;
    final isEmailProvider = provider != 'google.com';

    String currentName = displayName;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) => Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 28),

                // Avatar + name
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 88, height: 88,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                        ),
                        child: Center(child: Text(
                          currentName.isNotEmpty ? currentName[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900),
                        )),
                      ),
                      const SizedBox(height: 16),
                      Text(currentName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Text(email, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Account info
                const Text('ACCOUNT INFO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 1.4)),
                const SizedBox(height: 12),

                // Editable: Full Name
                _ProfileInfoTile(
                  icon: Icons.person_rounded,
                  iconColor: AppColors.primary,
                  label: 'Full Name',
                  value: currentName,
                  onEdit: () async {
                    final ctrl = TextEditingController(text: currentName);
                    final saved = await showDialog<String>(
                      context: ctx,
                      builder: (dCtx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text('Edit Full Name', style: TextStyle(fontWeight: FontWeight.w800)),
                        content: TextField(
                          controller: ctrl,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: const Icon(Icons.person_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            onPressed: () => Navigator.pop(dCtx, ctrl.text.trim()),
                            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    );
                    if (saved != null && saved.isNotEmpty) {
                      await FirebaseAuth.instance.currentUser?.updateDisplayName(saved);
                      setSheetState(() => currentName = saved);
                      setState(() {});
                      if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Name updated!'), backgroundColor: AppColors.success, duration: Duration(seconds: 2)),
                      );
                    }
                  },
                ),

                // Read-only: Email
                _ProfileInfoTile(
                  icon: Icons.email_rounded,
                  iconColor: const Color(0xFF3B82F6),
                  label: 'Email',
                  value: email,
                ),

                // Read-only: Sign-in method
                _ProfileInfoTile(
                  icon: providerIcon,
                  iconColor: const Color(0xFF10B981),
                  label: 'Sign-in Method',
                  value: providerLabel,
                ),

                // Read-only: Member since
                if (createdAt != null)
                  _ProfileInfoTile(
                    icon: Icons.calendar_today_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    label: 'Member Since',
                    value: '${createdAt.day} ${_monthName(createdAt.month)} ${createdAt.year}',
                  ),

                const SizedBox(height: 28),

                // Change Password (only for email/password accounts)
                if (isEmailProvider) ...[
                  const Text('SECURITY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 1.4)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _showChangePasswordDialog(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.1), borderRadius: BorderRadius.circular(11)),
                            child: const Icon(Icons.lock_outline_rounded, color: Color(0xFF4F46E5), size: 18),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Change Password', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                Text('Update your account password', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'Your data is saved to the cloud and will be restored when you sign back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      ref.read(userSettingsProvider.notifier).state = null;
      await appAuthNotifier.signOut();
    }
  }

  Future<void> _confirmClearData(BuildContext context) async {
    // Capture before any await
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete All Data?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'This will permanently delete all your recorded expenses and budget setup. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Show loading indicator using pre-captured navigator
      navigator.push(
        PageRouteBuilder(
          opaque: false,
          barrierDismissible: false,
          barrierColor: Colors.black26,
          pageBuilder: (_, __, ___) =>
              const Center(child: CircularProgressIndicator()),
        ),
      );

      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;

        if (uid != null) {
          final db = FirebaseFirestore.instance;
          final expensesSnapshot = await db
              .collection('users')
              .doc(uid)
              .collection('expenses')
              .get();
          for (final doc in expensesSnapshot.docs) {
            await doc.reference.delete();
          }
          await db.collection('users').doc(uid).delete();
        }

        await ref.read(userSettingsBoxProvider).clear();
        await ref.read(expensesBoxProvider).clear();
        ref.read(userSettingsProvider.notifier).state = null;
        ref.invalidate(expensesProvider);
        ref.invalidate(todaysExpensesProvider);
        ref.invalidate(dailyStatsProvider);

        // Resets setupComplete → router redirects to /setup automatically
        appAuthNotifier.markSetupIncomplete();

        navigator.pop(); // close loading
      } catch (e) {
        navigator.pop(); // close loading
        messenger.showSnackBar(
          SnackBar(content: Text('Error clearing data: ${e.toString()}')),
        );
      }
    }
  }

  void _showChangePasswordDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'New Password',
            prefixIcon: Icon(Icons.lock_outline_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final pwd = controller.text.trim();
              if (pwd.length < 6) return;
              try {
                await FirebaseAuth.instance.currentUser?.updatePassword(pwd);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password updated successfully')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 70,
      endIndent: 16,
      color: AppColors.border,
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final VoidCallback? onEdit;

  const _ProfileInfoTile({required this.icon, required this.iconColor, required this.label, required this.value, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.primary),
              onPressed: onEdit,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }
}
