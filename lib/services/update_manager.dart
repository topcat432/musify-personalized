/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'dart:convert';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/personalized_update_service.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/widgets/personalized_update_dialog.dart';

const String _upstreamAnnouncementUrl =
    'https://raw.githubusercontent.com/gokadzev/Musify/update/check.json';

Future<void> checkAppUpdates({bool showWhenCurrent = false}) async {
  final service = PersonalizedUpdateService();
  try {
    // Update checks and home-page announcements share the same opt-in. Keep
    // both channels refreshed without trusting the upstream APK download URL.
    await fetchAnnouncementOnly();
    final check = await service.check();
    if (check.availability == PersonalizedUpdateAvailability.current) {
      if (showWhenCurrent) {
        await _showUpdateStatusDialog(
          title: 'You are up to date',
          message:
              'Installed production build ${check.installed.versionCode} is the newest verified personalized release.',
          icon: FluentIcons.checkmark_circle_24_regular,
        );
      }
      return;
    }

    await showDialog<void>(
      context: NavigationManager().context,
      builder: (_) => PersonalizedUpdateDialog(check: check, service: service),
    );
  } catch (error, stackTrace) {
    logger.log(
      'Error in personalized update check',
      error: error,
      stackTrace: stackTrace,
    );
    if (showWhenCurrent) {
      await _showUpdateStatusDialog(
        title: 'Could not check for updates',
        message: error.toString(),
        icon: FluentIcons.warning_24_regular,
        isError: true,
      );
    }
  } finally {
    service.close();
  }
}

Future<void> _showUpdateStatusDialog({
  required String title,
  required String message,
  required IconData icon,
  bool isError = false,
}) {
  return showDialog<void>(
    context: NavigationManager().context,
    builder: (context) {
      final colors = Theme.of(context).colorScheme;
      return AlertDialog(
        icon: Icon(
          icon,
          color: isError ? colors.error : colors.primary,
          size: 40,
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}

void showUpdateCheckDialog(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        icon: Icon(
          FluentIcons.arrow_sync_circle_24_regular,
          color: colorScheme.primary,
          size: 40,
        ),
        title: Text(
          context.l10n!.checkForUpdates,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'Automatically check for verified Musify Personalized production updates when the app starts.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () {
              shouldWeCheckUpdates.value = false;
              addOrUpdateData<bool>('settings', 'shouldWeCheckUpdates', false);
              Navigator.of(context).pop();
            },
            child: Text(context.l10n!.no),
          ),
          FilledButton(
            onPressed: () {
              shouldWeCheckUpdates.value = true;
              addOrUpdateData<bool>('settings', 'shouldWeCheckUpdates', true);
              if (!isFdroidBuild && kReleaseMode && !offlineMode.value) {
                checkAppUpdates();
                isUpdateChecked = true;
              }
              Navigator.of(context).pop();
            },
            child: Text(context.l10n!.yes),
          ),
        ],
      );
    },
  );
}

/// Fetch only the upstream announcement URL without using its APK channel.
Future<void> fetchAnnouncementOnly() async {
  try {
    final response = await http.get(Uri.parse(_upstreamAnnouncementUrl));
    if (response.statusCode != 200) {
      logger.log(
        'Fetch announcement returned status code ${response.statusCode}',
      );
      return;
    }
    final map = json.decode(response.body) as Map<String, dynamic>;
    final announcement = map['announcementurl'];
    announcementURL.value = announcement?.toString();
  } catch (error, stackTrace) {
    logger.log(
      'Error in fetchAnnouncementOnly',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
