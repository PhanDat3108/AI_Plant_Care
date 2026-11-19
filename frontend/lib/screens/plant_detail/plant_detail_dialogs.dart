import 'package:flutter/material.dart';

import '../../models/plant_model.dart';
import '../../theme/app_theme.dart';

TimeOfDay _parseTimeOfDay(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length == 2) {
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) {
      return TimeOfDay(hour: h, minute: m);
    }
  }
  return const TimeOfDay(hour: 8, minute: 0);
}

String _formatTimeOfDay(TimeOfDay time) {
  final hh = time.hour.toString().padLeft(2, '0');
  final mm = time.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

/// Hộp thoại chỉnh chu kỳ và giờ nhắc (Tưới nước / Bón phân)
Future<({int intervalDays, String localTime, bool enabled})?>
showEditScheduleDialog(
  BuildContext context, {
  required bool isWater,
  required int currentDays,
  required String currentTime,
  required bool currentEnabled,
}) {
  var daysText = currentDays.toString();
  var selectedTime = _parseTimeOfDay(currentTime);
  var enabled = currentEnabled;
  String? validationError;

  return showDialog<({int intervalDays, String localTime, bool enabled})>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              isWater ? 'Chỉnh lịch tưới nước' : 'Chỉnh lịch bón phân',
              style: const TextStyle(color: AppTheme.titleTextColor),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  initialValue: daysText,
                  keyboardType: TextInputType.number,
                  onChanged: (val) => daysText = val,
                  decoration: InputDecoration(
                    labelText: 'Chu kỳ (1 - 365 ngày)',
                    errorText: validationError,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Giờ nhắc nhở'),
                    TextButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setDialogState(() => selectedTime = picked);
                        }
                      },
                      icon: const Icon(Icons.schedule_rounded, size: 18),
                      label: Text(_formatTimeOfDay(selectedTime)),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bật nhắc nhở'),
                  value: enabled,
                  activeThumbColor: AppTheme.primaryColor,
                  onChanged: (val) => setDialogState(() => enabled = val),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Hủy',
                  style: TextStyle(color: AppTheme.subTextColor),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final parsed = int.tryParse(daysText.trim());
                  if (parsed == null || parsed < 1 || parsed > 365) {
                    setDialogState(() {
                      validationError = 'Nhập số nguyên từ 1 đến 365';
                    });
                    return;
                  }
                  Navigator.pop(dialogContext, (
                    intervalDays: parsed,
                    localTime: _formatTimeOfDay(selectedTime),
                    enabled: enabled,
                  ));
                },
                child: const Text('Lưu'),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Hộp thoại thêm hoặc sửa mục nhật ký chăm sóc
Future<({String? kind, String note})?> showCareLogDialog(
  BuildContext context, {
  CareLog? existingLog,
}) {
  final isEdit = existingLog != null;
  final isLinkedToTask = existingLog?.taskId != null;
  var selectedKind = existingLog?.kind ?? 'water';
  var noteText = existingLog?.note ?? '';

  const kindOptions = <({String value, String label})>[
    (value: 'water', label: 'Tưới nước'),
    (value: 'fertilize', label: 'Bón phân'),
    (value: 'treat', label: 'Phun thuốc / Điều trị'),
    (value: 'note', label: 'Ghi chú'),
  ];

  return showDialog<({String? kind, String note})>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              isEdit ? 'Sửa nhật ký chăm sóc' : 'Thêm nhật ký chăm sóc',
              style: const TextStyle(color: AppTheme.titleTextColor),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Loại hoạt động',
                    style: TextStyle(
                      color: AppTheme.subTextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: kindOptions.map((opt) {
                      return ChoiceChip(
                        label: Text(opt.label),
                        selected: selectedKind == opt.value,
                        onSelected: isLinkedToTask
                            ? null
                            : (_) => setDialogState(
                                  () => selectedKind = opt.value,
                                ),
                      );
                    }).toList(),
                  ),
                  if (isLinkedToTask) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Nhật ký gắn với lịch trình không thể đổi loại hoạt động.',
                      style: TextStyle(
                        color: AppTheme.subTextColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: noteText,
                    maxLines: 3,
                    onChanged: (val) => noteText = val,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú (tùy chọn)',
                      hintText: 'Ví dụ: Đã tưới 300ml, lá tươi hơn...',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Hủy',
                  style: TextStyle(color: AppTheme.subTextColor),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, (
                  kind: isLinkedToTask ? null : selectedKind,
                  note: noteText.trim(),
                )),
                child: const Text('Lưu'),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Hộp thoại xác nhận xóa một mục nhật ký
Future<bool> showDeleteCareLogDialog(
  BuildContext context, {
  required bool isLinkedToTask,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Xóa nhật ký?',
        style: TextStyle(color: AppTheme.sickBadgeText),
      ),
      content: Text(
        isLinkedToTask
            ? 'Nhật ký này đang gắn với một nhiệm vụ lịch trình. Nếu xóa, nhiệm vụ tương ứng sẽ quay lại trạng thái chờ.'
            : 'Bạn có chắc chắn muốn xóa mục nhật ký này không?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text(
            'Hủy',
            style: TextStyle(color: AppTheme.subTextColor),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.sickBadgeText,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Xóa'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Hộp thoại đổi biệt danh cây
Future<String?> showEditNicknameDialog(
  BuildContext context, {
  required String currentNickname,
}) {
  var nicknameText = currentNickname;
  String? errorText;

  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Đổi biệt danh',
              style: TextStyle(color: AppTheme.titleTextColor),
            ),
            content: TextFormField(
              initialValue: nicknameText,
              onChanged: (val) => nicknameText = val,
              decoration: InputDecoration(
                hintText: 'Nhập tên gọi mới cho cây...',
                errorText: errorText,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Hủy',
                  style: TextStyle(color: AppTheme.subTextColor),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final trimmed = nicknameText.trim();
                  if (trimmed.isEmpty) {
                    setDialogState(() {
                      errorText = 'Tên cây không được để trống.';
                    });
                    return;
                  }
                  Navigator.pop(dialogContext, trimmed);
                },
                child: const Text('Lưu'),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Hộp thoại xác nhận xóa cây khỏi vườn
Future<bool> showDeletePlantDialog(
  BuildContext context, {
  required String plantNickname,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Xóa cây?',
        style: TextStyle(color: AppTheme.sickBadgeText),
      ),
      content: Text(
        'Bạn có chắc chắn muốn xóa "$plantNickname" khỏi Vườn của mình không?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text(
            'Hủy',
            style: TextStyle(color: AppTheme.subTextColor),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.sickBadgeText,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Xóa'),
        ),
      ],
    ),
  );
  return confirmed == true;
}