import 'dart:io'; // Для Platform
import 'dart:ui'; // Для ImageFilter
import 'package:flutter/foundation.dart'; // Для kIsWeb
import 'package:flutter/material.dart';
import 'glass/liquid_controls.dart';

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
    final theme = Theme.of(context);
    // --- 2. IOS & WEB (Liquid Glass) ---
    if (!kIsWeb && Platform.isAndroid) {
      // Keep existing Android logic (Material 3)
      return Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: _buildContent(theme),
        ),
      );
    }

    // iOS / Web -> Liquid Glass Style
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        onTap: onTap,
        borderRadius: 20,
        child: _buildContent(theme),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withOpacity(0.8),
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
