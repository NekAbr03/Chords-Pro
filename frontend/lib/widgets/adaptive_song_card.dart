import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cupertino_native/cupertino_native.dart';

class AdaptiveSongCard extends StatelessWidget {
  final String title;
  final String artist;
  final String url;
  final String? source; // 1. Новое поле
  final VoidCallback onTap;

  const AdaptiveSongCard({
    super.key,
    required this.title,
    required this.artist,
    required this.url,
    this.source, // Добавили в конструктор
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && Platform.isIOS) {
      // iOS: Native Cupertino Style (No Glass)
      final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

      return Container(
        margin: const EdgeInsets.only(bottom: 1), // Separator effect
        color: isDark
            ? CupertinoColors.black
            : CupertinoColors.systemBackground,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onTap,
          child: _buildIOSContent(context),
        ),
      );
    }

    // Android / Web: Material 3
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: _buildAndroidContent(theme),
      ),
    );
  }

  // --- IOS CONTENT ---
  Widget _buildIOSContent(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final iconColor = isDark ? CupertinoColors.white : CupertinoColors.black;
    final titleColor = isDark ? CupertinoColors.white : CupertinoColors.black;
    final subtitleColor = CupertinoColors.systemGrey;

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: CNIcon(
              symbol: const CNSymbol('music.note'),
              color: iconColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: titleColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        artist,
                        style: TextStyle(fontSize: 14, color: subtitleColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (source != null && source!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          source!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: CupertinoColors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const CNIcon(
            symbol: CNSymbol('chevron.right'),
            color: CupertinoColors.systemGrey,
          ),
        ],
      ),
    );
  }

  // --- ANDROID CONTENT ---
  Widget _buildAndroidContent(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withValues(
                alpha: 0.8,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.music_note,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // 2. Артист + Источник в одной строке
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        artist,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // 3. Рисуем бейдж только если источник есть
                    if (source != null && source!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          source!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}
