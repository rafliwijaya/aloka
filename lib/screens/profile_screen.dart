import 'package:flutter/material.dart';
import '../state/aloka_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/aloka_widgets.dart';

/// Halaman 4: PROFIL
/// Mengatur fullname & username (default: Pengguna / user),
/// manajemen & arsip kategori kustom, penghapusan riwayat lokal,
/// serta informasi singkat aplikasi Aloka dan metode Algoritma Genetika.
class ProfileScreen extends StatefulWidget {
  final AlokaController controller;

  const ProfileScreen({
    super.key,
    required this.controller,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _fullnameCtrl;
  late final TextEditingController _usernameCtrl;

  @override
  void initState() {
    super.initState();
    _fullnameCtrl = TextEditingController(
      text: widget.controller.userProfile.fullname,
    );
    _usernameCtrl = TextEditingController(
      text: widget.controller.userProfile.username,
    );
  }

  @override
  void dispose() {
    _fullnameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile(BuildContext context) async {
    await widget.controller.updateUserProfile(
      fullname: _fullnameCtrl.text,
      username: _usernameCtrl.text,
    );
    _fullnameCtrl.text = widget.controller.userProfile.fullname;
    _usernameCtrl.text = widget.controller.userProfile.username;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profil diperbarui: ${widget.controller.userProfile.fullname} (@${widget.controller.userProfile.username})',
          ),
        ),
      );
    }
  }

  Future<void> _confirmClearAllHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AlokaColors.surfaceWhite,
        title: const Text('Hapus Semua Riwayat?'),
        content: const Text(
          'Semua riwayat optimasi akan dihapus permanen. Rencana aktif tetap aman.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AlokaColors.terracotta,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.controller.clearAllHistory();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Semua riwayat dihapus.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customCategories = widget.controller.allCategories
        .where((cat) => !cat.isDefault)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 118),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profil & Pengaturan',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),

          // 1. Kartu Profil Pengguna
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AlokaColors.surfaceWhite,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AlokaColors.mustardGold,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        size: 28,
                        color: AlokaColors.charcoal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.controller.userProfile.fullname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Halo, ${widget.controller.userProfile.username}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const AlokaPillBadge(
                      text: 'Offline',
                      backgroundColor: AlokaColors.pastelLime,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _fullnameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap',
                    hintText: 'Default: Pengguna',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _usernameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    hintText: 'Default: user',
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _saveProfile(context),
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Simpan Profil'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Manajemen Kategori Kustom
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AlokaColors.surfaceWhite,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kategori Kustom',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Kategori terarsip tetap tersimpan pada riwayat lama.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (customCategories.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AlokaColors.surfaceSand,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Belum ada kategori kustom.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AlokaColors.charcoal,
                          ),
                    ),
                  )
                else
                  ...customCategories.map(
                    (cat) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AlokaColors.background,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              AlokaCategoryIcons.resolve(cat.iconKey),
                              size: 18,
                              color: AlokaColors.charcoal,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cat.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                  Text(
                                    '${cat.type.label} • ${cat.isArchived ? "Arsip" : "Aktif"}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                widget.controller.toggleArchiveCustomCategory(
                                  categoryId: cat.id,
                                  archived: !cat.isArchived,
                                );
                              },
                              child: Text(
                                cat.isArchived ? 'Pulihkan' : 'Arsipkan',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Data & Privasi Lokal
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AlokaColors.surfaceWhite,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data & Privasi Lokal',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Seluruh rencana anggaran dan riwayat tersimpan lokal di perangkat.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.controller.history.isEmpty
                        ? null
                        : () => _confirmClearAllHistory(context),
                    icon: const Icon(
                      Icons.delete_sweep_outlined,
                      color: AlokaColors.terracotta,
                    ),
                    label: const Text('Hapus Semua Riwayat'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AlokaColors.terracotta,
                      side: const BorderSide(color: AlokaColors.terracotta),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Tentang Aloka (Ringkas 2 kalimat)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AlokaColors.surfaceSand,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AlokaColors.mustardGold,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_outlined,
                        size: 18,
                        color: AlokaColors.charcoal,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tentang Aloka',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Aloka membantu merencanakan pembagian uang saku bulanan secara luring. Algoritma Genetika memprioritaskan kebutuhan wajib serta menimbang target tabungan sesuai bobot pilihan Anda.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AlokaColors.charcoal,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
