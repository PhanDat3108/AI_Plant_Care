import '../models/task_model.dart';
import 'dio_client.dart';

class CareTaskPage {
  final String date;
  final String timezone;
  final List<TaskModel> items;

  const CareTaskPage({
    required this.date,
    required this.timezone,
    required this.items,
  });
}

class CareTaskService {
  static Future<CareTaskPage> getCareTasks({
    String? date,
    String state = 'pending',
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      'state': state,
      'limit': limit,
      'offset': offset,
      if (date != null && date.isNotEmpty) 'date': date,
    };

    final data = await DioClient.instance.get(
      '/care-tasks',
      queryParameters: params,
    );

    if (data is! Map) {
      return const CareTaskPage(
        date: '',
        timezone: 'Asia/Ho_Chi_Minh',
        items: [],
      );
    }

    final rawItems = data['items'];
    final items = rawItems is List
        ? rawItems
            .whereType()
            .map((item) => TaskModel.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <TaskModel>[];

    return CareTaskPage(
      date: data['date']?.toString() ?? '',
      timezone: data['timezone']?.toString() ?? 'Asia/Ho_Chi_Minh',
      items: items,
    );
  }

  /// Lấy toàn bộ việc trong ngày (cả đang chờ và đã xong) để hiển thị tiến độ.
  static Future<CareTaskPage> getTodayTasks({String? date}) async {
    final pages = await Future.wait([
      getCareTasks(date: date, state: 'pending', limit: 100),
      getCareTasks(date: date, state: 'done', limit: 100),
    ]);

    final pendingPage = pages[0];
    final donePage = pages[1];

    return CareTaskPage(
      date: pendingPage.date.isNotEmpty ? pendingPage.date : donePage.date,
      timezone: pendingPage.timezone,
      items: [...pendingPage.items, ...donePage.items],
    );
  }
}