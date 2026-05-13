import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:image_picker/image_picker.dart';
import 'package:labirynt_premium/src/core/theme/app_theme.dart';
import 'package:labirynt_premium/src/core/utils/app_haptics.dart';
import 'package:labirynt_premium/src/core/providers/user_provider.dart';
import 'package:labirynt_premium/src/core/extensions/l10n_extension.dart';
import 'package:labirynt_premium/src/features/auth/data/auth_repository.dart';

import 'package:labirynt_premium/src/core/ui/eu_components.dart';
import 'package:labirynt_premium/src/core/ui/eu_photo_source_picker.dart';
import 'package:labirynt_premium/src/core/ui/eu_toast.dart';

class AvatarUploadScreen extends ConsumerStatefulWidget {
  const AvatarUploadScreen({super.key});

  @override
  ConsumerState<AvatarUploadScreen> createState() => _AvatarUploadScreenState();
}

class _AvatarUploadScreenState extends ConsumerState<AvatarUploadScreen> {
  XFile? _selectedImage;
  bool _isLoading = false;

  Future<void> _onImagePicked(XFile file) async {
    if (!mounted) return;
    setState(() => _selectedImage = file);
    _handleUpload(file);
  }

  Future<void> _handleUpload(XFile image) async {
    setState(() => _isLoading = true);
    AppHaptics.heavyImpact(ref);

    try {
      debugPrint('[AvatarUpload] Starting upload...');
      final downloadUrl = await ref
          .read(authRepositoryProvider)
          .uploadProfileImage(image);
      debugPrint('[AvatarUpload] Upload complete! URL: $downloadUrl');

      // Force refresh of the user profile provider
      ref.invalidate(userProfileProvider);

      if (mounted) {
        EuphireToast.show(context, message: context.l10n.avatarUpdateSuccess);
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('[AvatarUpload] ERROR: $e');
      if (mounted) {
        EuphireToast.show(context, message: "${context.l10n.error}: $e");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider).valueOrNull;
    final user = ref.watch(authStateProvider).value;

    // Prefer Firestore photoUrl as it updates more reliably in real-time
    String? photoUrl = userProfile?.photoUrl ?? user?.photoURL;

    // Cache buster for Web to force refresh when same URL is reused
    if (kIsWeb && photoUrl != null && photoUrl.contains('firebasestorage')) {
      photoUrl = "$photoUrl&t=${DateTime.now().millisecondsSinceEpoch}";
    }

    // Background Image Logic
    ImageProvider? bgImageProvider;
    if (_selectedImage != null) {
      if (kIsWeb) {
        bgImageProvider = NetworkImage(_selectedImage!.path);
      } else {
        bgImageProvider = FileImage(File(_selectedImage!.path));
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          // CORRECTED GRADIENT: Green (Top) -> Dark (Bottom)
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.nocturne, // Green/Teal
              AppColors.deepTealBackground, // Darker
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Hero(
                  tag: 'profile-avatar',
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.surfaceTeal,
                        width: 3,
                      ),
                      color: Colors.black26,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _selectedImage != null
                        ? Image(image: bgImageProvider!, fit: BoxFit.cover)
                        : (photoUrl != null
                              ? Image.network(
                                  photoUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (ctx, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return const Center(
                                          child: CircularProgressIndicator(
                                            color: AppColors.ember,
                                            strokeWidth: 2,
                                          ),
                                        );
                                      },
                                  errorBuilder: (ctx, error, stackTrace) {
                                    return const Icon(
                                      Icons.broken_image,
                                      size: 50,
                                      color: Colors.white54,
                                    );
                                  },
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 100,
                                  color: Colors.white54,
                                )),
                  ),
                ),
                if (_isLoading)
                  Container(
                    width: 200,
                    height: 200,
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: AppColors.ember),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 60),

            EuPhotoSourcePicker(onImagePicked: _onImagePicked),

            const SizedBox(height: 20),
            Text(
              context.l10n.avatarUpdateHint,
              style: TextStyle(
                fontFamily: 'Montserrat',
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
