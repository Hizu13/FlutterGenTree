import '../models/member_model.dart';
import '../services/member_api_service.dart';

/// Repository quản lý dữ liệu thành viên.
/// Kết nối tới Backend FastAPI qua MemberApiService.
/// Giữ cache cục bộ để hiển thị nhanh, đồng bộ với DB khi có thay đổi.
class MemberRepository {
  /// Cache danh sách thành viên trong bộ nhớ
  static List<MemberModel> members = [];

  /// Trạng thái đã tải dữ liệu từ API chưa
  static bool _isLoaded = false;

  /// Lấy toàn bộ thành viên từ Backend API (có cache)
  static Future<List<MemberModel>> fetchAll({bool forceRefresh = false}) async {
    if (_isLoaded && !forceRefresh) {
      return members;
    }
    try {
      members = await MemberApiService.fetchAll();
      _isLoaded = true;
      return members;
    } catch (e) {
      // Nếu Backend không khả dụng, trả về cache hiện tại
      if (members.isNotEmpty) return members;
      rethrow;
    }
  }

  /// Thêm thành viên mới qua API → cập nhật cache
  static Future<MemberModel> addMember(MemberModel member) async {
    final created = await MemberApiService.create(member);
    final idx = members.indexWhere((m) => m.id == created.id);
    if (idx == -1) {
      members.add(created);
    } else {
      members[idx] = created;
    }
    return created;
  }

  /// Cập nhật thành viên qua API → cập nhật cache
  static Future<MemberModel> updateMember(String id, MemberModel member) async {
    final updated = await MemberApiService.update(id, member);
    final idx = members.indexWhere((m) => m.id == id);
    if (idx != -1) {
      members[idx] = updated;
    }
    return updated;
  }

  /// Xóa thành viên qua API → cập nhật cache
  static Future<void> deleteMember(String id) async {
    await MemberApiService.delete(id);
    members.removeWhere((m) => m.id == id);
  }

  /// Xóa cache, buộc tải lại từ API lần tiếp theo
  static void invalidateCache() {
    _isLoaded = false;
  }
}
