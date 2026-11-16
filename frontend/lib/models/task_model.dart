enum TaskType { 
  water,              //Tưới nước
  fertilize,          //Bón phân 
  spray               //Phun thuốc
}                    

class TaskModel {
  final String id;
  final String plantId;
  final String plantNickname;
  final String plantAvatar;
  final TaskType type;
  final bool isCompleted;

  TaskModel({
    required this.id,
    required this.plantId,
    required this.plantNickname,
    required this.plantAvatar,
    required this.type,
    this.isCompleted = false,
  });

  // xử lý khi người dùng thay đổi trạng thái hoàn thành
  TaskModel copyWith({
    bool? isCompleted,
  }) {
    return TaskModel(
      id: id,
      plantId: plantId,
      plantNickname: plantNickname,
      plantAvatar: plantAvatar,
      type: type,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}