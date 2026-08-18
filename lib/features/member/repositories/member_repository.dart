import '../models/member_model.dart';
import '../services/member_api_service.dart';
import '../../family/services/family_api_service.dart';

/// Repository quản lý dữ liệu thành viên.
/// Kết nối tới Backend FastAPI qua MemberApiService.
/// Tự động gắn và lọc dữ liệu theo Gia phả đang chọn (family_id).
class MemberRepository {
  /// Cache danh sách thành viên trong bộ nhớ
  static List<MemberModel> members = [];

  /// Trạng thái đã tải dữ liệu từ API chưa
  static bool _isLoaded = false;
  static int? _cachedFamilyId;

  /// Lấy danh sách thành viên từ Backend API (theo gia phả đang hoạt động)
  static Future<List<MemberModel>> fetchAll({bool forceRefresh = false, int? familyId}) async {
    int? targetFamilyId = familyId;
    if (targetFamilyId == null) {
      final curFam = await FamilyApiService.getCurrentFamily();
      targetFamilyId = curFam?.id;
    }

    if (_isLoaded && !forceRefresh && _cachedFamilyId == targetFamilyId) {
      return members;
    }
    try {
      members = await MemberApiService.fetchAll(familyId: targetFamilyId);
      _isLoaded = true;
      _cachedFamilyId = targetFamilyId;
      return members;
    } catch (e) {
      // Nếu Backend không khả dụng, trả về cache hiện tại nếu có
      if (members.isNotEmpty) return members;
      rethrow;
    }
  }

  /// Thêm thành viên mới qua API → tự động gán familyId đang hoạt động nếu thiếu
  static Future<MemberModel> addMember(MemberModel member) async {
    MemberModel toCreate = member;
    if (toCreate.familyId == null) {
      final curFam = await FamilyApiService.getCurrentFamily();
      if (curFam != null) {
        toCreate = toCreate.copyWith(familyId: curFam.id);
      }
    }
    final created = await MemberApiService.create(toCreate);
    _isLoaded = false;
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
    _isLoaded = false;
    final idx = members.indexWhere((m) => m.id == id);
    if (idx != -1) {
      members[idx] = updated;
    }
    return updated;
  }

  /// Xóa thành viên qua API → cập nhật cache
  static Future<void> deleteMember(String id) async {
    await MemberApiService.delete(id);
    _isLoaded = false;
    members.removeWhere((m) => m.id == id);
  }

  /// Cập nhật vai trò thành viên (admin/editor/member) → cập nhật cache
  static Future<void> updateRole(String id, String role) async {
    await MemberApiService.updateRole(id, role);
    final idx = members.indexWhere((m) => m.id == id);
    if (idx != -1) {
      members[idx] = members[idx].copyWith(role: role);
    }
  }

  /// Xóa cache, buộc tải lại từ API lần tiếp theo hoặc khi đổi gia phả
  static void invalidateCache() {
    _isLoaded = false;
    _cachedFamilyId = null;
    members.clear();
  }
}
