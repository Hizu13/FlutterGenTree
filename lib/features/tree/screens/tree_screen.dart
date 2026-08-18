import 'package:flutter/material.dart';
import 'dart:math';
import '../../../config/app_color.dart';
import '../../member/models/member_model.dart';
import '../../member/repositories/member_repository.dart';
import '../../member/screens/member_profile_screen.dart';

class TreeScreen extends StatefulWidget {
  const TreeScreen({super.key});

  @override
  State<TreeScreen> createState() => _TreeScreenState();
}

class _TreeScreenState extends State<TreeScreen> {
  List<MemberModel> _allMembers = [];
  List<FamilyTreeLayoutNode> _layoutRoots = [];

  // Dropdown chọn thành viên A và B để tìm quan hệ
  String? _selectedPersonAId;
  String? _selectedPersonBId;
  String? _relationshipName;

  // Bộ lọc theo thế hệ (đời)
  int? _selectedGenerationFilter; // null = Tất cả, 2, 3, 4, 5...

  // Bản đồ lưu trữ tọa độ của các thành viên để vẽ đường nối nổi bật
  final Map<String, Offset> _nodePositions = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _nodePositions.clear();
      _allMembers = MemberRepository.members;
      _layoutRoots = _buildLayoutTrees(_allMembers);
    });
  }

  // ===========================================================================
  // XÂY DỰNG CẤU TRÚC PHẢ HỆ
  // ===========================================================================
  List<FamilyTreeLayoutNode> _buildLayoutTrees(List<MemberModel> members) {
    // Tìm các ứng viên là nút gốc (không có cha và mẹ trong dữ liệu)
    final candidates = members.where((m) => m.fatherId == null && m.motherId == null).toList();

    final List<MemberModel> roots = [];
    final Set<String> processedSpouses = {};

    for (final c in candidates) {
      if (processedSpouses.contains(c.id)) continue;

      // Tìm vợ/chồng của candidate này
      MemberModel? spouse;
      final children = members.where((m) => m.fatherId == c.id || m.motherId == c.id);
      for (final child in children) {
        if (c.gender == 'Nam' && child.motherId != null) {
          spouse = candidates.firstWhere((m) => m.id == child.motherId, orElse: () => c);
          if (spouse != c) break;
        } else if (c.gender == 'Nữ' && child.fatherId != null) {
          spouse = candidates.firstWhere((m) => m.id == child.fatherId, orElse: () => c);
          if (spouse != c) break;
        }
      }

      if (spouse != null && spouse != c) {
        processedSpouses.add(spouse.id!);
        if (c.gender == 'Nam') {
          roots.add(c);
        } else {
          roots.add(spouse);
        }
      } else {
        roots.add(c);
      }
    }

    // Đệ quy xây dựng cây phả đồ cho các gốc
    final List<FamilyTreeLayoutNode> layoutTrees = [];
    for (final r in roots) {
      layoutTrees.add(_buildSubtree(r, members));
    }

    // Tính toán độ rộng và vị trí cho cây phả đồ
    double currentLeft = 50.0;
    for (final tree in layoutTrees) {
      _computeWidths(tree);
      _computePositions(tree, currentLeft, 0);
      currentLeft += tree.width + 100.0; // Khoảng cách giữa các cây gia phả nếu có nhiều hơn 1 họ tộc gốc
    }

    return layoutTrees;
  }

  FamilyTreeLayoutNode _buildSubtree(MemberModel m, List<MemberModel> members) {
    MemberModel? spouse;
    final children = members.where((child) => child.fatherId == m.id || child.motherId == m.id).toList();

    for (final child in children) {
      if (m.gender == 'Nam' && child.motherId != null) {
        try {
          spouse = members.firstWhere((item) => item.id == child.motherId);
          break;
        } catch (_) {}
      } else if (m.gender == 'Nữ' && child.fatherId != null) {
        try {
          spouse = members.firstWhere((item) => item.id == child.fatherId);
          break;
        } catch (_) {}
      }
    }

    // Tìm vợ chồng phụ nếu không có con (dựa trên spouses danh sách)
    // Dữ liệu hiện tại chủ yếu qua con cái.

    final List<FamilyTreeLayoutNode> childrenNodes = [];
    // Chỉ đệ quy vẽ con cái của cặp vợ chồng này
    for (final child in children) {
      // Để tránh lặp khi duyệt cả cha và mẹ, ta chỉ duyệt đệ quy theo nhánh huyết thống (ở đây là cha mẹ gốc)
      // Con cái sẽ được xử lý đệ quy
      childrenNodes.add(_buildSubtree(child, members));
    }

    // Lọc con trùng lặp (nếu con có cả bố và mẹ, chỉ thêm con một lần từ phía người đi trước)
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
  void _calculateRelationship() {
    if (_selectedPersonAId == null || _selectedPersonBId == null) {
      setState(() {
        _relationshipName = null;
      });
      return;
    }

    final idA = _selectedPersonAId!;
    final idB = _selectedPersonBId!;

    if (idA == idB) {
      setState(() {
        _relationshipName = "Cùng một người";
      });
      return;
    }

    final personA = _getMember(idA);
    final personB = _getMember(idB);
    if (personA == null || personB == null) return;

    // 1. Kiểm tra vợ chồng trực tiếp
    if (_isSpouseOf(idA, idB)) {
      final isHusband = personA.gender == 'Nam';
      setState(() {
        _relationshipName = isHusband ? "Chồng" : "Vợ";
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
    // Tính toán kích thước canvas vẽ cây
    double maxTreeWidth = 200.0;
    double maxTreeHeight = 200.0;

    for (final root in _layoutRoots) {
      maxTreeWidth = max(maxTreeWidth, root.width);
      // Tìm độ sâu lớn nhất của cây
      int maxDepth = _getTreeDepth(root);
      maxTreeHeight = max(maxTreeHeight, maxDepth * 220.0 + 300.0);
    }

    // Thêm khoảng đệm bên ngoài canvas để thoải mái zoom/pan
    final canvasWidth = maxTreeWidth + 200.0;
    final canvasHeight = maxTreeHeight;

    return Scaffold(
      backgroundColor: AppColors.background,
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
                    constrained: false,
                    boundaryMargin: const EdgeInsets.all(150),
                    minScale: 0.3,
                    maxScale: 2.0,
                    child: Container(
                      width: canvasWidth,
                      height: canvasHeight,
                      color: AppColors.background,
                      child: Stack(
                        children: [
                          // Vẽ các đường nối
                          Positioned.fill(
                            child: CustomPaint(
                              painter: TreeLinePainter(
                                _layoutRoots,
                                (_selectedPersonAId != null && _selectedPersonBId != null)
                                    ? _getPathBetween(_selectedPersonAId!, _selectedPersonBId!)
                                    : const [],
                                _nodePositions,
                              ),
                            ),
                          ),
                          // Vẽ các Node đại diện cho các thành viên
                          ..._buildTreeNodes(_layoutRoots),
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
          const Text(
            'Sơ đồ gia phả',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
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
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề nhỏ
          Row(
            children: [
              const Icon(Icons.search_rounded, color: AppColors.primaryMedium, size: 20),
              const SizedBox(width: 8),
              Text(
                'Tìm kiếm mối quan hệ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

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
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Và',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryMedium,
                    fontSize: 13,
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

          // Hiển thị kết quả mối quan hệ y như hình ảnh
          if (_selectedPersonAId != null && _selectedPersonBId != null && _relationshipName != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textPrimary,
                        ),
                        children: [
                          const TextSpan(
                            text: 'Kết quả: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: '${personA?.fullName} là '),
                          TextSpan(
                            text: _relationshipName!.toLowerCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryMedium,
                            ),
                          ),
                          TextSpan(text: ' của ${personB?.fullName}'),
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
                      });
                    },
                    child: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                  ),
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: title == 'Chọn người' ? AppColors.textMuted : AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
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
                hint: const Text(
                  'Bộ lọc theo đời',
                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                ),
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Tất cả thế hệ'),
                  ),
                  const DropdownMenuItem<int?>(
                    value: 2,
                    child: Text('Đời thứ 2'),
                  ),
                  const DropdownMenuItem<int?>(
                    value: 3,
                    child: Text('Đời thứ 3'),
                  ),
                  const DropdownMenuItem<int?>(
                    value: 4,
                    child: Text('Đời thứ 4'),
                  ),
                  const DropdownMenuItem<int?>(
                    value: 5,
                    child: Text('Đời thứ 5'),
                  ),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedGenerationFilter = val;
                  });
                },
              ),
            ],
          ),
          // Nút chú thích truyền thống (Legend)
          GestureDetector(
            onTap: _showLegendBottomSheet,
            child: Row(
              children: [
                Icon(Icons.help_outline_rounded, color: AppColors.textSecondary, size: 16),
                const SizedBox(width: 4),
                const Text(
                  'Chú thích',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          )
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

    // Tính độ mờ đục nếu có lọc đời
    double opacity = 1.0;
    if (_selectedGenerationFilter != null) {
      final nodeGen = node.member.generation;
      final spouseGen = node.spouse?.generation;

      // Nếu không khớp với đời được lọc, làm mờ đi
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
    // Xác định màu viền:
    // Bản thân Nguyễn Văn An (id = '9') sẽ viền cam.
    // Nam viền xanh dương. Nữ viền hồng.
    Color borderColor = member.gender == 'Nam' ? AppColors.male : AppColors.female;
    if (member.id == '9') {
      borderColor = AppColors.selfNode;
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
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: member.gender == 'Nam' ? AppColors.maleBg : AppColors.femaleBg,
                border: Border.all(
                  color: borderColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.person_outline_rounded,
                color: member.id == '9' ? AppColors.selfNode : (member.gender == 'Nam' ? AppColors.male : AppColors.female),
                size: 26,
              ),
            ),
            const SizedBox(height: 8),

            // Tên thành viên
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                member.fullName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 2),

            // Năm sinh
            Text(
              member.dateOfBirth != null && member.dateOfBirth!.isNotEmpty
                  ? member.dateOfBirth!.split('/').last
                  : 'N/A',
              style: const TextStyle(
                fontSize: 9.0,
                color: AppColors.textSecondary,
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
                color: AppColors.selfNode,
                text: 'Bản thân (Nguyễn Văn An)',
                isCircle: true,
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
  final List<String> highlightPath;
  final Map<String, Offset> nodePositions;

  TreeLinePainter(this.roots, this.highlightPath, this.nodePositions);

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

    // Vẽ đường nối nổi bật màu xanh lục trực quan nối giữa 2 người đang tìm kiếm quan hệ
    if (highlightPath.length > 1) {
      final highlightPaint = Paint()
        ..color = const Color(0xFF00FF00) // Màu xanh lục lá cây nổi bật y như hình ảnh
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5 // Dày hơn đường thường để dễ phân biệt
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < highlightPath.length - 1; i++) {
        final id1 = highlightPath[i];
        final id2 = highlightPath[i + 1];

        final pos1 = nodePositions[id1];
        final pos2 = nodePositions[id2];

        if (pos1 != null && pos2 != null) {
          // Khác tầng thế hệ (quan hệ cha mẹ - con cái)
          if ((pos1.dy - pos2.dy).abs() > 50.0) {
            final higher = pos1.dy < pos2.dy ? pos1 : pos2;
            final lower = pos1.dy < pos2.dy ? pos2 : pos1;
            
            // Vẽ trực tiếp nối từ mép dưới node cha/mẹ sang mép trên node con
            canvas.drawLine(
              Offset(higher.dx, higher.dy + 62.5),
              Offset(lower.dx, lower.dy - 62.5),
              highlightPaint,
            );
          } else {
            // Cùng tầng thế hệ (quan hệ vợ chồng)
            canvas.drawLine(pos1, pos2, highlightPaint);
          }
        }
      }
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
