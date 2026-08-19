import 'package:flutter/material.dart';
import 'dart:math';
import '../../../config/app_color.dart';
import '../../auth/models/auth_request_model.dart';
import '../../auth/services/auth_service.dart';
import '../../member/models/member_model.dart';
import '../../member/repositories/member_repository.dart';
import '../../member/screens/member_profile_screen.dart';
import '../../member/services/member_api_service.dart';
import '../../family/models/family_model.dart';
import '../../family/services/family_api_service.dart';

class TreeScreen extends StatefulWidget {
  final FamilyModel? family;
  const TreeScreen({super.key, this.family});

  @override
  State<TreeScreen> createState() => _TreeScreenState();
}

class _TreeScreenState extends State<TreeScreen> with SingleTickerProviderStateMixin {
  static const int kFilterFourGenerations = -4;

  final TransformationController _transformationController = TransformationController();
  AnimationController? _animationController;
  Animation<Matrix4>? _animation;

  List<MemberModel> _allMembers = [];
  List<FamilyTreeLayoutNode> _layoutRoots = [];
  UserModel? _currentUser;
  MemberModel? _currentMember;

  // Dropdown chọn thành viên A và B để tìm quan hệ
  String? _selectedPersonAId;
  String? _selectedPersonBId;
  String? _relationshipName;
  String? _relationshipDetail;
  List<String> _highlightedPathNodeIds = [];
  bool _isDetailExpanded = false;

  // Bộ lọc theo thế hệ (đời) - Mặc định là 4 đời gần nhất từ bản thân lên
  int? _selectedGenerationFilter = kFilterFourGenerations;

  // Bản đồ lưu trữ tọa độ của các thành viên để vẽ đường nối nổi bật
  final Map<String, Offset> _nodePositions = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(() {
        if (_animation != null) {
          _transformationController.value = _animation!.value;
        }
      });

    _loadData();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final targetFamily = widget.family ?? await FamilyApiService.getCurrentFamily();
    final targetFamilyId = targetFamily?.id;
    _currentUser = await AuthService.getSavedUser();
    _currentUser ??= await AuthService.fetchProfile();

    try {
      await MemberRepository.fetchAll(forceRefresh: true, familyId: targetFamilyId);
    } catch (_) {}


    _allMembers = List.from(MemberRepository.members);
    _currentMember = _findCurrentMember();

    _rebuildTree();

    // Tự động định vị về vị trí bản thân khi mở màn hình
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) {
            _locateSelf(animated: true);
          }
        });
      }
    });
  }

  /// Định vị và căn giữa màn hình vào vị trí của bản thân trên sơ đồ
  void _locateSelf({bool animated = true}) {
    if (_currentMember?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa xác định được vị trí của bạn trên sơ đồ gia phả.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final pos = _nodePositions[_currentMember!.id!];
    if (pos == null) return;

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    // Chiều cao vùng hiển thị sơ đồ (trừ AppBar, RelationshipCard, FilterBar)
    final double viewportHeight = max(200.0, mediaQuery.size.height - 260.0);

    const double targetScale = 1.0;
    final double targetX = (screenWidth / 2) - (pos.dx * targetScale);
    final double targetY = (viewportHeight / 2) - (pos.dy * targetScale);

    final endMatrix = Matrix4.identity()
      ..setTranslationRaw(targetX, targetY, 0.0)
      ..scaleByDouble(targetScale, targetScale, 1.0, 1.0);

    if (animated && _animationController != null) {
      _animationController!.reset();
      _animation = Matrix4Tween(
        begin: _transformationController.value,
        end: endMatrix,
      ).animate(
        CurvedAnimation(
          parent: _animationController!,
          curve: Curves.easeInOutCubic,
        ),
      );
      _animationController!.forward();
    } else {
      _transformationController.value = endMatrix;
    }
  }

  void _rebuildTree() {
    if (!mounted) return;
    setState(() {
      _nodePositions.clear();
      _layoutRoots = _buildLayoutTrees(_allMembers);
    });
  }

  MemberModel? _findCurrentMember() {
    if (_allMembers.isEmpty) return null;
    if (_currentUser != null) {
      // 1. Khớp theo userId
      for (final m in _allMembers) {
        if (m.userId != null && m.userId == _currentUser!.id) return m;
      }
      // 2. Khớp theo CCCD
      if (_currentUser!.cccd != null && _currentUser!.cccd!.isNotEmpty) {
        for (final m in _allMembers) {
          if (m.identityCard != null && m.identityCard == _currentUser!.cccd) return m;
        }
      }
      // 3. Khớp theo Email
      if (_currentUser!.email.isNotEmpty) {
        for (final m in _allMembers) {
          if (m.email != null && m.email!.toLowerCase() == _currentUser!.email.toLowerCase()) return m;
        }
      }
      // 4. Khớp theo Họ và Tên
      final fullUName = '${_currentUser!.lastName ?? ""} ${_currentUser!.firstName}'.trim().toLowerCase();
      if (fullUName.isNotEmpty) {
        for (final m in _allMembers) {
          if (m.fullName.trim().toLowerCase() == fullUName) return m;
        }
      }
    }
    // Fallback: Tìm thành viên có đời cao (thế hệ trẻ) trong cây gia phả
    final withParents = _allMembers.where((m) => m.fatherId != null || m.motherId != null).toList();
    if (withParents.isNotEmpty) {
      withParents.sort((a, b) => (b.generation ?? 1).compareTo(a.generation ?? 1));
      return withParents.first;
    }
    return _allMembers.first;
  }

  // ===========================================================================
  // XÂY DỰNG CẤU TRÚC PHẢ HỆ
  // ===========================================================================
  List<FamilyTreeLayoutNode> _buildLayoutTrees(List<MemberModel> members) {
    if (members.isEmpty) return [];

    // Nếu đang chọn chế độ lọc "4 đời gần nhất từ bản thân lên"
    if (_selectedGenerationFilter == kFilterFourGenerations && _currentMember != null) {
      final tree = _buildFourGenerationsTree(members, _currentMember!);
      if (tree.isNotEmpty) return tree;
    }

    // Xây dựng toàn bộ cây phả hệ
    // 1. Tập hợp danh sách ID của tất cả những ai là "con" (có fatherId hoặc motherId)
    final Set<String> childIds = members
        .where((m) => m.fatherId != null || m.motherId != null)
        .map((m) => m.id!)
        .toSet();

    final List<MemberModel> roots = [];
    final Set<String> processedMemberIds = {};

    for (final m in members) {
      if (m.id == null || processedMemberIds.contains(m.id)) continue;

      // Người là con của ai đó thì không thể là Root
      if (childIds.contains(m.id)) continue;

      final spouse = _findSpouse(m, members);
      // Nếu vợ/chồng của người này là con của ai đó thì người này là dâu/rể -> Không phải Root
      if (spouse != null && spouse.id != null && childIds.contains(spouse.id)) {
        continue;
      }

      // Đây là tổ tiên gốc thực sự (cả 2 vợ chồng đều không có cha mẹ trong cây)
      if (spouse != null && spouse.id != null) {
        processedMemberIds.add(m.id!);
        processedMemberIds.add(spouse.id!);
        // Ưu tiên thành viên Nam làm node chính của Root
        if (m.gender == 'Nam') {
          roots.add(m);
        } else {
          roots.add(spouse);
        }
      } else {
        processedMemberIds.add(m.id!);
        roots.add(m);
      }
    }

    final List<FamilyTreeLayoutNode> layoutTrees = [];
    for (final r in roots) {
      layoutTrees.add(_buildSubtree(r, members));
    }

    double currentLeft = 50.0;
    for (final tree in layoutTrees) {
      _computeWidths(tree);
      _computePositions(tree, currentLeft, 0);
      currentLeft += tree.width + 100.0;
    }

    return layoutTrees;
  }

  /// Xây dựng cây chỉ hiển thị 4 đời gần nhất từ bản thân lên (mình là đời bé nhất)
  List<FamilyTreeLayoutNode> _buildFourGenerationsTree(List<MemberModel> members, MemberModel self) {
    // 1. Tìm tổ tiên ngược dòng tối đa 3 bước (tổng cộng 4 thế hệ: Cụ -> Ông/Bà -> Bố/Mẹ -> Bản thân)
    MemberModel currentAncestor = self;
    final List<MemberModel> ancestorLine = [self];

    for (int step = 0; step < 3; step++) {
      MemberModel? parent;
      if (currentAncestor.fatherId != null) {
        parent = members.where((m) => m.id == currentAncestor.fatherId).firstOrNull;
      }
      if (parent == null && currentAncestor.motherId != null) {
        parent = members.where((m) => m.id == currentAncestor.motherId).firstOrNull;
      }
      if (parent != null) {
        ancestorLine.add(parent);
        currentAncestor = parent;
      } else {
        break;
      }
    }

    // Tổ tiên cao nhất trong chuỗi 4 đời này
    final rootAncestor = ancestorLine.last;
    final maxGen = self.generation ?? 999;
    final int maxLevelsDown = ancestorLine.length - 1;

    final rootNode = _buildSubtreeLimited(rootAncestor, members, 0, maxLevelsDown, maxGen);

    _computeWidths(rootNode);
    _computePositions(rootNode, 50.0, 0);

    return [rootNode];
  }

  FamilyTreeLayoutNode _buildSubtreeLimited(
    MemberModel m,
    List<MemberModel> members,
    int currentLevel,
    int maxLevel,
    int maxGen,
  ) {
    MemberModel? spouse = _findSpouse(m, members);
    final List<FamilyTreeLayoutNode> childrenNodes = [];

    if (currentLevel < maxLevel) {
      final children = members.where((child) =>
        (child.fatherId == m.id || child.motherId == m.id) &&
        (child.generation == null || child.generation! <= maxGen)
      ).toList();

      for (final child in children) {
        childrenNodes.add(_buildSubtreeLimited(child, members, currentLevel + 1, maxLevel, maxGen));
      }
    }

    final uniqueChildrenNodes = <String, FamilyTreeLayoutNode>{};
    for (final cNode in childrenNodes) {
      if (cNode.member.id != null) {
        uniqueChildrenNodes[cNode.member.id!] = cNode;
      }
    }

    return FamilyTreeLayoutNode(
      member: m,
      spouse: spouse,
      children: uniqueChildrenNodes.values.toList(),
    );
  }

  MemberModel? _findSpouse(MemberModel m, List<MemberModel> members) {
    final children = members.where((child) => child.fatherId == m.id || child.motherId == m.id).toList();
    for (final child in children) {
      if (m.gender == 'Nam' && child.motherId != null) {
        final sp = members.where((item) => item.id == child.motherId).firstOrNull;
        if (sp != null) return sp;
      } else if (m.gender == 'Nữ' && child.fatherId != null) {
        final sp = members.where((item) => item.id == child.fatherId).firstOrNull;
        if (sp != null) return sp;
      }
    }
    return null;
  }

  FamilyTreeLayoutNode _buildSubtree(MemberModel m, List<MemberModel> members) {
    MemberModel? spouse = _findSpouse(m, members);
    final children = members.where((child) => child.fatherId == m.id || child.motherId == m.id).toList();

    final List<FamilyTreeLayoutNode> childrenNodes = [];
    for (final child in children) {
      childrenNodes.add(_buildSubtree(child, members));
    }

    final uniqueChildrenNodes = <String, FamilyTreeLayoutNode>{};
    for (final cNode in childrenNodes) {
      if (cNode.member.id != null) {
        uniqueChildrenNodes[cNode.member.id!] = cNode;
      }
    }

    return FamilyTreeLayoutNode(
      member: m,
      spouse: spouse,
      children: uniqueChildrenNodes.values.toList(),
    );
  }

  double _computeWidths(FamilyTreeLayoutNode node) {
    double coupleWidth = node.spouse != null ? (100.0 * 2 + 30.0) : 100.0;

    if (node.children.isEmpty) {
      node.width = coupleWidth;
      return node.width;
    }

    double childrenWidth = 0;
    for (int i = 0; i < node.children.length; i++) {
      childrenWidth += _computeWidths(node.children[i]);
      if (i < node.children.length - 1) {
        childrenWidth += 40.0; // childrenGap
      }
    }

    node.width = max(coupleWidth, childrenWidth);
    return node.width;
  }

  void _computePositions(FamilyTreeLayoutNode node, double left, int level) {
    double coupleWidth = node.spouse != null ? (100.0 * 2 + 30.0) : 100.0;
    node.y = level * 220.0 + 50.0; // level * levelHeight + padding

    if (node.children.isEmpty) {
      node.x = left + node.width / 2;
      _savePositions(node);
      return;
    }

    double childrenWidth = 0;
    for (int i = 0; i < node.children.length; i++) {
      childrenWidth += node.children[i].width;
      if (i < node.children.length - 1) {
        childrenWidth += 40.0;
      }
    }

    double childrenCenter = left + childrenWidth / 2;

    if (coupleWidth > childrenWidth) {
      node.x = left + coupleWidth / 2;
      double currentLeft = node.x - childrenWidth / 2;
      for (var child in node.children) {
        _computePositions(child, currentLeft, level + 1);
        currentLeft += child.width + 40.0;
      }
    } else {
      node.x = childrenCenter;
      double currentLeft = left;
      for (var child in node.children) {
        _computePositions(child, currentLeft, level + 1);
        currentLeft += child.width + 40.0;
      }
    }
    _savePositions(node);
  }

  void _savePositions(FamilyTreeLayoutNode node) {
    if (node.spouse != null) {
      _nodePositions[node.member.id!] = Offset(node.x - 65.0, node.y + 62.5);
      _nodePositions[node.spouse!.id!] = Offset(node.x + 65.0, node.y + 62.5);
    } else {
      _nodePositions[node.member.id!] = Offset(node.x, node.y + 62.5);
    }
  }

  // ===========================================================================
  // THUẬT TOÁN TÌM MỐI QUAN HỆ TIẾNG VIỆT
  // ===========================================================================
  Future<void> _calculateRelationship() async {
    if (_selectedPersonAId == null || _selectedPersonBId == null) {
      setState(() {
        _relationshipName = null;
        _relationshipDetail = null;
        _highlightedPathNodeIds = [];
      });
      return;
    }

    final idA = _selectedPersonAId!;
    final idB = _selectedPersonBId!;

    if (idA == idB) {
      setState(() {
        _relationshipName = "Cùng một người";
        _relationshipDetail = null;
        _highlightedPathNodeIds = [idA];
      });
      return;
    }

    final personA = _getMember(idA);
    final personB = _getMember(idB);
    if (personA == null || personB == null) return;

    final intIdA = int.tryParse(idA);
    final intIdB = int.tryParse(idB);

    if (intIdA != null && intIdB != null) {
      final res = await MemberApiService.findRelationshipPath(intIdA, intIdB);
      if (res != null) {
        if (mounted && _selectedPersonAId == idA && _selectedPersonBId == idB) {
          final summary = res['summary'] as String?;
          final detailed = res['detailed'] as String?;
          final pathList = (res['path'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

          setState(() {
            _relationshipName = summary ?? res['relationship'] as String?;
            _relationshipDetail = (detailed != null && detailed.isNotEmpty) ? detailed : null;
            _highlightedPathNodeIds = pathList;
            _isDetailExpanded = false;

            // Luôn chuyển sang bộ lọc Tất cả thế hệ và làm mới tọa độ tất cả node để bảo đảm có đầy đủ các vị trí
            _selectedGenerationFilter = null;
            _nodePositions.clear();
            _layoutRoots = _buildLayoutTrees(_allMembers);
          });


          // Căn giữa và điều chỉnh tầm nhìn để thấy rõ đường nối giữa 2 người
          if (pathList.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _focusOnPath(pathList);
              }
            });
          }
          return;
        }
      }
    }

    // Fallback: Local calculation
    _calculateRelationshipLocal(personA, personB, idA, idB);
  }

  /// Căn giữa và zoom vừa vặn để nhìn thấy toàn bộ đường dẫn liên kết giữa 2 người
  void _focusOnPath(List<String> pathIds) {
    if (pathIds.isEmpty || _nodePositions.isEmpty) return;

    final validPositions = pathIds
        .map((id) => _nodePositions[id])
        .where((pos) => pos != null)
        .cast<Offset>()
        .toList();

    if (validPositions.isEmpty) return;

    double minX = validPositions.map((p) => p.dx).reduce(min);
    double maxX = validPositions.map((p) => p.dx).reduce(max);
    double minY = validPositions.map((p) => p.dy).reduce(min);
    double maxY = validPositions.map((p) => p.dy).reduce(max);

    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final viewportHeight = max(200.0, mediaQuery.size.height - 260.0);

    final pathWidth = (maxX - minX) + 240.0;
    final pathHeight = (maxY - minY) + 260.0;
    final scaleX = screenWidth / pathWidth;
    final scaleY = viewportHeight / pathHeight;
    final targetScale = min(1.0, max(0.35, min(scaleX, scaleY)));

    final targetX = (screenWidth / 2) - (centerX * targetScale);
    final targetY = (viewportHeight / 2) - (centerY * targetScale);

    final endMatrix = Matrix4.identity()
      ..setTranslationRaw(targetX, targetY, 0.0)
      ..scaleByDouble(targetScale, targetScale, 1.0, 1.0);

    if (_animationController != null) {
      _animationController!.reset();
      _animation = Matrix4Tween(
        begin: _transformationController.value,
        end: endMatrix,
      ).animate(
        CurvedAnimation(
          parent: _animationController!,
          curve: Curves.easeInOutCubic,
        ),
      );
      _animationController!.forward();
    } else {
      _transformationController.value = endMatrix;
    }
  }

  void _calculateRelationshipLocal(MemberModel personA, MemberModel personB, String idA, String idB) {
    // 1. Kiểm tra vợ chồng trực tiếp
    if (_isSpouseOf(idA, idB)) {
      final isHusband = personA.gender == 'Nam';
      setState(() {
        _relationshipName = isHusband ? "Chồng" : "Vợ";
        _relationshipDetail = null;
        _highlightedPathNodeIds = [idA, idB];
      });
      return;
    }

    // 2. Tìm đường tổ tiên chung gần nhất (LCA)
    final pathA = _getAncestralPath(idA);
    final pathB = _getAncestralPath(idB);

    String? lcaId;
    int depthA = -1;
    int depthB = -1;

    for (int i = 0; i < pathA.length; i++) {
      final ancestor = pathA[i];
      final indexInB = pathB.indexOf(ancestor);
      if (indexInB != -1) {
        lcaId = ancestor;
        depthA = i;
        depthB = indexInB;
        break;
      }
    }

    if (lcaId == null) {
      setState(() {
        _relationshipName = "Họ hàng";
        _relationshipDetail = null;
        _highlightedPathNodeIds = [];
      });
      return;
    }

    String relationship = "";
    if (depthA == 1 && depthB == 0) {
      relationship = personA.gender == 'Nam' ? "Bố ruột" : "Mẹ ruột";
    } else if (depthA == 0 && depthB == 1) {
      relationship = personA.gender == 'Nam' ? "Con trai" : "Con gái";
    } else if (depthA == 2 && depthB == 0) {
      relationship = personA.gender == 'Nam' ? "Ông nội" : "Bà nội";
    } else if (depthA == 0 && depthB == 2) {
      relationship = personA.gender == 'Nam' ? "Cháu nội (Trai)" : "Cháu nội (Gái)";
    } else if (depthA == 3 && depthB == 0) {
      relationship = "Cụ nội";
    } else if (depthA == 0 && depthB == 3) {
      relationship = "Chắt nội";
    } else if (depthA == 1 && depthB == 1) {
      // Anh chị em ruột
      final birthYearA = int.tryParse(personA.dateOfBirth?.split('/').last ?? '0') ?? 0;
      final birthYearB = int.tryParse(personB.dateOfBirth?.split('/').last ?? '0') ?? 0;
      if (birthYearA < birthYearB) {
        relationship = personA.gender == 'Nam' ? "Anh trai" : "Chị gái";
      } else {
        relationship = personA.gender == 'Nam' ? "Em trai" : "Em gái";
      }
    } else if (depthA == 2 && depthB == 1) {
      relationship = "Cháu họ";
    } else if (depthA == 1 && depthB == 2) {
      final parentOfB = _getMember(pathB[1]);
      final birthYearA = int.tryParse(personA.dateOfBirth?.split('/').last ?? '0') ?? 0;
      final birthYearParentB = int.tryParse(parentOfB?.dateOfBirth?.split('/').last ?? '0') ?? 0;

      if (personA.gender == 'Nam') {
        relationship = birthYearA < birthYearParentB ? "Bác (Trai)" : "Chú";
      } else {
        relationship = birthYearA < birthYearParentB ? "Bác (Gái)" : "Cô";
      }
    } else if (depthA == 2 && depthB == 2) {
      relationship = "Anh chị em họ";
    } else {
      relationship = "Họ hàng";
    }

    setState(() {
      _relationshipName = relationship;
      _relationshipDetail = null;
      _highlightedPathNodeIds = _getPathBetween(idA, idB);
    });
  }

  List<String> _getAncestralPath(String id) {
    List<String> path = [id];
    String? currentId = id;
    while (currentId != null) {
      final m = _getMember(currentId);
      if (m == null) break;
      if (m.fatherId != null) {
        path.add(m.fatherId!);
        currentId = m.fatherId;
      } else if (m.motherId != null) {
        path.add(m.motherId!);
        currentId = m.motherId;
      } else {
        break;
      }
    }
    return path;
  }

  List<String> _getPathBetween(String idA, String idB) {
    if (idA == idB) return [idA];

    final pathA = _getAncestralPath(idA);
    final pathB = _getAncestralPath(idB);

    String? lcaId;
    int idxA = -1;
    int idxB = -1;

    for (int i = 0; i < pathA.length; i++) {
      final ancestor = pathA[i];
      final indexInB = pathB.indexOf(ancestor);
      if (indexInB != -1) {
        lcaId = ancestor;
        idxA = i;
        idxB = indexInB;
        break;
      }
    }

    if (lcaId == null) {
      if (_isSpouseOf(idA, idB)) {
        return [idA, idB];
      }
      return [];
    }

    // Đường đi từ A lên LCA (gồm cả LCA)
    final List<String> path = pathA.sublist(0, idxA + 1);
    // Đường đi từ LCA xuống B (không gồm LCA, đảo ngược thứ tự)
    for (int i = idxB - 1; i >= 0; i--) {
      path.add(pathB[i]);
    }

    return path;
  }

  MemberModel? _getMember(String id) {
    try {
      return _allMembers.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  bool _isSpouseOf(String idA, String idB) {
    final mA = _getMember(idA);
    if (mA == null) return false;
    final children = _allMembers.where((m) => m.fatherId == idA || m.motherId == idA);
    for (final child in children) {
      if (child.fatherId == idB || child.motherId == idB) return true;
    }
    return false;
  }

  // ===========================================================================
  // DIALOG CHỌN THÀNH VIÊN
  // ===========================================================================
  void _showMemberSelector(bool isPersonA) {
    String searchQuery = "";
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredList = _allMembers.where((m) {
              if (searchQuery.isEmpty) return true;
              return m.fullName.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              minChildSize: 0.4,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Handle bar
                      Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          isPersonA ? 'Chọn người thứ nhất' : 'Chọn người thứ hai',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Ô tìm kiếm thành viên
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                onChanged: (val) {
                                  setSheetState(() {
                                    searchQuery = val;
                                  });
                                },
                                decoration: const InputDecoration(
                                  hintText: 'Nhập tên tìm kiếm...',
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: filteredList.length,
                          itemBuilder: (context, index) {
                            final m = filteredList[index];
                            final isSelected = isPersonA ? _selectedPersonAId == m.id : _selectedPersonBId == m.id;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: m.gender == 'Nam' ? AppColors.maleBg : AppColors.femaleBg,
                                child: Icon(
                                  Icons.person_rounded,
                                  color: m.gender == 'Nam' ? AppColors.male : AppColors.female,
                                ),
                              ),
                              title: Text(
                                m.fullName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              subtitle: Text('Đời ${m.generation} - Sinh năm ${m.dateOfBirth?.split('/').last ?? 'N/A'}'),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryGold)
                                  : null,
                              onTap: () {
                                setState(() {
                                  if (isPersonA) {
                                    _selectedPersonAId = m.id;
                                  } else {
                                    _selectedPersonBId = m.id;
                                  }
                                  _calculateRelationship();
                                });
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // BUILD METHOD
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    // Tính toán kích thước canvas vẽ cây - sử dụng tọa độ thực tế của các node
    double maxTreeWidth = 200.0;
    double maxTreeHeight = 200.0;

    // Dùng tọa độ thực tế trong _nodePositions để xác định kích thước chính xác
    if (_nodePositions.isNotEmpty) {
      double maxX = 0;
      double maxY = 0;
      for (final pos in _nodePositions.values) {
        if (pos.dx > maxX) maxX = pos.dx;
        if (pos.dy > maxY) maxY = pos.dy;
      }
      // Thêm khoảng đệm cho thẻ thành viên (120px rộng, 125px cao) + padding
      maxTreeWidth = max(maxTreeWidth, maxX + 200.0);
      maxTreeHeight = max(maxTreeHeight, maxY + 200.0);
    } else {
      for (final root in _layoutRoots) {
        maxTreeWidth = max(maxTreeWidth, root.width);
        int maxDepth = _getTreeDepth(root);
        maxTreeHeight = max(maxTreeHeight, maxDepth * 220.0 + 300.0);
      }
    }

    // Thêm khoảng đệm bên ngoài canvas để thoải mái zoom/pan
    final canvasWidth = maxTreeWidth;
    final canvasHeight = maxTreeHeight;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _locateSelf(animated: true),
        backgroundColor: const Color(0xFFFF6D00),
        elevation: 5,
        icon: const Icon(Icons.my_location_rounded, color: Colors.white, size: 20),
        label: const Text(
          'Định vị bản thân',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── App Bar ────────────────────────────────────────────────────────
          _buildAppBar(context),

          // ── Ô Tìm Kiếm Mối Quan Hệ (Màu kem nhạt) ──────────────────────────
          _buildRelationshipCard(),

          // ── Bộ Lọc Theo Đời ────────────────────────────────────────────────
          _buildFilterBar(),

          // ── Khu Vực Vẽ Sơ Đồ Gia Phả (InteractiveViewer) ──────────────────
          Expanded(
            child: _layoutRoots.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : InteractiveViewer(
                    transformationController: _transformationController,
                    constrained: false,
                    boundaryMargin: const EdgeInsets.all(250),
                    minScale: 0.2,
                    maxScale: 2.5,
                    child: Container(
                      width: canvasWidth,
                      height: canvasHeight,
                      color: AppColors.background,
                      child: Stack(
                        children: [
                          // 1. Vẽ các đường nối cây gia phả cơ bản (đường xám + trái tim)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: TreeLinePainter(
                                _layoutRoots,
                                _nodePositions,
                              ),
                            ),
                          ),
                          // 2. Vẽ các thẻ thành viên
                          ..._buildTreeNodes(_layoutRoots),
                          // 3. Vẽ đường Vector màu xanh lá và Mũi tên ĐÈ LÊN TRÊN THẺ THÀNH VIÊN (để không bị che khuất)
                          if (_highlightedPathNodeIds.isNotEmpty || (_selectedPersonAId != null && _selectedPersonBId != null))
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: VectorHighlightPainter(
                                    _highlightedPathNodeIds.isNotEmpty
                                        ? _highlightedPathNodeIds
                                        : _getPathBetween(_selectedPersonAId!, _selectedPersonBId!),
                                    _nodePositions,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TIỂU PHÂN CỦA MÀN HÌNH (WIDGETS)
  // ===========================================================================
  Widget _buildAppBar(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Sơ đồ gia phả',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.family?.name != null)
                  Text(
                    widget.family!.name,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelationshipCard() {
    final personA = _selectedPersonAId != null ? _getMember(_selectedPersonAId!) : null;
    final personB = _selectedPersonBId != null ? _getMember(_selectedPersonBId!) : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tiêu đề nhỏ gọn
          Row(
            children: [
              const Icon(Icons.search_rounded, color: AppColors.primaryMedium, size: 16),
              const SizedBox(width: 6),
              Text(
                'Tìm kiếm mối quan hệ',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Hai bộ chọn người và chữ "Và" ở giữa
          Row(
            children: [
              Expanded(
                child: _buildSelectorButton(
                  title: personA?.fullName ?? 'Chọn người',
                  onTap: () => _showMemberSelector(true),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Và',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryMedium,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: _buildSelectorButton(
                  title: personB?.fullName ?? 'Chọn người',
                  onTap: () => _showMemberSelector(false),
                ),
              ),
            ],
          ),

          // Hiển thị kết quả mối quan hệ thu gọn để tối đa hóa không gian sơ đồ
          if (_selectedPersonAId != null && _selectedPersonBId != null && _relationshipName != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF00C853).withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C853).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.family_restroom_rounded,
                          color: Color(0xFF2E7D32),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                            children: [
                              TextSpan(
                                text: personA?.fullName ?? 'Người 1',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                              ),
                              const TextSpan(text: ' là '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00C853).withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFF00C853).withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    _relationshipName!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FontStyle.italic,
                                      color: Color(0xFF1B5E20),
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ),
                              const TextSpan(text: ' của '),
                              TextSpan(
                                text: personB?.fullName ?? 'Người 2',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
                      ),
                      if (_relationshipDetail != null && _relationshipDetail!.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isDetailExpanded = !_isDetailExpanded;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _isDetailExpanded ? 'Thu gọn' : 'Chi tiết',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: Color(0xFF2E7D32),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Icon(
                                  _isDetailExpanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: const Color(0xFF2E7D32),
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedPersonAId = null;
                            _selectedPersonBId = null;
                            _relationshipName = null;
                            _relationshipDetail = null;
                            _highlightedPathNodeIds = [];
                            _isDetailExpanded = false;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 14),
                        ),
                      ),
                    ],
                  ),
                  if (_relationshipDetail != null && _relationshipDetail!.isNotEmpty && _isDetailExpanded) ...[
                    const Divider(height: 10, thickness: 0.5),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.35),
                        children: [
                          const TextSpan(
                            text: 'Cụ thể: ',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                          ),
                          TextSpan(text: _relationshipDetail!),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildSelectorButton({required String title, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: title == 'Chọn người' ? AppColors.textMuted : AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    // Thu thập danh sách các đời hiện có trong dữ liệu
    final Set<int> availableGens = {};
    for (final m in _allMembers) {
      if (m.generation != null && m.generation! > 0) {
        availableGens.add(m.generation!);
      }
    }
    final sortedGens = availableGens.toList()..sort();

    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_alt_outlined, color: AppColors.primaryMedium, size: 18),
              const SizedBox(width: 6),
              DropdownButton<int?>(
                value: _selectedGenerationFilter,
                underline: const SizedBox(),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 18),
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                items: [
                  const DropdownMenuItem<int?>(
                    value: kFilterFourGenerations,
                    child: Text('4 đời gần nhất (Bản thân)'),
                  ),
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Tất cả thế hệ'),
                  ),
                  ...sortedGens.map(
                    (gen) => DropdownMenuItem<int?>(
                      value: gen,
                      child: Text('Đời thứ $gen'),
                    ),
                  ),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedGenerationFilter = val;
                    _rebuildTree();
                  });
                },
              ),
            ],
          ),
          Row(
            children: [
              // Nút định vị bản thân nhanh
              InkWell(
                onTap: () => _locateSelf(animated: true),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFF6D00).withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.my_location_rounded, color: Color(0xFFFF6D00), size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Tôi',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFE65100),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Nút chú thích truyền thống (Legend)
              GestureDetector(
                onTap: _showLegendBottomSheet,
                child: const Row(
                  children: [
                    Icon(Icons.help_outline_rounded, color: AppColors.textSecondary, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Chú thích',
                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // VẼ CÁC NÚT (NODE WIDGETS)
  // ===========================================================================
  List<Widget> _buildTreeNodes(List<FamilyTreeLayoutNode> nodes) {
    final List<Widget> widgets = [];
    for (final node in nodes) {
      widgets.addAll(_buildSubtreeNodeWidgets(node));
    }
    return widgets;
  }

  List<Widget> _buildSubtreeNodeWidgets(FamilyTreeLayoutNode node) {
    final List<Widget> widgets = [];

    // Tính độ mờ đục nếu có lọc 1 đời cụ thể
    double opacity = 1.0;
    if (_selectedGenerationFilter != null && _selectedGenerationFilter != kFilterFourGenerations) {
      final nodeGen = node.member.generation;
      final spouseGen = node.spouse?.generation;

      final matchNode = nodeGen == _selectedGenerationFilter;
      final matchSpouse = spouseGen == _selectedGenerationFilter;

      if (!matchNode && !matchSpouse) {
        opacity = 0.25;
      }
    }

    // 1. Vẽ node thành viên chính
    widgets.add(
      Positioned(
        left: node.spouse != null ? node.x - 100.0 - 15.0 : node.x - 50.0,
        top: node.y,
        child: Opacity(
          opacity: opacity,
          child: _buildNodeCard(node.member),
        ),
      ),
    );

    // 2. Vẽ node vợ/chồng (nếu có)
    if (node.spouse != null) {
      widgets.add(
        Positioned(
          left: node.x + 15.0,
          top: node.y,
          child: Opacity(
            opacity: opacity,
            child: _buildNodeCard(node.spouse!),
          ),
        ),
      );
    }

    // 3. Đệ quy vẽ con cái
    for (final child in node.children) {
      widgets.addAll(_buildSubtreeNodeWidgets(child));
    }

    return widgets;
  }

  Widget _buildNodeCard(MemberModel member) {
    final isMe = (member.userId != null && member.userId == _currentUser?.id) ||
        (member.id != null && member.id == _currentMember?.id);
    final isPersonA = member.id != null && member.id == _selectedPersonAId;
    final isPersonB = member.id != null && member.id == _selectedPersonBId;
    final isPathSelected = member.id != null && _highlightedPathNodeIds.contains(member.id);

    // Xác định màu viền và màu nền:
    // Bản thân (chủ tài khoản): Màu cam nổi bật (Color(0xFFFF6D00))
    // Người đang tra cứu A / B: Màu xanh lá cây nổi bật (Color(0xFF00C853))
    // Nút liên kết trên đường đi: Màu xanh lá cây dịu (Color(0xFF43A047))
    // Nam: xanh dương. Nữ: hồng.
    final Color borderColor;
    final Color nodeBgColor;
    final double borderWidth;
    if (isPersonA || isPersonB) {
      borderColor = const Color(0xFF00C853);
      nodeBgColor = const Color(0xFFE8F5E9);
      borderWidth = 3.0;
    } else if (isPathSelected) {
      borderColor = const Color(0xFF43A047);
      nodeBgColor = const Color(0xFFF1F8E9);
      borderWidth = 2.5;
    } else if (isMe) {
      borderColor = const Color(0xFFFF6D00);
      nodeBgColor = const Color(0xFFFFF3E0);
      borderWidth = 2.5;
    } else {
      borderColor = member.gender == 'Nam' ? AppColors.male : AppColors.female;
      nodeBgColor = AppColors.white;
      borderWidth = 2.0;
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MemberProfileScreen(
              member: member,
              allMembers: _allMembers,
              onUpdated: (updated) {
                setState(() {
                  final idx = MemberRepository.members.indexWhere((m) => m.id == updated.id);
                  if (idx != -1) {
                    MemberRepository.members[idx] = updated;
                  }
                  _loadData();
                });
              },
              onMemberAdded: (newMember) {
                setState(() {
                  MemberRepository.members.add(newMember);
                  _loadData();
                });
              },
            ),
          ),
        );
      },
      child: Container(
        width: 100,
        height: 125,
        decoration: BoxDecoration(
          color: nodeBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: (isPersonA || isPersonB || isPathSelected)
                  ? const Color(0xFF00C853).withValues(alpha: 0.35)
                  : (isMe
                      ? const Color(0xFFFF6D00).withValues(alpha: 0.28)
                      : Colors.black.withValues(alpha: 0.06)),
              blurRadius: (isPersonA || isPersonB || isPathSelected || isMe) ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Nội dung chính
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isPersonA || isPersonB || isPathSelected)
                          ? const Color(0xFFC8E6C9)
                          : (isMe
                              ? const Color(0xFFFFE0B2)
                              : (member.gender == 'Nam' ? AppColors.maleBg : AppColors.femaleBg)),
                      border: Border.all(
                        color: borderColor.withValues(alpha: 0.8),
                        width: 1.5,
                      ),
                    ),
                    child: ClipOval(
                      child: (member.avatarUrl != null && member.avatarUrl!.isNotEmpty)
                          ? Image.network(
                              member.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.person_rounded,
                                color: (isPersonA || isPersonB || isPathSelected)
                                    ? const Color(0xFF2E7D32)
                                    : (isMe
                                        ? const Color(0xFFFF6D00)
                                        : (member.gender == 'Nam' ? AppColors.male : AppColors.female)),
                                size: 26,
                              ),
                            )
                          : Icon(
                              Icons.person_rounded,
                              color: (isPersonA || isPersonB || isPathSelected)
                                  ? const Color(0xFF2E7D32)
                                  : (isMe
                                      ? const Color(0xFFFF6D00)
                                      : (member.gender == 'Nam' ? AppColors.male : AppColors.female)),
                              size: 26,
                            ),
                    ),
                  ),
                  const SizedBox(height: 7),

                  // Tên thành viên
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      member.fullName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: (isPersonA || isPersonB)
                            ? const Color(0xFF1B5E20)
                            : (isMe ? const Color(0xFFE65100) : AppColors.textPrimary),
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Năm sinh
                  Text(
                    member.dateOfBirth != null && member.dateOfBirth!.isNotEmpty
                        ? member.dateOfBirth!.split('/').last
                        : (member.generation != null ? 'Đời ${member.generation}' : 'N/A'),
                    style: TextStyle(
                      fontSize: 9.0,
                      color: (isPersonA || isPersonB)
                          ? const Color(0xFF2E7D32)
                          : (isMe ? const Color(0xFFBF360C) : AppColors.textSecondary),
                      fontWeight: (isMe || isPersonA || isPersonB) ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),

            // Huy hiệu Người 1 / Người 2 / Liên kết
            if (isPersonA)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C853),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'NGƯỜI 1',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 7.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            else if (isPersonB)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C853),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'NGƯỜI 2',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 7.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            else if (isPathSelected)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF43A047),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.link_rounded,
                    color: Colors.white,
                    size: 11,
                  ),
                ),
              ),

            // Huy hiệu "TÔI" cho chủ tài khoản
            if (isMe)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6D00),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Text(
                    'TÔI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8.0,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _getTreeDepth(FamilyTreeLayoutNode node) {
    if (node.children.isEmpty) return 1;
    int maxChildDepth = 0;
    for (final child in node.children) {
      maxChildDepth = max(maxChildDepth, _getTreeDepth(child));
    }
    return 1 + maxChildDepth;
  }

  // ===========================================================================
  // BOTTOM SHEET CHÚ THÍCH (LEGEND)
  // ===========================================================================
  void _showLegendBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Chú thích sơ đồ',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Divider(),
              const SizedBox(height: 8),
              _buildLegendItem(
                color: const Color(0xFFFF6D00),
                text: 'Bản thân (Chủ tài khoản: ${_currentMember?.fullName ?? "Tôi"})',
                isCircle: true,
              ),
              const SizedBox(height: 12),
              _buildLegendItem(
                color: const Color(0xFF00C853),
                text: 'Đường dẫn & Đối tượng trong quan hệ tra cứu',
                isCircle: false,
              ),
              const SizedBox(height: 12),
              _buildLegendItem(
                color: AppColors.female,
                text: 'Thành viên Nữ',
                isCircle: false,
              ),
              const SizedBox(height: 12),
              _buildLegendItem(
                color: AppColors.male,
                text: 'Thành viên Nam',
                isCircle: false,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 24,
                    alignment: Alignment.center,
                    child: const Icon(Icons.favorite_rounded, color: AppColors.marriageHeart, size: 16),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Vợ chồng (Hôn nhân)',
                    style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem({required Color color, required String text, required bool isCircle}) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isCircle ? null : BorderRadius.circular(6),
            border: Border.all(color: color, width: 2),
          ),
          child: isCircle
              ? Center(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 14),
        Text(
          text,
          style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

// ===========================================================================
// LỚP DỰNG TỌA ĐỘ VÀ VẼ CẠNH GIA PHẢ
// ===========================================================================
class FamilyTreeLayoutNode {
  final MemberModel member;
  final MemberModel? spouse;
  final List<FamilyTreeLayoutNode> children;

  double x = 0;
  double y = 0;
  double width = 0;

  FamilyTreeLayoutNode({
    required this.member,
    this.spouse,
    required this.children,
  });
}

class TreeLinePainter extends CustomPainter {
  final List<FamilyTreeLayoutNode> roots;
  final Map<String, Offset> nodePositions;

  TreeLinePainter(this.roots, this.nodePositions);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.treeLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final heartPaint = Paint()
      ..color = AppColors.marriageHeart
      ..style = PaintingStyle.fill;

    for (final root in roots) {
      _drawLines(canvas, root, paint, heartPaint);
    }
  }

  void _drawLines(Canvas canvas, FamilyTreeLayoutNode node, Paint paint, Paint heartPaint) {
    double coupleYCenter = node.y + 62.5; // Y center of the 125-high node

    if (node.spouse != null) {
      // Vẽ đường kết nối ngang giữa vợ chồng
      double husbandXRight = node.x - 15;
      double wifeXLeft = node.x + 15;
      canvas.drawLine(Offset(husbandXRight, coupleYCenter), Offset(wifeXLeft, coupleYCenter), paint);

      // Vẽ trái tim đỏ ở giữa
      _drawHeart(canvas, Offset(node.x, coupleYCenter - 3), heartPaint);
    }

    if (node.children.isNotEmpty) {
      double startY = coupleYCenter;
      double breakY = node.y + 125 + 30; // 30px dưới đáy của node cha mẹ

      // Vẽ đường thẳng từ liên kết hôn nhân đi xuống
      canvas.drawLine(Offset(node.x, startY), Offset(node.x, breakY), paint);

      // Lấy X nhỏ nhất và lớn nhất của con cái để vẽ thanh ngang
      double minX = node.children.map((c) => c.x).reduce(min);
      double maxX = node.children.map((c) => c.x).reduce(max);
      canvas.drawLine(Offset(minX, breakY), Offset(maxX, breakY), paint);

      // Vẽ các đường dọc đi xuống từng con
      for (final child in node.children) {
        canvas.drawLine(Offset(child.x, breakY), Offset(child.x, child.y), paint);

        // Đệ quy vẽ tiếp cho cây con
        _drawLines(canvas, child, paint, heartPaint);
      }
    }
  }

  void _drawHeart(Canvas canvas, Offset center, Paint paint) {
    final path = Path();
    double width = 8;
    double height = 8;
    
    path.moveTo(center.dx, center.dy + height / 4);
    path.cubicTo(center.dx - width / 2, center.dy - height / 2,
                 center.dx - width, center.dy + height / 4,
                 center.dx, center.dy + height);
    path.cubicTo(center.dx + width, center.dy + height / 4,
                 center.dx + width / 2, center.dy - height / 2,
                 center.dx, center.dy + height / 4);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ===========================================================================
// LỚP VẼ ĐƯỜNG VECTOR VÀ MŨI TÊN CHỈ HƯỚNG QUAN HỆ (LAYER NẰM TRÊN CÙNG)
// ===========================================================================
class VectorHighlightPainter extends CustomPainter {
  final List<String> highlightPath;
  final Map<String, Offset> nodePositions;

  VectorHighlightPainter(this.highlightPath, this.nodePositions);

  @override
  void paint(Canvas canvas, Size size) {
    if (highlightPath.length < 2) return;

    // 1. Viền phát sáng Neon cho đường vector
    final glowVectorPaint = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 2. Đường vector thẳng màu xanh lục nổi bật
    final vectorPaint = Paint()
      ..color = const Color(0xFF00C853) // Màu xanh lá cây chuẩn Material
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 3. Điểm chấm tròn phát sáng tại tâm mỗi nút
    final dotGlowPaint = Paint()
      ..color = const Color(0xFF00E676)
      ..style = PaintingStyle.fill;

    final dotSolidPaint = Paint()
      ..color = const Color(0xFF00C853)
      ..style = PaintingStyle.fill;

    final dotCenterWhite = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Vẽ các đoạn vector thẳng nối trực tiếp lần lượt từ A qua các người trung gian đến F
    for (int i = 0; i < highlightPath.length - 1; i++) {
      final id1 = highlightPath[i];
      final id2 = highlightPath[i + 1];

      final pos1 = nodePositions[id1];
      final pos2 = nodePositions[id2];

      if (pos1 != null && pos2 != null) {
        // Lớp phát sáng viền ngoài
        canvas.drawLine(pos1, pos2, glowVectorPaint);
        // Đường vector thẳng chính
        canvas.drawLine(pos1, pos2, vectorPaint);

        // Vẽ mũi tên chỉ hướng vector từ id1 sang id2
        _drawVectorArrow(canvas, pos1, pos2);
      }
    }

    // Vẽ điểm nối tròn nổi bật ở tất cả các nút trên đường đi
    for (final id in highlightPath) {
      final pos = nodePositions[id];
      if (pos != null) {
        canvas.drawCircle(pos, 9.0, dotGlowPaint);
        canvas.drawCircle(pos, 6.5, dotSolidPaint);
        canvas.drawCircle(pos, 3.0, dotCenterWhite);
      }
    }
  }

  void _drawVectorArrow(Canvas canvas, Offset from, Offset to) {
    final double dx = to.dx - from.dx;
    final double dy = to.dy - from.dy;
    final double distance = sqrt(dx * dx + dy * dy);
    if (distance < 5.0) return; // Luôn luôn vẽ mũi tên kể cả khoảng cách gần

    final double uX = dx / distance;
    final double uY = dy / distance;
    final double nX = -uY;
    final double nY = uX;

    // Đặt mũi tên tại trung điểm 50% quãng đường
    final double midX = from.dx + dx * 0.5;
    final double midY = from.dy + dy * 0.5;

    const double arrowHeadLen = 18.0;
    const double arrowHeadWidth = 10.0;

    // Đỉnh nhọn phía trước mũi tên
    final double tipX = midX + arrowHeadLen * 0.5 * uX;
    final double tipY = midY + arrowHeadLen * 0.5 * uY;

    // Cánh trái
    final double leftX = tipX - arrowHeadLen * uX + arrowHeadWidth * nX;
    final double leftY = tipY - arrowHeadLen * uY + arrowHeadWidth * nY;

    // Điểm khuyết đuôi mũi tên
    final double notchX = tipX - (arrowHeadLen * 0.6) * uX;
    final double notchY = tipY - (arrowHeadLen * 0.6) * uY;

    // Cánh phải
    final double rightX = tipX - arrowHeadLen * uX - arrowHeadWidth * nX;
    final double rightY = tipY - arrowHeadLen * uY - arrowHeadWidth * nY;

    final arrowPath = Path()
      ..moveTo(tipX, tipY)
      ..lineTo(leftX, leftY)
      ..lineTo(notchX, notchY)
      ..lineTo(rightX, rightY)
      ..close();

    // 1. Viền phát sáng Neon cho mũi tên
    final arrowGlowPaint = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    // 2. Mũi tên chính màu xanh lục đậm
    final arrowSolidPaint = Paint()
      ..color = const Color(0xFF00C853)
      ..style = PaintingStyle.fill;

    // 3. Viền mảnh trắng tạo độ tương phản cao, nổi bật trên mọi thẻ
    final arrowBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawPath(arrowPath, arrowGlowPaint);
    canvas.drawPath(arrowPath, arrowSolidPaint);
    canvas.drawPath(arrowPath, arrowBorderPaint);
  }

  @override
  bool shouldRepaint(covariant VectorHighlightPainter oldDelegate) {
    return oldDelegate.highlightPath != highlightPath ||
        oldDelegate.nodePositions != nodePositions;
  }
}
