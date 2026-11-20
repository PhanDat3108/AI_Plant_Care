import 'package:flutter/material.dart';
import '../core/api_exception.dart';
import '../models/plant_model.dart';
import '../services/garden_service.dart';
import '../theme/app_theme.dart';
import '../widgets/header_sheet_scaffold.dart';
import '../widgets/plant_card.dart';

class MyGardenScreen extends StatefulWidget {
  const MyGardenScreen({super.key});

  @override
  State<MyGardenScreen> createState() => _MyGardenScreenState();
}

class _MyGardenScreenState extends State<MyGardenScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  List<PlantModel> _plants = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plants = await GardenService.getPlants();
      if (!mounted) return;
      setState(() {
        _plants = plants;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Không tải được vườn cây. Vui lòng thử lại.';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Lọc theo biệt danh, tên phổ thông hoặc tên khoa học.
  List<PlantModel> get _filteredPlants {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _plants;
    return _plants.where((p) {
      return p.nickname.toLowerCase().contains(q) ||
          p.commonName.toLowerCase().contains(q) ||
          p.scientificName.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return HeaderSheetScaffold(
      header: _buildHeader(),
      body: _buildBody(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Vườn của tôi',
                  style: TextStyle(
                    color: AppTheme.titleTextColor,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Icon(
                Icons.local_florist_rounded,
                size: 46,
                color: AppTheme.primaryColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildSearchField(),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    final noBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide.none,
    );

    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Tìm cây trong vườn...',
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppTheme.subTextColor,
        ),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppTheme.subTextColor,
                ),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
        border: noBorder,
        enabledBorder: noBorder,
        focusedBorder: noBorder,
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.subTextColor)),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }
    final plants = _filteredPlants;

    if (plants.isEmpty) {
      return _EmptyState(
        message: _plants.isEmpty
            ? 'Vườn của bạn chưa có cây nào.\nHãy bấm nút Quét AI để thêm cây đầu tiên!'
            : 'Không tìm thấy cây nào phù hợp.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        mainAxisExtent: 216,
      ),
      itemCount: plants.length,
      itemBuilder: (context, index) {
        // TODO: onTap mở màn chi tiết cây khi màn đó được làm.
        return PlantCard(plant: plants[index]);
      },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.eco_outlined,
              size: 56,
              color: AppTheme.subTextColor,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.subTextColor,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
