# routers/relationship_service.py
# Module tra cứu & giải thích mối quan hệ huyết thống tiếng Việt
from sqlalchemy.orm import Session
from models import Member, User
from db.neo4j_connection import find_shortest_path
from typing import Optional, Dict, Any, List
from collections import deque

Person = Member

def _find_path_mysql(from_id: int, to_id: int, db: Session):
    """Tìm đường đi ngắn nhất qua MySQL khi Neo4j chưa có node hoặc chưa kết nối."""
    if from_id == to_id:
        p = db.query(Member).filter(Member.id == from_id).first()
        if not p:
            return None
        name = f"{p.last_name or ''} {p.first_name or ''}".strip()
        return {
            'nodes': [{'id': p.id, 'name': name, 'gender': p.gender}],
            'rels': []
        }

    start_member = db.query(Member).filter(Member.id == from_id).first()
    if not start_member:
        return None

    family_members = db.query(Member).filter(Member.family_id == start_member.family_id).all() if start_member.family_id else db.query(Member).all()
    mem_map = {m.id: m for m in family_members}
    if to_id not in mem_map:
        to_m = db.query(Member).filter(Member.id == to_id).first()
        if to_m:
            mem_map[to_m.id] = to_m
        else:
            return None

    adj = {m_id: [] for m_id in mem_map}
    for m_id, m in mem_map.items():
        if m.father_id and m.father_id in mem_map:
            adj[m.father_id].append((m_id, {'start': m.father_id, 'end': m_id, 'type': 'FATHER_OF'}))
            adj[m_id].append((m.father_id, {'start': m.father_id, 'end': m_id, 'type': 'FATHER_OF'}))
        if m.mother_id and m.mother_id in mem_map:
            adj[m.mother_id].append((m_id, {'start': m.mother_id, 'end': m_id, 'type': 'MOTHER_OF'}))
            adj[m_id].append((m.mother_id, {'start': m.mother_id, 'end': m_id, 'type': 'MOTHER_OF'}))

    for m_id, m in mem_map.items():
        if m.father_id and m.mother_id and m.father_id in mem_map and m.mother_id in mem_map:
            f_id = m.father_id
            m_id_mom = m.mother_id
            if not any(n == m_id_mom and r['type'] == 'SPOUSE' for n, r in adj[f_id]):
                adj[f_id].append((m_id_mom, {'start': f_id, 'end': m_id_mom, 'type': 'SPOUSE'}))
                adj[m_id_mom].append((f_id, {'start': f_id, 'end': m_id_mom, 'type': 'SPOUSE'}))

    queue = deque([[from_id]])
    visited = {from_id}
    parent_edge = {}

    found_path_nodes = None
    while queue:
        path = queue.popleft()
        curr = path[-1]
        if curr == to_id:
            found_path_nodes = path
            break
        for neighbor, edge in adj.get(curr, []):
            if neighbor not in visited:
                visited.add(neighbor)
                parent_edge[(curr, neighbor)] = edge
                queue.append(path + [neighbor])

    if not found_path_nodes:
        return None

    nodes = []
    for n_id in found_path_nodes:
        m = mem_map[n_id]
        name = f"{m.last_name or ''} {m.first_name or ''}".strip()
        nodes.append({'id': m.id, 'name': name, 'gender': m.gender or 'male'})

    rels = []
    for i in range(len(found_path_nodes) - 1):
        u, v = found_path_nodes[i], found_path_nodes[i+1]
        edge = parent_edge.get((u, v))
        if edge:
            rels.append(edge)
        else:
            rels.append({'start': u, 'end': v, 'type': 'RELATED'})

    return {'nodes': nodes, 'rels': rels}




def calculate_relationship_path(
    from_id: int,
    to_id: int,
    db: Session,
) -> dict:
    if not from_id or not to_id:
        return {"relationship": "Thiếu thông tin người cần tra cứu", "path": []}

    path = None
    try:
        path = find_shortest_path(from_id, to_id)
    except Exception as e:
        print(f"[!] Neo4j shortest path query failed: {e}")
    if not path:
        path = _find_path_mysql(from_id, to_id, db)
    if not path:
         return {"relationship": "Không tìm thấy mối quan hệ"}
         
    # Cấu trúc đường đi: {'nodes': [{id, name, gender}, ...], 'rels': [{start, end, type}, ...]}
    nodes = path['nodes']
    rels = path['rels']
    
    # --- HÀM TỔNG HỢP QUAN HỆ (MỤC 3 EXPLANATION) ---
    def get_summary_term(nodes, rels):
        n_steps = len(rels)
        
        # Kiểm tra mối quan hệ VỢ/CHỒNG (1 bước, trực tiếp)
        if n_steps == 1 and rels[0]['type'] == 'SPOUSE':
            gender = nodes[0].get('gender')
            is_male = gender in ['male', 'nam']
            return "Chồng" if is_male else "Vợ"
        
        # directions: 1 nếu n[i] là cha/mẹ n[i+1], -1 nếu n[i] là con n[i+1]
        dirs = []
        for i in range(n_steps):
            rel_type = rels[i]['type']
            # Xử lý VỢ/CHỒNG riêng (hướng trung lập)
            if rel_type == 'SPOUSE':
                dirs.append(0)  # Trung lập đối với VỢ/CHỒNG
            elif rels[i]['start'] == nodes[i]['id']:
                dirs.append(1)
            else:
                dirs.append(-1)
        
        
        start_gender = nodes[0].get('gender')
        is_male = start_gender == 'male' or start_gender == 'nam'
        
        # 1. Quan hệ trực hệ đi xuống (Tổ tiên -> Hậu duệ): dirs = [1, 1, ...]
        # Ví dụ: Cha/Mẹ -> Con, Ông/Bà -> Cháu
        # Đây là khi nodes[0] -> nodes[1] theo chiều FATHER_OF hoặc MOTHER_OF
        if all(d == 1 for d in dirs):
            if n_steps == 1:
                # Kiểm tra relationship type để xác định chính xác
                rel_type = rels[0]['type']
                if rel_type == 'FATHER_OF':
                    return "Cha"
                elif rel_type == 'MOTHER_OF':
                    return "Mẹ"
                else:
                    # Kiểm tra giới tính để xác định chính xác
                    return "Cha" if is_male else "Mẹ"
                    
            if n_steps == 2:
                # Ông/Bà -> Cha/Mẹ -> Cháu
                # Xác định nội/ngoại dựa vào người ở giữa
                mid_gender = nodes[1].get('gender')
                is_paternal_side = (mid_gender == 'male' or mid_gender == 'nam')
                side = "nội" if is_paternal_side else "ngoại"
                
                return f"Ông {side}" if is_male else f"Bà {side}"
                    
            if n_steps == 3: 
                return "Cụ "
            if n_steps == 4: 
                return "Kị"
            if n_steps == 5: 
                return "Thiên Tổ"
            if n_steps == 6: 
                return "Liệt Tổ"
            if n_steps == 7: 
                return "Tổ tiên đời thứ 7"
            if n_steps == 8: 
                return "Tổ tiên đời thứ 8"
            if n_steps == 9: 
                return "Tổ tiên đời thứ 9" 
            return f"Tổ tiên ({n_steps} đời)"

        # 2. Quan hệ trực hệ đi lên (Hậu duệ -> Tổ tiên): dirs = [-1, -1, ...]
        # Ví dụ: Con -> Cha/Mẹ, Cháu -> Ông/Bà
        # Đây là khi nodes[0] <- nodes[1] (ngược chiều relationship)
        if all(d == -1 for d in dirs):
            if n_steps == 1: 
                return "Con trai" if is_male else "Con gái"
            if n_steps == 2: 
                return "Cháu trai" if is_male else "Cháu gái"
            if n_steps == 3: 
                return "Chắt (Tằng Tôn)"
            if n_steps == 4: 
                return "Chút (Huyền Tôn)" 
            if n_steps == 5: 
                return "Lai Tôn" 
            if n_steps == 6: 
                return "Côn Tôn" 
            if n_steps == 7: 
                return "Nhưng Tôn" 
            if n_steps == 8: 
                return "Vân Tôn" 
            if n_steps == 9: 
                return "Nhĩ Tôn" 
            return f"Hậu duệ ({n_steps} đời)"

        # 3. Quan hệ ngang (Anh chị em)
        if dirs == [-1, 1]:
            # Kiểm tra ngày sinh để xác định anh/chị hay em
            # Lấy dữ liệu cá nhân từ DB để lấy ngày sinh
            try:
                p1 = db.query(Person).filter(Person.id == nodes[0]['id']).first()
                p2 = db.query(Person).filter(Person.id == nodes[-1]['id']).first()
                
                if p1 and p2:
                    # Xác định ai là người lớn tuổi hơn
                    is_older = False
                    if p1.date_of_birth and p2.date_of_birth:
                        is_older = p1.date_of_birth < p2.date_of_birth
                    else:
                        is_older = p1.id < p2.id  # Mặc định: ID nhỏ hơn = lớn tuổi hơn
                    
                    gender = nodes[0].get('gender')
                    is_male = gender in ['male', 'nam']
                    
                    if is_older:
                        return "Anh ruột" if is_male else "Chị ruột"
                    else:
                        return "Em trai ruột" if is_male else "Em gái ruột"
            except:
                pass
            return "Anh/Chị/Em"
        
        # 4. Quan hệ Bác/Chú/Cô/Dì (Parent's sibling)
        # nodes[0] is uncle/aunt, nodes[-1] is nephew/niece
        # Pattern: Uncle/Aunt -> GP -> Parent -> Child
        # dirs = [-1, 1, 1]: đi lên ông bà, sau đó đi xuống cha mẹ, sau đó đi xuống con
        if n_steps == 3 and dirs == [-1, 1, 1]:
            # Đây là mối quan hệ Bác/Chú/Cô/Dì (từ góc nhìn của Bác/Chú/Cô/Dì)
            # nodes[0] = Bác/Chú/Cô/Dì, nodes[-1] = Cháu trai/Cháu gái
            # Cần xác định loại mối quan hệ dựa trên giới tính của Bác/Chú/Cô/Dì, tuổi so với cha mẹ và giới tính của cha mẹ
            try:
                uncle_node = nodes[0]
                parent_node = nodes[2]  
                
                # Lấy ngày sinh để so sánh
                uncle = db.query(Person).filter(Person.id == uncle_node['id']).first()
                parent = db.query(Person).filter(Person.id == parent_node['id']).first()
                
                if uncle and parent:
                    # Xác định xem Bác/Chú/Cô/Dì có lớn tuổi hơn cha mẹ không (anh chị em của họ)
                    is_uncle_older_than_parent = False
                    if uncle.date_of_birth and parent.date_of_birth:
                        is_uncle_older_than_parent = uncle.date_of_birth < parent.date_of_birth
                    else:
                        is_uncle_older_than_parent = uncle.id < parent.id
                    
                    uncle_gender = uncle_node.get('gender')
                    is_male = uncle_gender in ['male', 'nam']
                    parent_gender = parent_node.get('gender')
                    parent_is_male = parent_gender in ['male', 'nam']
                    
                    # Xác định mối quan hệ dựa trên bên của cha mẹ và tuổi/giới tính của Bác/Chú/Cô/Dì
                    if parent_is_male:
                        # Bên nội
                        if is_uncle_older_than_parent:
                            # Anh chị em lớn tuổi hơn của cha = Bác (cả nam và nữ)
                            return "Bác"
                        else:
                            # Em trai/em gái của cha
                            if is_male:
                                return "Chú"
                            else:
                                return "Cô"
                    else:
                        # Bên ngoại
                        if is_uncle_older_than_parent:
                             # Anh chị em lớn tuổi hơn của mẹ
                            return "Bác"
                        else:
                            # Em trai/em gái của mẹ
                            if is_male:
                                return "Cậu"
                            else:
                                return "Dì"
            except:
                pass
                
            return "Bác/Chú/Cô/Dì/Cậu"
        
        # 5. Mối quan hệ Cháu trai/Cháu gái (ngược lại với Bác/Chú/Cô/Dì)
        # nodes[0] là Cháu trai/Cháu gái, nodes[-1] là Bác/Chú/Cô/Dì
        # Pattern: Cháu trai/Cháu gái -> Cha mẹ -> Ông bà -> Bác/Chú/Cô/Dì
        # dirs = [-1, -1, 1] có nghĩa là: đi lên cha mẹ, đi lên ông bà, sau đó đi ngang sang Bác/Chú/Cô/Dì
        if n_steps == 3 and dirs == [-1, -1, 1]:
            # Đây là mối quan hệ Cháu trai/Cháu gái từ góc nhìn của họ khi nhìn Bác/Chú/Cô/Dì
            try:
                nephew_node = nodes[0]  # The person making the query
                nephew = db.query(Person).filter(Person.id == nephew_node['id']).first()
                
                if nephew:
                    nephew_gender = nephew_node.get('gender')
                    is_male = nephew_gender in ['male', 'nam']
                    
                    return "Cháu trai" if is_male else "Cháu gái"
            except:
                pass
            
            return "Cháu"

        # Xử lý cả hướng ngược lại cho Bác/Chú/Cô/Dì
        # Pattern: Con -> Cha mẹ -> Ông bà -> Bác/Chú/Cô/Dì
        # dirs = [1, 1, -1]
        if n_steps == 3 and dirs == [1, 1, -1]:
            # Đây cũng là Bác/Chú/Cô/Dì nhưng đường đi theo hướng khác
            try:
                uncle_node = nodes[-1]
                parent_node = nodes[-2]
                
                uncle = db.query(Person).filter(Person.id == uncle_node['id']).first()
                parent = db.query(Person).filter(Person.id == parent_node['id']).first()
                
                print(f"DEBUG Uncle/Aunt: nephew={nodes[0].get('name')}, parent={parent_node.get('name')}, uncle={uncle_node.get('name')}")
                
                if uncle and parent:
                    # Kiểm tra xem Bác/Chú/Cô/Dì và cha mẹ có phải là anh chị em ruột không (cùng cha hoặc cùng mẹ)
                    are_siblings = (
                        (uncle.father_id and parent.father_id and uncle.father_id == parent.father_id) or
                        (uncle.mother_id and parent.mother_id and uncle.mother_id == parent.mother_id)
                    )
                    
                    print(f"DEBUG: are_siblings={are_siblings}, uncle.father_id={uncle.father_id}, parent.father_id={parent.father_id}")
                    
                    if are_siblings:
                        # Anh chị em ruột - sử dụng so sánh ngày sinh
                        is_uncle_older_than_parent = False
                        if uncle.date_of_birth and parent.date_of_birth:
                            is_uncle_older_than_parent = uncle.date_of_birth < parent.date_of_birth
                        else:
                            is_uncle_older_than_parent = uncle.id < parent.id
                    else:
                        # KHÔNG phải anh chị em ruột - họ có thể là anh em họ
                        # Tìm mối quan hệ giữa Bác/Chú/Cô/Dì và cha mẹ để xác định thứ bậc
                        print(f"DEBUG: NOT siblings, finding path between uncle {uncle.id} and parent {parent.id}")
                        uncle_parent_path = find_shortest_path(uncle.id, parent.id)
                        
                        if uncle_parent_path:
                            up_nodes = uncle_parent_path['nodes']
                            up_rels = uncle_parent_path['rels']
                            uncle_to_parent_term = get_summary_term(up_nodes, up_rels)
                            
                            print(f"DEBUG: uncle_to_parent_term='{uncle_to_parent_term}'")
                            
                            # Nếu Bác/Chú/Cô/Dì là "Anh họ" của cha -> Bác/Chú/Cô/Dì có thứ bậc cao hơn
                            # Nếu Bác/Chú/Cô/Dì là "Em họ" của cha -> Bác/Chú/Cô/Dì có thứ bậc thấp hơn
                            if uncle_to_parent_term and "Anh" in uncle_to_parent_term:
                                is_uncle_older_than_parent = True
                            elif uncle_to_parent_term and "Em" in uncle_to_parent_term:
                                is_uncle_older_than_parent = False
                            else:
                                # Mặc định sử dụng so sánh ID
                                is_uncle_older_than_parent = uncle.id < parent.id
                        else:
                            # Không tìm thấy đường đi, mặc định sử dụng ID
                            is_uncle_older_than_parent = uncle.id < parent.id
                    
                    uncle_gender = uncle_node.get('gender')
                    is_male = uncle_gender in ['male', 'nam']
                    parent_gender = parent_node.get('gender')
                    parent_is_male = parent_gender in ['male', 'nam']
                    
                    if parent_is_male:
                        # Bên nội
                        if is_uncle_older_than_parent:
                            return "Bác"
                        else:
                            if is_male:
                                return "Chú"
                            else:
                                return "Cô"
                    else:
                        # Bên ngoại
                        if is_uncle_older_than_parent:
                            return "Bác"
                        else:
                            if is_male:
                                return "Cậu"
                            else:
                                return "Dì"
            except:
                pass
                
            return "Bác/Chú/Cô/Dì/Cậu"
        
        # 5.4. Mối quan hệ Bác/Chú/Cô/Dì mở rộng (5 bước qua ông bà cố)
        # Pattern: Con -> Cha mẹ -> Ông bà -> Ông bà cố -> Bác/Chú/Cô/Dì của cha mẹ -> Bác/Chú/Cô/Dì
        # dirs = [-1, -1, -1, 1, 1] (Đi lên, Đi lên, Đi lên, Đi xuống, Đi xuống)
        if n_steps == 5 and dirs == [-1, -1, -1, 1, 1]:
            try:
                my_gp_node = nodes[2]      # Ông bà của tôi
                uncles_parent_node = nodes[4] # Bác/Chú/Cô/Dì của cha mẹ
                uncle_node = nodes[5]      # Bác/Chú/Cô/Dì
                parent_node = nodes[1]     # Cha mẹ của tôi
                
                my_gp = db.query(Person).filter(Person.id == my_gp_node['id']).first()
                uncles_parent = db.query(Person).filter(Person.id == uncles_parent_node['id']).first()
                uncle = db.query(Person).filter(Person.id == uncle_node['id']).first()
                
                if my_gp and uncles_parent and uncle:
                    # Xác định thứ bậc giữa Ông bà của tôi và Bác/Chú/Cô/Dì của cha mẹ
                    is_my_gp_older = False
                    if my_gp.date_of_birth and uncles_parent.date_of_birth:
                        is_my_gp_older = my_gp.date_of_birth < uncles_parent.date_of_birth
                    else:
                        # Mặc định sử dụng ID
                        is_my_gp_older = my_gp.id < uncles_parent.id
                        
                    uncle_gender = uncle_node.get('gender')
                    is_male = uncle_gender in ['male', 'nam']
                    
                    parent_gender = parent_node.get('gender')
                    parent_is_male = parent_gender in ['male', 'nam']
                    
                    if parent_is_male:
                        #Bên nội
                        if is_my_gp_older:
                            #Bên nội
                            return "Cháu"
                        else:
                            #Bên nội
                            return "Cháu"
                    else:
                        #Bên ngoại
                        return "Cháu"
            except:
                pass
            return "Cháu"
        
        # 5.5. Mối quan hệ Bác/Chú/Cô/Dì mở rộng (5 bước qua ông bà cố)
        # Pattern: Bác/Chú/Cô/Dì -> Bác/Chú/Cô/Dì của cha mẹ -> Ông bà cố -> Ông bà -> Cha mẹ -> Con
        # dirs = [-1, -1, 1, 1, 1] (Đi lên, Đi lên, Đi xuống, Đi xuống, Đi xuống)
        if n_steps == 5 and dirs == [-1, -1, 1, 1, 1]:
            try:
                uncle_node = nodes[0]
                uncles_parent_node = nodes[1]
                my_gp_node = nodes[3]
                uncle = db.query(Person).filter(Person.id == uncle_node['id']).first()
                uncles_parent = db.query(Person).filter(Person.id == uncles_parent_node['id']).first()
                my_gp = db.query(Person).filter(Person.id == my_gp_node['id']).first()
                
                if my_gp and uncles_parent and uncle:
                    is_nephew_line_older = False
                    if my_gp.date_of_birth and uncles_parent.date_of_birth:
                        is_nephew_line_older = my_gp.date_of_birth < uncles_parent.date_of_birth
                    else:
                        is_nephew_line_older = my_gp.id < uncles_parent.id

                    uncle_gender = uncle_node.get('gender')
                    is_male = uncle_gender in ['male', 'nam']
                    
                    # Bác/Chú/Cô/Dì nhìn vào Con -> Luôn là "Cháu"
                    # Có thể chỉ định "Cháu (gọi bằng Chú/Bác)"
                    
                    if is_nephew_line_older:
                        #  (lớn tuổi hơn) -> Bác/Chú/Cô/Dì là em -> Bác/Chú/Cô/Dì là [Chú] của Con
                        return "Chú" if is_male else "Cô"
                    else:
                        #  (lớn tuổi hơn) -> Bác/Chú/Cô/Dì là anh -> Bác/Chú/Cô/Dì là [Bác] của Con
                        
                        # Kiểm tra giới tính của Cha mẹ
                        parent_node = nodes[4]
                        parent_gender = parent_node.get('gender')
                        parent_is_male = parent_gender in ['male', 'nam']
                        
                        if parent_is_male:
                            return "Bác"
                        else:
                            return "Cậu" if is_male else "Dì"
            except:
                pass
            return "Bác/Chú/Cô/Dì/Cậu"

        # 5.6. Mối quan hệ Bác/Chú/Cô/Dì mở rộng (6 bước qua ông bà cố)
        # Mối quan hệ: Cháu họ <-> Bác/Chú/Cô/Dì (Ông họ - Cháu họ)
        
        # Forward: Cháu họ -> Bác/Chú/Cô/Dì 
        # Pattern: Con -> Cha mẹ -> Ông bà -> Ông bà cố -> Ông bà cố -> Bác/Chú/Cô/Dì của cha mẹ -> Bác/Chú/Cô/Dì
        # Đi lên, Đi lên, Đi lên, Đi lên, Đi xuống, Đi xuống -> [-1, -1, -1, -1, 1, 1]
        if n_steps == 6 and dirs == [-1, -1, -1, -1, 1, 1]:
            return "Cháu"

        # Reverse: Bác/Chú/Cô/Dì -> Cháu họ
        # Pattern: Bác/Chú/Cô/Dì -> Bác/Chú/Cô/Dì của cha mẹ -> Ông bà cố -> Ông bà cố -> Ông bà -> Cha mẹ -> Con
        # Đi lên, Đi lên, Đi xuống, Đi xuống, Đi xuống, Đi xuống -> [-1, -1, 1, 1, 1, 1]
        if n_steps == 6 and dirs == [-1, -1, 1, 1, 1, 1]:
            try:
                user_node = nodes[0]
                gender = user_node.get('gender')
                is_male = gender in ['male', 'nam']
                return "Ông" if is_male else "Bà"
            except:
                return "Ông/Bà"

        # 5.6b. Bổ sung các trường hợp mối quan hệ bàng hệ 6 bước còn thiếu
        if n_steps == 6:
            # --- TRƯỜNG HỢP (5,1): Cháu họ (đời 5) ---
            # Đi lên 5 đời, đi xuống 1 đời sang anh/chị/em cụ tổ
            if dirs == [-1, -1, -1, -1, -1, 1]:
                return "Chút(Huyền Tôn)"

            # --- TRƯỜNG HỢP (1,5): Cụ tổ đời thứ 5 (Xuôi/Ngược với 5,1) ---
            # Đi lên 1 đời, đi xuống 5 đời đến đối phương
            elif dirs == [-1, 1, 1, 1, 1, 1]:
                gender = nodes[0].get('gender')
                is_male = gender in ['male', 'nam']
                return "Kị(Cao Tổ)"
        
        # 5.7. Mối quan hệ Bác/Chú/Cô/Dì mở rộng (7 bước qua ông bà cố)
        # Mối quan hệ: Cháu họ <-> Bác/Chú/Cô/Dì (Ông họ - Cháu họ)
        
        # Reverse: Bác/Chú/Cô/Dì -> Cháu họ
        # Pattern: Bác/Chú/Cô/Dì -> Bác/Chú/Cô/Dì của cha mẹ -> Ông bà cố -> Ông bà cố -> Ông bà -> Cha mẹ -> Con
        # Đi lên, Đi lên, Đi lên, Đi xuống, Đi xuống, Đi xuống, Đi xuống -> [-1, -1, -1, 1, 1, 1, 1]
        if n_steps == 7 and dirs == [-1, -1, -1, 1, 1, 1, 1]:
            try:
                # Xác định vai vế giữa  (Ông bà cố của tôi, Node 2) và  (Ông bà cố của cháu, Node 4)
                
                my_ancestor_node = nodes[2]   # Ông bà cố của tôi
                target_ancestor_node = nodes[4] # Ông bà cố của cháu
                user_node = nodes[0] # Bác/Chú/Cô/Dì
                
                my_ancestor = db.query(Person).filter(Person.id == my_ancestor_node['id']).first()
                target_ancestor = db.query(Person).filter(Person.id == target_ancestor_node['id']).first()
                
                if my_ancestor and target_ancestor:
                     is_target_line_older = False
                     if target_ancestor.date_of_birth and my_ancestor.date_of_birth:
                         is_target_line_older = target_ancestor.date_of_birth < my_ancestor.date_of_birth
                     else:
                         is_target_line_older = target_ancestor.id < my_ancestor.id
                     
                     user_gender = user_node.get('gender')
                     is_male = user_gender in ['male', 'nam']
                     
                     if is_target_line_older:
                         # Người được chọn lớn tuổi hơn -> Tôi là nhánh dưới -> Cô/Chú
                         return "Chú" if is_male else "Cô"
                     else:
                         # Tôi là nhánh trên -> Bác
                         return "Bác"
            except:
                pass
            return "Họ hàng"

        # Mối quan hệ Bác/Chú/Cô/Dì mở rộng (7 bước qua ông bà cố)
        # Mối quan hệ: Cháu họ <-> Bác/Chú/Cô/Dì (Ông họ - Cháu họ)
        
        # Forward: Cháu họ -> Bác/Chú/Cô/Dì 
        # Pattern: Con -> Cha mẹ -> Ông bà -> Ông bà cố -> Ông bà cố -> Bác/Chú/Cô/Dì của cha mẹ -> Bác/Chú/Cô/Dì
        # Đi lên, Đi lên, Đi lên, Đi lên, Đi xuống, Đi xuống, Đi xuống -> [-1, -1, -1, -1, 1, 1, 1]
        if n_steps == 7 and dirs == [-1, -1, -1, -1, 1, 1, 1]:
            return "Cháu"

        # 5.7c. Bổ sung các trường hợp mối quan hệ bàng hệ 7 bước còn lại
        # --- TRƯỜNG HỢP (6,1): Cháu họ (đời 6) ---
        # Đi lên 6 đời đến cụ tổ đời 6, đi xuống 1 đời sang anh/chị/em cụ tổ
        if n_steps == 7 and dirs == [-1, -1, -1, -1, -1, -1, 1]:
            return "Lai Tôn"

        # --- TRƯỜNG HỢP (1,6): Cụ tổ đời thứ 6 ---
        # Đi lên 1 đời (Cha mẹ), đi xuống 6 đời đến đối phương
        if n_steps == 7 and dirs == [-1, 1, 1, 1, 1, 1, 1]:
            gender = nodes[0].get('gender')
            is_male = gender in ['male', 'nam']
            return "Thiên Tổ"          

        # --- TRƯỜNG HỢP (5,2): Cháu họ (đời 5) ---
        # Đi lên 5 đời đến cụ tổ đời 5, đi xuống 2 đời đến con của anh/chị/em cụ tổ
        if n_steps == 7 and dirs == [-1, -1, -1, -1, -1, 1, 1]:
            return "Chắt"

        # --- TRƯỜNG HỢP (2,5): Cụ họ (đời 4) ---
        # Đi lên 2 đời (Ông bà), đi xuống 5 đời đến đối phương
        if n_steps == 7 and dirs == [-1, -1, 1, 1, 1, 1, 1]:
            return "Cụ"
        # Pattern: Bác/Chú/ Cô/Dì -> Ông bà cố -> Ông bà cố -> Ông bà -> Cha mẹ -> Con
        # Đi lên, Đi xuống, Đi xuống, Đi xuống -> [-1, 1, 1, 1]
        if n_steps == 4 and dirs == [-1, 1, 1, 1]:
            try:
                great_uncle_node = nodes[0]
                ggp_node = nodes[1]  # Ông bà cố
                gp_node = nodes[2]   # Ông bà
                parent_node = nodes[3]  # Cha mẹ
                
                great_uncle = db.query(Person).filter(Person.id == great_uncle_node['id']).first()
                grandparent = db.query(Person).filter(Person.id == gp_node['id']).first()
                parent = db.query(Person).filter(Person.id == parent_node['id']).first()
                
                if great_uncle and grandparent and parent:
                    # Xác định vai vế giữa Bác/Chú/Cô/Dì và Ông bà
                    is_great_uncle_older = False
                    if great_uncle.date_of_birth and grandparent.date_of_birth:
                        is_great_uncle_older = great_uncle.date_of_birth < grandparent.date_of_birth
                    else:
                        is_great_uncle_older = great_uncle.id < grandparent.id
                    
                    great_uncle_gender = great_uncle_node.get('gender')
                    is_male = great_uncle_gender in ['male', 'nam']
                    
                    parent_gender = parent_node.get('gender')
                    parent_is_male = parent_gender in ['male', 'nam']
                    
                    # Xác định vai vế dựa trên bên và tuổi
                    if parent_is_male:
                        # Bên nội
                        return "Ông" if is_male else "Bà"
                    
                    else:
                        #Bên ngoại
                        return "Ông" if is_male else "Bà"
                        
            except:
                pass
            
            return "Cụ/Ông cố"
        
        # 5.6. Mối quan hệ Cháu cố (reverse)
        # Pattern: Cháu cố -> Cha mẹ -> Ông bà -> Ông bà cố -> Bác/Chú/Cô/Dì
        # Đi lên, Đi lên, Đi lên, Đi xuống -> [-1, -1, -1, 1]
        if n_steps == 4 and dirs == [-1, -1, -1, 1]:
            try:
                great_nephew_node = nodes[0]
                gender = great_nephew_node.get('gender')
                is_male = gender in ['male', 'nam']
                return "Cháu"
            except:
                pass
            
            return "Cháu"
        
        # 5.7. Mối quan hệ Cố (5 bước - anh chị em của ông bà cố - trường hợp 1 lên 4 xuống)
        # Đi lên 1 đời (cha mẹ), đi xuống 4 đời -> [-1, 1, 1, 1, 1]
        if n_steps == 5 and dirs == [-1, 1, 1, 1, 1]:
            try:
                ggu_node = nodes[0]  # Cố
                ggu = db.query(Person).filter(Person.id == ggu_node['id']).first()
                if ggu:
                    ggu_gender = ggu_node.get('gender')
                    is_male = ggu_gender in ['male', 'nam']
                    return "Cụ" if is_male else "Bà cụ"
            except:
                pass
            return "Cụ"
        
        # 5.8. Mối quan hệ Cháu cố (reverse - 5 bước - trường hợp 4 lên 1 xuống)
        # Đi lên 4 đời đến cụ kỵ, đi xuống 1 đời -> dirs = [-1, -1, -1, -1, 1]
        if n_steps == 5 and dirs == [-1, -1, -1, -1, 1]:
            try:
                ggn_node = nodes[0]
                gender = ggn_node.get('gender')
                return "Cháu"
            except:
                pass
            
            return "Cháu"
        

        # 6. Mối quan hệ Anh em họ (con của Bác/Chú/Cô/Dì)
        # Mẫu: Tôi -> Bố mẹ -> Ông bà -> Bác/Chú/Cô/Dì -> Anh em họ
        # Đi lên, Đi lên, Đi xuống, Đi xuống -> hướng = [1, 1, -1, -1] (đi lên 2 cấp, sau đó đi xuống 2 cấp)
        # Hoặc ngược lại: Anh em họ -> Bác/Chú/Cô/Dì -> Ông bà -> Bố mẹ -> Tôi
        # Đi xuống, Đi xuống, Đi lên, Đi lên -> hướng = [-1, -1, 1, 1]
        if n_steps == 4:
            if dirs == [1, 1, -1, -1] or dirs == [-1, -1, 1, 1]:
                # Đây là mối quan hệ anh em họ
                try:
                    if dirs == [1, 1, -1, -1]:
                        # Tôi -> Cha mẹ -> Ông bà -> Bác/Chú/Cô/Dì -> Anh em họ
                        cousin_node = nodes[-1]
                        my_node = nodes[0]
                        my_parent_node = nodes[1]
                        gp_node = nodes[2]
                        uncle_node = nodes[3]
                    else:
                        # Anh em họ -> Bác/Chú/Cô/Dì -> Ông bà -> Cha mẹ -> Tôi
                        cousin_node = nodes[0]
                        my_node = nodes[-1]
                        gp_node = nodes[2]
                        my_parent_node = nodes[3]
                        uncle_node = nodes[1]
                    
                    # LOGIC: Thay vì so sánh ngày sinh,
                    # tính toán mối quan hệ anh em thực tế giữa cha mẹ tôi và bác/chú/cô/dì
                    # Điều này đòi hỏi phải tìm đường đi giữa họ
                    
                    # Xây dựng đường đi đơn giản để kiểm tra mối quan hệ anh em
                    # cha mẹ tôi -> ông bà, ông bà -> bác/chú/cô/dì (2 bước)
                    # Cần xác định xem cha mẹ tôi có phải là "Anh" hay "Em" của bác/chú/cô/dì không
                    
                    # Lấy thông tin cả hai cha mẹ
                    uncle = db.query(Person).filter(Person.id == uncle_node['id']).first()
                    my_parent = db.query(Person).filter(Person.id == my_parent_node['id']).first()
                    
                    # Xác định thứ bậc dựa trên mối quan hệ anh em
                    # Kiểm tra xem họ có cùng cha mẹ không (anh chị em)
                    my_parent_is_older_sibling = False
                    
                    if uncle and my_parent:
                        # Cùng cha hoặc cùng mẹ cho thấy họ là anh chị em
                        are_siblings = (
                            (my_parent.father_id and uncle.father_id and my_parent.father_id == uncle.father_id) or
                            (my_parent.mother_id and uncle.mother_id and my_parent.mother_id == uncle.mother_id)
                        )
                        
                        if are_siblings:
                            # Đối với anh chị em, sử dụng ngày sinh để xác định anh/em
                            # Điều này được chấp nhận theo yêu cầu của người dùng
                            if uncle.date_of_birth and my_parent.date_of_birth:
                                my_parent_is_older_sibling = my_parent.date_of_birth < uncle.date_of_birth
                            else:
                                # Fallback to ID if no birth date
                                my_parent_is_older_sibling = my_parent.id < uncle.id
                        
                    cousin_gender = cousin_node.get('gender')
                    is_male = cousin_gender in ['male', 'nam']
                        
                    # Xác định mối quan hệ anh em họ dựa trên thứ bậc anh chị em của cha mẹ
                    if my_parent_is_older_sibling:
                        # Cha mẹ tôi là anh chị em lớn tuổi hơn của Bác/Chú/Cô/Dì
                        # => Bác/Chú/Cô/Dì là em của cha mẹ tôi
                        # => Bác/Chú/Cô/Dì là Chú/Cô/Dì/Cậu (tùy thuộc vào giới tính và bên)
                        # => Anh em họ là "Con chú/cô/dì/cậu"
                        # => Cousin is younger rank than me
                        if is_male:
                            return "Em trai họ "
                        else:
                            return "Em gái họ"
                    else:
                        #Cha mẹ tôi là em của Bác/Chú/Cô/Dì
                        # => Bác/Chú/Cô/Dì là anh chị em lớn tuổi hơn của cha mẹ tôi
                        # => Bác/Chú/Cô/Dì là Bác
                        # => Anh em họ là "Con bác"
                        # => Anh em họ có thứ bậc cao hơn tôi
                        if is_male:
                            return "Anh họ"
                        else:
                            return "Chị họ"
                except:
                    pass
                
                return "Anh chị em họ"

        # 6b. Con của anh em họ (children of first cousins)
        # Mẫu: Tôi -> Bố mẹ -> Ông bà -> Ông bà cố -> Bác -> Anh em họ -> Con của anh em họ
        # Đây là 6 bước cho con của anh em họ
        # hướng = [1, 1, 1, -1, -1, -1] hoặc ngược lại [-1, -1, -1, 1, 1, 1]
        if n_steps == 6:
            if dirs == [1, 1, 1, -1, -1, -1] or dirs == [-1, -1, -1, 1, 1, 1]:
                # Đây là mối quan hệ con của anh em họ
                try:
                    if dirs == [1, 1, 1, -1, -1, -1]:
                        # Tôi -> Bố mẹ -> Ông bà -> Ông bà cố -> Bác -> Anh em họ -> Con của anh em họ
                        second_cousin_node = nodes[-1]
                        my_node = nodes[0]
                        my_parent_node = nodes[1]  # Bố mẹ của tôi
                        parents_cousin_node = nodes[5]  # Anh em họ của bố/mẹ
                    else:
                        #  Ngược lại: Con của anh em họ -> Anh em họ -> Bác -> Ông bà cố -> Ông bà -> Bố mẹ -> Tôi
                        second_cousin_node = nodes[0]
                        my_node = nodes[-1]
                        my_parent_node = nodes[-2]  # nodes[5]
                        parents_cousin_node = nodes[1]  # Anh em họ của bố/mẹ
                    
                    # Chiến lược: Xác định mối quan hệ giữa bố/mẹ tôi và anh em họ của bố/mẹ
                    # Họ là anh em họ đời thứ nhất, nên chúng ta cần biết ai là "bậc cao hơn"
                    # Chúng ta có thể tính toán đệ quy mối quan hệ giữa họ
                    
                    # Xây dựng đường đi giữa bố/mẹ tôi và anh em họ của bố/mẹ
                    # Đây sẽ là quan hệ anh em họ 4 bước
                    parent_relationship_path = find_shortest_path(my_parent_node['id'], parents_cousin_node['id'])
                    
                    if parent_relationship_path:
                        parent_nodes = parent_relationship_path['nodes']
                        parent_rels = parent_relationship_path['rels']
                        
                        # Get the cousin relationship term for parents
                        parent_term = get_summary_term(parent_nodes, parent_rels)
                        
                        # Now determine second cousin relationship based on parent relationship
                        second_cousin_gender = second_cousin_node.get('gender')
                        is_male = second_cousin_gender in ['male', 'nam']
                        
                        # If my parent is "Anh/Chị họ" of parents_cousin
                        # => I am higher rank than second cousin
                        # => second cousin is "Em họ đời 2"
                        if parent_term and "Anh" in parent_term or "Chị" in parent_term:
                            # My parent is older rank cousin
                            if is_male:
                                return "Em trai họ"
                            else:
                                return "Em gái họ"
                        # If my parent is "Em họ" of parents_cousin
                        # => I am lower rank than second cousin
                        # => second cousin is "Anh/Chị họ đời 2"
                        elif parent_term and "Em" in parent_term:
                            # My parent is younger rank cousin
                            if is_male:
                                return "Anh họ"
                            else:
                                return "Chị họ"
                
                except:
                    pass
                
                return "Anh chị em họ"


        # 6c. Xử lý toàn bộ các trường hợp mối quan hệ bàng hệ 8 bước
        # Có 7 trường hợp bàng hệ (không tính trực hệ thuần túy đã xử lý ở mục 1 & 2):
        # (4,4) Anh em họ đời 3 | (5,3)/(3,5) Cháu họ/Ông Bà họ
        # (6,2)/(2,6) Cụ họ/Cháu họ | (7,1)/(1,7) Cụ tổ đời thứ 7/Cháu họ
        if n_steps == 8:

            # --- TRƯỜNG HỢP 1: Anh em họ đời 3 (4 lên, 4 xuống) ---
            # Mẫu: Tôi -> Bố mẹ -> Ông bà -> Cụ -> Kỵ -> Anh/chị/em của Cụ -> Ông bà họ -> Bố mẹ họ -> Anh em họ đời 3
            if dirs == [-1, -1, -1, -1, 1, 1, 1, 1] or dirs == [1, 1, 1, 1, -1, -1, -1, -1]:
                try:
                    if dirs == [-1, -1, -1, -1, 1, 1, 1, 1]:
                        # Chiều xuôi: Tôi (nodes[0]) -> ... -> Anh em họ đời 3 (nodes[-1])
                        third_cousin_node = nodes[-1]
                        my_parent_node = nodes[1]       # Cha/Mẹ của tôi
                        parents_cousin_node = nodes[7]   # Cha/Mẹ của anh em họ đời 3
                    else:
                        # Chiều ngược: Anh em họ đời 3 (nodes[0]) -> ... -> Tôi (nodes[-1])
                        third_cousin_node = nodes[0]
                        my_parent_node = nodes[-2]       # Cha/Mẹ của tôi (nodes[7])
                        parents_cousin_node = nodes[1]   # Cha/Mẹ của anh em họ đời 3

                    # Đệ quy: Tính toán mối quan hệ giữa cha mẹ hai bên (đường đi 6 bước đã có sẵn)
                    parent_relationship_path = find_shortest_path(my_parent_node['id'], parents_cousin_node['id'])
                    
                    if parent_relationship_path:
                        parent_nodes = parent_relationship_path['nodes']
                        parent_rels = parent_relationship_path['rels']
                        parent_term = get_summary_term(parent_nodes, parent_rels)
                        
                        third_cousin_gender = third_cousin_node.get('gender')
                        is_male = third_cousin_gender in ['male', 'nam']
                        
                        # Suy luận vai vế dựa trên vai vế cha mẹ
                        if parent_term and ("Anh" in parent_term or "Chị" in parent_term):
                            # Cha mẹ tôi là vai anh/chị -> Tôi vai cao hơn -> Anh em họ là Em
                            return "Anh họ (đời 3)" if is_male else "Chị họ (đời 3)"
                        elif parent_term and "Em" in parent_term:
                            # Cha mẹ tôi là vai em -> Tôi vai thấp hơn -> Anh em họ là Anh/Chị
                            return "Em họ (đời 3)"
                except Exception as ex:
                    print(f"Error parsing 8-step third cousin: {ex}")
                
                return "Anh chị em họ (đời 3)"

            # --- TRƯỜNG HỢP 2: Ông họ / Bà họ và Cháu họ (3 lên 5 xuống hoặc 5 lên 3 xuống) ---
            # Mẫu xuôi (3,5): Tôi -> Cha mẹ -> Ông bà -> Cụ cố (tổ tiên chung) -> ... -> Đối phương (5 đời dưới)
            # => Tôi ở vai Ông/Bà họ của đối phương
            elif dirs == [-1, -1, -1, 1, 1, 1, 1, 1]:
                gender = nodes[0].get('gender')
                is_male = gender in ['male', 'nam']
                return "Ông họ" if is_male else "Bà họ"

            # Mẫu ngược (5,3): Tôi -> ... -> 5 đời lên -> tổ tiên chung -> ... -> Đối phương (3 đời dưới)
            # => Tôi ở vai Cháu họ của đối phương
            elif dirs == [-1, -1, -1, -1, -1, 1, 1, 1]:
                return "Cháu họ (đời 5)"

            # --- TRƯỜNG HỢP 3: Cụ họ và Cháu họ đời 6 (6 lên 2 xuống hoặc 2 lên 6 xuống) ---
            # Mẫu xuôi (6,2): Tôi đi lên 6 đời đến tổ tiên chung, đi xuống 2 đời
            # => Tôi ở vai Cụ họ của đối phương
            elif dirs == [-1, -1, -1, -1, -1, -1, 1, 1]:
                gender = nodes[0].get('gender')
                is_male = gender in ['male', 'nam']
                return "Chút(Huyền Tôn)"

            # Mẫu ngược (2,6): Tôi đi lên 2 đời (Ông bà), đi xuống 6 đời
            # => Tôi ở vai Cháu họ đời 6 của đối phương
            elif dirs == [-1, -1, 1, 1, 1, 1, 1, 1]:
                return "Kị(Cao Tổ)"

            # --- TRƯỜNG HỢP 4: Cụ tổ đời thứ 7 và Cháu họ đời 7 (7 lên 1 xuống hoặc 1 lên 7 xuống) ---
            # Mẫu xuôi (7,1): Tôi đi lên 7 đời đến tổ tiên chung, đi xuống 1 đời sang anh/chị/em cụ tổ
            # => Tôi ở vai Cụ tổ đời thứ 7
            elif dirs == [-1, -1, -1, -1, -1, -1, -1, 1]:
                return "Côn Tôn(Cháu họ đời 7)"

            # Mẫu ngược (1,7): Tôi đi lên 1 đời (Cha mẹ), đi xuống 7 đời
            # => Tôi ở vai Cháu họ đời 7 của đối phương
            elif dirs == [-1, 1, 1, 1, 1, 1, 1, 1]:
                return "Liệt Tổ(Ông nội của Kị)" 

        # 6d. Xử lý toàn bộ các trường hợp mối quan hệ bàng hệ 9 bước
        if n_steps == 9:
            # --- TRƯỜNG HỢP 1: Cháu họ đời 8 và Cụ tổ đời thứ 8 (8 lên 1 xuống hoặc ngược lại) ---
            if dirs == [-1, -1, -1, -1, -1, -1, -1, -1, 1]:
                return "Vân Tôn(Cháu họ đời 8)"
                
            elif dirs == [-1, 1, 1, 1, 1, 1, 1, 1, 1]:
                return "Tổ tiên đời thứ 8(Kị của Kị)"

            # --- TRƯỜNG HỢP 2: Cháu họ đời 7 và Cụ họ đời 6 (7 lên 2 xuống hoặc ngược lại) ---
            elif dirs == [-1, -1, -1, -1, -1, -1, -1, 1, 1]:
                return "Côn Tôn(Cháu họ đời 7)"
                
            elif dirs == [-1, -1, 1, 1, 1, 1, 1, 1, 1]:
                return "Liệt Tổ"

            # --- TRƯỜNG HỢP 3: Cháu họ đời 6 và Cụ họ (6 lên 3 xuống hoặc ngược lại) ---
            elif dirs == [-1, -1, -1, -1, -1, -1, 1, 1, 1]:
                return "Chắt"
                
            elif dirs == [-1, -1, -1, 1, 1, 1, 1, 1, 1]:              
                return "Cụ"

            # --- TRƯỜNG HỢP 4: Cháu bàng hệ và Bác/Chú/Cô/Dì (5 lên 4 xuống hoặc ngược lại) ---
            elif dirs == [-1, -1, -1, -1, -1, 1, 1, 1, 1]:
                return "Cháu"
                
            elif dirs == [-1, -1, -1, -1, 1, 1, 1, 1, 1]:
                try:
                    # So sánh vai vế giữa thế hệ trung gian ngay dưới LCA (nodes[4])
                    # nodes[3] (Phía đối phương) và nodes[5] (Phía người dùng)
                    my_ancestor_node = nodes[5]      # Ông bà cố của tôi
                    target_ancestor_node = nodes[3]  # Ông bà cố của đối phương
                    user_node = nodes[0]             # Bác/Chú/Cô/Dì
                    
                    my_ancestor = db.query(Person).filter(Person.id == my_ancestor_node['id']).first()
                    target_ancestor = db.query(Person).filter(Person.id == target_ancestor_node['id']).first()
                    
                    if my_ancestor and target_ancestor:
                        is_target_line_older = False
                        if target_ancestor.date_of_birth and my_ancestor.date_of_birth:
                            is_target_line_older = target_ancestor.date_of_birth < my_ancestor.date_of_birth
                        else:
                            is_target_line_older = target_ancestor.id < my_ancestor.id
                        
                        user_gender = user_node.get('gender')
                        is_male = user_gender in ['male', 'nam']
                        
                        if is_target_line_older:
                            # Đối phương thuộc nhánh lớn tuổi hơn -> Tôi vai dưới -> Chú/Cô/Cậu/Dì
                            # Lấy giới tính của cha mẹ để phân biệt bên nội / ngoại
                            parent_node = nodes[8]
                            parent_gender = parent_node.get('gender')
                            parent_is_male = parent_gender in ['male', 'nam']
                            
                            if parent_is_male:
                                return "Bác"
                        else:
                            # Đối phương thuộc nhánh nhỏ tuổi hơn -> Tôi vai trên -> Bác
                            return "Chú" if is_male else "Cô"
                except:
                    pass
                return "Bác/Chú/Cô/Dì/Cậu"

        # 6e. Xử lý toàn bộ các trường hợp mối quan hệ bàng hệ 10 bước
        if n_steps == 10:

            # --- TRƯỜNG HỢP CÙNG THẾ HỆ: Anh em họ đời 4 (5 lên, 5 xuống) ---
            if dirs == [-1, -1, -1, -1, -1, 1, 1, 1, 1, 1] or dirs == [1, 1, 1, 1, 1, -1, -1, -1, -1, -1]:
                try:
                    if dirs == [-1, -1, -1, -1, -1, 1, 1, 1, 1, 1]:
                        # Chiều xuôi: Tôi (nodes[0]) -> ... -> Anh em họ đời 4 (nodes[-1])
                        fourth_cousin_node = nodes[-1]
                        my_parent_node = nodes[1]       # Cha/Mẹ của tôi
                        parents_cousin_node = nodes[9]   # Cha/Mẹ của anh em họ đời 4
                    else:
                        # Chiều ngược: Anh em họ đời 4 (nodes[0]) -> ... -> Tôi (nodes[-1])
                        fourth_cousin_node = nodes[0]
                        my_parent_node = nodes[-2]
                        parents_cousin_node = nodes[1]

                    # Đệ quy: Tính toán mối quan hệ giữa cha mẹ hai bên (đường đi 8 bước đã có sẵn)
                    parent_relationship_path = find_shortest_path(my_parent_node['id'], parents_cousin_node['id'])

                    if parent_relationship_path:
                        parent_nodes = parent_relationship_path['nodes']
                        parent_rels = parent_relationship_path['rels']
                        parent_term = get_summary_term(parent_nodes, parent_rels)

                        cousin_gender = fourth_cousin_node.get('gender')
                        is_male = cousin_gender in ['male', 'nam']

                        # Suy luận vai vế dựa trên vai vế cha mẹ
                        if parent_term and ("Anh" in parent_term or "Chị" in parent_term):
                            # Cha mẹ tôi là vai anh/chị -> Tôi vai cao hơn
                            return "Anh họ (đời 4)" if is_male else "Chị họ (đời 4)"
                        elif parent_term and "Em" in parent_term:
                            # Cha mẹ tôi là vai em -> Tôi vai thấp hơn
                            return "Em họ (đời 4)"
                except Exception as ex:
                    print(f"Error parsing 10-step fourth cousin: {ex}")

                return "Anh chị em họ (đời 4)"

            # --- CÁC TRƯỜNG HỢP BÀNG HỆ BẤT ĐỐI XỨNG ---

            # 9 lên 1 xuống / 1 lên 9 xuống
            elif dirs == [-1, -1, -1, -1, -1, -1, -1, -1, -1, 1]:
                return "Vân Tôn(Cháu họ đời 9)"
            elif dirs == [-1, 1, 1, 1, 1, 1, 1, 1, 1, 1]:
                return "Tổ tiên đời thứ 8"

            # 8 lên 2 xuống / 2 lên 8 xuống
            elif dirs == [-1, -1, -1, -1, -1, -1, -1, -1, 1, 1]:
                return "Côn Tôn(Cháu họ 7 đời)"
            elif dirs == [-1, -1, 1, 1, 1, 1, 1, 1, 1, 1]:
                return "Liệt Tổ"

            # 7 lên 3 xuống / 3 lên 7 xuống
            elif dirs == [-1, -1, -1, -1, -1, -1, -1, 1, 1, 1]:
                return "Lai Tôn(Cháu họ 5 đời)"
            elif dirs == [-1, -1, -1, 1, 1, 1, 1, 1, 1, 1]:
                return "Thiên Tổ"

            # 6 lên 4 xuống / 4 lên 6 xuống
            elif dirs == [-1, -1, -1, -1, -1, -1, 1, 1, 1, 1]:
                return "Cháu"
            elif dirs == [-1, -1, -1, -1, 1, 1, 1, 1, 1, 1]:
                gender = nodes[0].get('gender')
                is_male = gender in ['male', 'nam']
                return "Ông" if is_male else "Bà"
        # 6f. Xử lý toàn bộ các trường hợp mối quan hệ bàng hệ 11 bước
        if n_steps == 11:
            # 10 lên 1 xuống / 1 lên 10 xuống
            if dirs == [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 1]:
                return "Nhĩ Tôn(Cháu họ 10 đời)"
            elif dirs == [-1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]:
                return "Tỷ Tổ"

            # 9 lên 2 xuống / 2 lên 9 xuống
            elif dirs == [-1, -1, -1, -1, -1, -1, -1, -1, -1, 1, 1]:
                return "Nhưng Tôn(Cháu họ 8 đời)"
            elif dirs == [-1, -1, 1, 1, 1, 1, 1, 1, 1, 1, 1]:
                return "Tổ tiên đời thứ 7"

            # 8 lên 3 xuống / 3 lên 8 xuống
            elif dirs == [-1, -1, -1, -1, -1, -1, -1, -1, 1, 1, 1]:
                return "Lai Tôn (Cháu họ 6 đời)"
            elif dirs == [-1, -1, -1, 1, 1, 1, 1, 1, 1, 1, 1]:
                return "Thiên Tổ"

            # 7 lên 4 xuống / 4 lên 7 xuống
            elif dirs == [-1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1]:
                return "Cháu họ (đời 7)"
            elif dirs == [-1, -1, -1, -1, 1, 1, 1, 1, 1, 1, 1]:
                return "Cụ họ"

            # 6 lên 5 xuống (Cháu) / 5 lên 6 xuống (Bác/Chú/Cô/Cậu/Dì)
            elif dirs == [-1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1]:
                return "Cháu"
            elif dirs == [-1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1]:
                try:
                    # LCA ở nodes[5]. So sánh nhánh Target (nodes[4]) với nhánh Tôi (nodes[6])
                    my_ancestor_node = nodes[6]
                    target_ancestor_node = nodes[4]
                    user_node = nodes[0]

                    my_ancestor = db.query(Person).filter(Person.id == my_ancestor_node['id']).first()
                    target_ancestor = db.query(Person).filter(Person.id == target_ancestor_node['id']).first()

                    if my_ancestor and target_ancestor:
                        is_target_line_older = False
                        if target_ancestor.date_of_birth and my_ancestor.date_of_birth:
                            is_target_line_older = target_ancestor.date_of_birth < my_ancestor.date_of_birth
                        else:
                            is_target_line_older = target_ancestor.id < my_ancestor.id

                        user_gender = user_node.get('gender')
                        is_male = user_gender in ['male', 'nam']

                        if is_target_line_older:
                            parent_node = nodes[10]
                            parent_gender = parent_node.get('gender')
                            parent_is_male = parent_gender in ['male', 'nam']
                            if parent_is_male:
                                return "Bác"                     
                        else:
                            return "Chú" if is_male else "Cô"
                except:
                    pass
                return "Bác/Chú/Cô/Dì/Cậu"

        # 6g. Xử lý toàn bộ các trường hợp mối quan hệ bàng hệ 12 bước
        if n_steps == 12:

            # --- TRƯỜNG HỢP CÙNG THẾ HỆ: Anh em họ đời 5 (6 lên, 6 xuống) ---
            if dirs == [-1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1] or dirs == [1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1]:
                try:
                    if dirs == [-1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1]:
                        # Chiều xuôi
                        fifth_cousin_node = nodes[-1]
                        my_parent_node = nodes[1]
                        parents_cousin_node = nodes[11]
                    else:
                        # Chiều ngược
                        fifth_cousin_node = nodes[0]
                        my_parent_node = nodes[-2]
                        parents_cousin_node = nodes[1]

                    # Đệ quy tìm vai vế cha mẹ (bài toán 10 bước đã giải quyết)
                    parent_relationship_path = find_shortest_path(my_parent_node['id'], parents_cousin_node['id'])

                    if parent_relationship_path:
                        parent_nodes = parent_relationship_path['nodes']
                        parent_rels = parent_relationship_path['rels']
                        parent_term = get_summary_term(parent_nodes, parent_rels)

                        cousin_gender = fifth_cousin_node.get('gender')
                        is_male = cousin_gender in ['male', 'nam']

                        if parent_term and ("Anh" in parent_term or "Chị" in parent_term):
                            return "Anh họ (đời 5)" if is_male else "Chị họ (đời 5)"
                        elif parent_term and "Em" in parent_term:
                            return "Em họ (đời 5)"
                except Exception as ex:
                    print(f"Error parsing 12-step fifth cousin: {ex}")

                return "Anh chị em họ (đời 5)"

            # --- CÁC TRƯỜNG HỢP BÀNG HỆ BẤT ĐỐI XỨNG ---

            # 11 lên 1 xuống / 1 lên 11 xuống
            elif dirs == [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 1]:
                return "Cháu họ 11 đời"
            elif dirs == [-1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]:
                return "Cụ tổ đời thứ 11"

            # 10 lên 2 xuống / 2 lên 10 xuống
            elif dirs == [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 1, 1]:
                return "Vân Tôn"
            elif dirs == [-1, -1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]:
                return "Tổ tiên đời thứ 8"

            # 9 lên 3 xuống / 3 lên 9 xuống
            elif dirs == [-1, -1, -1, -1, -1, -1, -1, -1, -1, 1, 1, 1]:
                return "Côn Tôn"
            elif dirs == [-1, -1, -1, 1, 1, 1, 1, 1, 1, 1, 1, 1]:
                return "Liệt Tổ"

            # 8 lên 4 xuống / 4 lên 8 xuống
            elif dirs == [-1, -1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1]:
                return "Chắt"
            elif dirs == [-1, -1, -1, -1, 1, 1, 1, 1, 1, 1, 1, 1]:
                return "Kị"

            # 7 lên 5 xuống / 5 lên 7 xuống
            elif dirs == [-1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1]:
                return "Cháu"
            elif dirs == [-1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1, 1]:
                gender = nodes[0].get('gender')
                is_male = gender in ['male', 'nam']
                return "Ông" if is_male else "Bà"

        # 6h. Xử lý toàn bộ các trường hợp mối quan hệ bàng hệ 13 bước
        if n_steps == 13:
            # 12 lên 1 xuống / 1 lên 12 xuống
            if dirs == [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 1]:
                return "Cháu họ 12 đời"
            elif dirs == [-1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]:
                return "Cụ tổ đời thứ 12"

            # 11 lên 2 xuống / 2 lên 11 xuống
            elif dirs == [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 1, 1]:
                return "Nhĩ Tôn"
            elif dirs == [-1, -1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]:
                return "Tổ tiên đời thứ 9"

            # 10 lên 3 xuống / 3 lên 10 xuống
            elif dirs == [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 1, 1, 1]:
                return "Nhưng Tôn"
            elif dirs == [-1, -1, -1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]:
                return "Tổ tiên đời thứ 7"

            # 9 lên 4 xuống / 4 lên 9 xuống
            elif dirs == [-1, -1, -1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1]:
                return "Lai Tôn(Cháu họ 6 đời)"
            elif dirs == [-1, -1, -1, -1, 1, 1, 1, 1, 1, 1, 1, 1, 1]:
                return "Thiên Tổ"

            # 8 lên 5 xuống / 5 lên 8 xuống
            elif dirs == [-1, -1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1]:
                return "Chắt"
            elif dirs == [-1, -1, -1, -1, 1, 1, 1, 1, 1, 1, 1, 1, 1]:
                return "Cụ"

            # 7 lên 6 xuống (Cháu) / 6 lên 7 xuống (Bác/Chú/Cô/Cậu/Dì)
            elif dirs == [-1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1]:
                return "Cháu"
            elif dirs == [-1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1, 1]:
                try:
                    # LCA ở nodes[6]. So sánh nhánh Target (nodes[5]) với nhánh Tôi (nodes[7])
                    my_ancestor_node = nodes[7]
                    target_ancestor_node = nodes[5]
                    user_node = nodes[0]

                    my_ancestor = db.query(Person).filter(Person.id == my_ancestor_node['id']).first()
                    target_ancestor = db.query(Person).filter(Person.id == target_ancestor_node['id']).first()

                    if my_ancestor and target_ancestor:
                        is_target_line_older = False
                        if target_ancestor.date_of_birth and my_ancestor.date_of_birth:
                            is_target_line_older = target_ancestor.date_of_birth < my_ancestor.date_of_birth
                        else:
                            is_target_line_older = target_ancestor.id < my_ancestor.id

                        user_gender = user_node.get('gender')
                        is_male = user_gender in ['male', 'nam']

                        if is_target_line_older:
                            parent_node = nodes[12]
                            parent_gender = parent_node.get('gender')
                            parent_is_male = parent_gender in ['male', 'nam']
                            if parent_is_male:
                                return "Bác"
                        else:
                            return "Chú" if is_male else "Cô"
                except:
                    pass
                return "Bác/Chú/Cô/Dì/Cậu"

        # 6i. Xử lý toàn bộ các trường hợp mối quan hệ bàng hệ 14 bước
        if n_steps == 14:

            # --- TRƯỜNG HỢP CÙNG THẾ HỆ: Anh em họ đời 6 (7 lên, 7 xuống) ---
            if dirs == [-1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1, 1] or dirs == [1, 1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, -1]:
                try:
                    if dirs == [-1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1, 1]:
                        # Chiều xuôi
                        sixth_cousin_node = nodes[-1]
                        my_parent_node = nodes[1]
                        parents_cousin_node = nodes[13]
                    else:
                        # Chiều ngược
                        sixth_cousin_node = nodes[0]
                        my_parent_node = nodes[-2]
                        parents_cousin_node = nodes[1]

                    # Đệ quy tìm vai vế cha mẹ (bài toán 12 bước đã giải quyết)
                    parent_relationship_path = find_shortest_path(my_parent_node['id'], parents_cousin_node['id'])

                    if parent_relationship_path:
                        parent_nodes = parent_relationship_path['nodes']
                        parent_rels = parent_relationship_path['rels']
                        parent_term = get_summary_term(parent_nodes, parent_rels)

                        cousin_gender = sixth_cousin_node.get('gender')
                        is_male = cousin_gender in ['male', 'nam']

                        if parent_term and ("Anh" in parent_term or "Chị" in parent_term):
                            return "Anh họ (đời 6)" if is_male else "Chị họ (đời 6)"
                        elif parent_term and "Em" in parent_term:
                            return "Em họ (đời 6)"
                except Exception as ex:
                    print(f"Error parsing 14-step sixth cousin: {ex}")

                return "Anh chị em họ (đời 6)"

            # --- CÁC TRƯỜNG HỢP BÀNG HỆ BẤT ĐỐI XỨNG ---

            # 13 lên 1 xuống / 1 lên 13 xuống
            elif dirs == [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 1]:
                return "Cháu họ (đời 13)"
            elif dirs == [-1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]:
                gender = nodes[0].get('gender')
                is_male = gender in ['male', 'nam']
                return "Cụ tổ đời thứ 13" if is_male else "Cụ tổ đời thứ 13 (nữ)"

            # 12 lên 2 xuống / 2 lên 12 xuống
            elif dirs == [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 1, 1]:
                return "Cháu họ (đời 11)"
            elif dirs == [-1, -1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]:
                return "Cụ họ (đời 11)"

            # 11 lên 3 xuống / 3 lên 11 xuống
            elif dirs == [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 1, 1, 1]:
                return "Vân Tôn"
            elif dirs == [-1, -1, -1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]:
                return "Tổ tiên đời thứ 8"

            # 10 lên 4 xuống / 4 lên 10 xuống
            elif dirs == [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1]:
                return "Côn Tôn"
            elif dirs == [-1, -1, -1, -1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]:
                return "Liệt Tổ"

            # 9 lên 5 xuống / 5 lên 9 xuống
            elif dirs == [-1, -1, -1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1]:
                return "Chút"
            elif dirs == [-1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1, 1, 1, 1]:
                return "Kị"

            # 8 lên 6 xuống / 6 lên 8 xuống
            elif dirs == [-1, -1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1]:
                return "Cháu"
            elif dirs == [-1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1, 1, 1]:
                gender = nodes[0].get('gender')
                is_male = gender in ['male', 'nam']
                return "Ông" if is_male else "Bà"


        # 7. Quan hệ Vợ/Chồng của họ hàng (Generic Spouse-of-Relative relationships)
        # Check if the last relationship is SPOUSE
        if n_steps > 1:
            last_rel = rels[-1]
            last_rel_type = last_rel.get('type', '')
            if last_rel_type == 'SPOUSE':
                # Xác định mối quan hệ với Người đồng hành (người đứng trước Vợ/Chồng)
                # Đệ quy: tìm mối quan hệ giữa Tôi (nodes[0]) và Người đồng hành (nodes[-2])
                sub_nodes = nodes[:-1] # Bỏ Vợ/Chồng
                sub_rels = rels[:-1]   # Bỏ Quan hệ Vợ/Chồng
                
                partner_term = get_summary_term(sub_nodes, sub_rels)
                
                if not partner_term:
                    return None
                
                spouse_node = nodes[-1]
                spouse_gender = spouse_node.get('gender')
                is_spouse_male = spouse_gender in ['male', 'nam']
                
                # QUY TẮC CHUNG (GENERAL RULE):
                # 1. Cùng thế hệ (Anh/Chị/Em): Thêm "chồng" hoặc "vợ"
                # 2. Các thế hệ khác (Ông, Bà, Bác, Chú, Cô, Cháu, etc.): Giữ nguyên thuật ngữ
                
                # Check if it's same-generation relationship
                if any(keyword in partner_term for keyword in ["Anh", "Chị", "Em"]):
                    # Same generation - use "chồng/vợ" suffix
                    # QUAN TRỌNG: Đảo ngược thuật ngữ giới tính
                    # Người đồng hành là "Chị" (nữ) -> Vợ/Chồng (nam) là "Anh chồng"
                    # Người đồng hành là "Anh" (nam) -> Vợ/Chồng (nữ) là "Chị vợ"
                    
                    if "Chị" in partner_term:
                        # Partner is female (Chị) -> Spouse is male -> Use "Anh"
                        return "Anh chồng" if is_spouse_male else "Em vợ"
                    elif "Anh" in partner_term:
                        # Partner is male (Anh) -> Spouse is female -> Use "Chị"
                        return "Chị vợ" if is_spouse_male == False else "Em chồng"
                    elif "Em" in partner_term:
                        # Người đồng hành là Em -> Cần xác định là Em trai hay Em gái
                        # Nếu Vợ/Chồng là nam và Người đồng hành có "Em" -> Người đồng hành có thể là nữ (Em gái) -> Vợ/Chồng là Em chồng
                        # Nếu Vợ/Chồng là nữ và Người đồng hành có "Em" -> Người đồng hành có thể là nam (Em trai) -> Vợ/Chồng là Em vợ
                        return "Em chồng" if is_spouse_male else "Em vợ"

                
                # Bản đồ đặc biệt cho các thuật ngữ bác/chú/cô/dì
                # Người đồng hành là nam -> Vợ/Chồng cần thuật ngữ nữ tương đương
                if partner_term == "Chú":
                    return "Thím"  # Wife of Chú
                elif partner_term == "Cậu":
                    return "Mợ"  # Wife of Cậu
                elif partner_term in ["Cô", "Dì"]:
                    return "Dượng"  # Husband of Cô/Dì
                elif partner_term == "Bác":
                    # Bác can be male or female, spouse should match
                    return "Bác gái" if is_spouse_male == False else "Bác"
                
                # Cho tất cả các trường hợp khác (Ông, Bà, Cụ, Ông cố, Cháu, etc.)
                # Giữ nguyên thuật ngữ
                return partner_term


        # 8. Quan hệ Vợ/Chồng ở đầu đường đi (Người dùng là Vợ/Chồng -> Người đồng hành -> Mục tiêu)
        # ví dụ: Tôi (Vợ) -> Chồng -> Anh em họ
        if n_steps > 1:
            first_rel = rels[0]
            first_rel_type = first_rel.get('type', '')
            if first_rel_type == 'SPOUSE':
                # Vợ/Chồng của tôi là nodes[1]
                # Tính toán mối quan hệ từ Vợ/Chồng của tôi (nodes[1]) tới Mục tiêu (nodes[-1])
                sub_nodes = nodes[1:]
                sub_rels = rels[1:]
                
                partner_term = get_summary_term(sub_nodes, sub_rels)
                
                if not partner_term:
                    return None
                
                my_node = nodes[0]
                my_gender = my_node.get('gender')
                is_me_male = my_gender in ['male', 'nam']
                
                # DEBUG
                print(f"DEBUG S8: partner_term='{partner_term}', is_me_male={is_me_male}, my_name={my_node.get('name')}, target_name={nodes[-1].get('name')}")
                
                # Apply the SAME general rule as Section 7
                # 1. Same generation: Add "chồng/vợ"
                # 2. Other generations: Keep the same term
                
                # Check if same-generation relationship
                if any(keyword in partner_term for keyword in ["Anh", "Chị", "Em"]):
                    # Same generation - apply different rules based on relationship type
                    
                    # Quy tắc 1: Quan hệ Anh em họ (Cousin relationships) - đảo giới tính dựa trên vợ/chồng
                    if "họ" in partner_term:
                        if is_me_male:
                            # Male spouse
                            if "Chị" in partner_term or "Em gái" in partner_term:
                                # Người đồng hành (nữ) gọi anh em họ nữ -> Tôi (nam) gọi tương đương nam
                                if "con bác" in partner_term:
                                    return "Anh họ (con bác)"
                                elif "đời 2" in partner_term:
                                    return "Anh họ"
                                else:
                                    return "Anh họ"
                            else:
                                # Người đồng hành gọi anh em họ nam -> giữ nguyên
                                return partner_term
                        else:
                            # Female spouse
                            if "Anh" in partner_term or "Em trai" in partner_term:
                                # Người đồng hành (nam) gọi anh em họ nam -> Tôi (nữ) gọi tương đương nữ
                                if "con bác" in partner_term:
                                    return "Chị họ (con bác)"
                                elif "đời 2" in partner_term:
                                    return "Chị họ"
                                else:
                                    return "Chị họ"
                            else:
                                # Người đồng hành gọi anh em họ nữ -> giữ nguyên
                                return partner_term
                    
                    # Quy tắc 2: Anh chị em ruột trực tiếp (Direct siblings) - bỏ hậu tố giới tính, giữ cấp bậc
                    elif "trai" in partner_term or "gái" in partner_term:
                        # Bỏ "trai" hoặc "gái" và giữ thuật ngữ gốc
                        if "Anh" in partner_term:
                            return "Anh"
                        elif "Chị" in partner_term:
                            return "Chị"
                        elif "Em" in partner_term:
                            return "Em"
                    
                    # Quy tắc 3: Anh/Chị/Em chung (Generic Anh/Chị/Em - không họ, không trai/gái) - giữ nguyên
                    else:
                        return partner_term

                
                # Các ánh xạ đặc biệt cho các thuật ngữ bác/chú/cô/dì
                if partner_term == "Chú":
                    return "Thím"
                elif partner_term == "Cậu":
                    return "Mợ"
                elif partner_term in ["Cô", "Dì"]:
                    return "Dượng"
                elif partner_term == "Bác":
                    return "Bác gái" if is_me_male == False else "Bác"
                
                # Cho tất cả các trường hợp khác: giữ nguyên thuật ngữ
                return partner_term


        return None

    # Tạo mô tả chi tiết từng bước (giữ lại để bổ trợ)
    description_parts = []
    for i in range(len(nodes) - 1):
        n1, n2, rel = nodes[i], nodes[i+1], rels[i]
        rel_type = rel.get('type', '')
        
        # Xử lý quan hệ VỢ/CHỒNG (SPOUSE)
        if rel_type == 'SPOUSE':
            gender = n1.get('gender')
            is_male = gender in ['male', 'nam']
            role = "Chồng" if is_male else "Vợ"
            description_parts.append(f"{n1['name']} là {role} của {n2['name']}")
        # Xử lý các quan hệ BỐ/MẸ (PARENT)
        elif rel['start'] == n1['id']:
            # n1 là bố/mẹ của n2
            if rel_type == 'FATHER_OF':
                role = "Cha"
            elif rel_type == 'MOTHER_OF':
                role = "Mẹ"
            else:
                # Fallback to gender
                role = "Cha" if (n1.get('gender') == 'male' or n1.get('gender') == 'nam') else "Mẹ"
            description_parts.append(f"{n1['name']} là {role} của {n2['name']}")
        else:
            # n1 là con của n2
            gender = n1.get('gender')
            is_male = gender in ['male', 'nam']
            role = "Con trai" if is_male else "Con gái"
            description_parts.append(f"{n1['name']} là {role} của {n2['name']}")
    
    summary = get_summary_term(nodes, rels)
    detailed = ". ".join(description_parts) + "." if description_parts else ""
    
    result = {
        "relationship": detailed,
        "summary": summary or "Họ hàng",
        "detailed": detailed,
        "path": [n['id'] for n in nodes]
    }
    
    if summary:
        if detailed:
            result["relationship"] = f"{nodes[0]['name']} là {summary} của {nodes[-1]['name']}. ({detailed})"
        else:
            result["relationship"] = f"{nodes[0]['name']} là {summary} của {nodes[-1]['name']}."
    
    return result

