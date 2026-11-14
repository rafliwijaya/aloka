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
        title: const Text('Hapus Seluruh Riwayat?'),
        content: const Text(
          'Semua riwayat hasil optimasi yang tersimpan di perangkat ini akan dihapus permanen. Rencana anggaran aktif saat ini tidak akan terhapus.',
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
            content: Text('Seluruh riwayat optimasi telah dihapus.'),
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
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profil & Pengaturan',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),

          // 1. Kartu Profil Pengguna (Fullname & Username)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AlokaColors.surfaceWhite,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AlokaColors.mustardGold,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        size: 30,
                        color: AlokaColors.charcoal,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.controller.userProfile.fullname,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Halo, ${widget.controller.userProfile.username}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const AlokaPillBadge(
                      text: 'Lokal Offline',
                      backgroundColor: AlokaColors.pastelLime,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _fullnameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap (Fullname)',
                    hintText: 'Default: Pengguna',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _usernameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Username (Ditampilkan pada Beranda)',
                    hintText: 'Default: user',
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _saveProfile(context),
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Simpan Profil Pengguna'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 2. Manajemen Kategori Kustom & Arsip (Bagian 4.C)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AlokaColors.surfaceWhite,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manajemen Kategori Kustom',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Kategori kustom yang diarsipkan tidak akan muncul pada rencana baru, namun riwayat optimasi lama tetap terjaga utuh.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (customCategories.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AlokaColors.surfaceSand,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Belum ada kategori kustom. Anda dapat menambahkannya melalui halaman Anggaran.',
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
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  AlokaCategoryIcons.resolve(cat.iconKey),
                                  size: 18,
                                  color: AlokaColors.charcoal,
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cat.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                    Text(
                                      '${cat.type.label} • ${cat.isArchived ? "Diarsipkan" : "Aktif"}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ],
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
          const SizedBox(height: 18),

          // 3. Privasi & Penyimpanan Lokal
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AlokaColors.surfaceWhite,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data & Privasi Lokal',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Seluruh data uang saku, kategori, dan riwayat optimasi disimpan 100% secara lokal di perangkat Anda (SQLite) tanpa dikirim ke server eksternal.',
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
                    label: const Text('Bersihkan Semua Riwayat Optimasi'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AlokaColors.terracotta,
                      side: const BorderSide(color: AlokaColors.terracotta),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 4. Tentang Aloka & Metode Algoritma Genetika
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AlokaColors.surfaceSand,
              borderRadius: BorderRadius.circular(26),
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
                        borderRadius: BorderRadius.circular(12),
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
                        'Tentang Aloka & Algoritma Genetika',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Aloka adalah aplikasi mobile perencanaan alokasi uang saku bulanan mahasiswa. '
                  'Aloka menggunakan Algoritma Genetika (Genetic Algorithm) untuk mencari kombinasi pembagian anggaran yang memenuhi seluruh batas minimum kebutuhan wajib serta memaksimalkan pencapaian target alokasi dan tabungan berdasarkan bobot prioritas pengguna.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AlokaColors.charcoal,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Judul Penelitian:\n“Pengembangan Aplikasi Mobile untuk Optimasi Alokasi Uang Saku Mahasiswa Menggunakan Algoritma Genetika Berdasarkan Prioritas Kebutuhan dan Target Tabungan.”',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AlokaColors.charcoal,
                        fontWeight: FontWeight.w600,
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
