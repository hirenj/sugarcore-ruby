require "DebugLog"

class CondensedLayout
  include DebugLog

  DEFAULT_NODE_DIMENSIONS = { :width => 100, :height => 100 }
  DEFAULT_NODE_SPACING = { :x => 150, :y => 100 }

  attr_accessor :node_dimensions
  attr_accessor :node_spacing
  attr_accessor :seen_stubs

  def initialize()
    @node_dimensions = DEFAULT_NODE_DIMENSIONS
    @node_spacing = DEFAULT_NODE_SPACING
  end

  def layout(sugar)
    remove_layout(sugar)
    do_initial_layout(sugar)
    do_box_layout(sugar)
    do_center_boxes_more(sugar)
    do_sibling_bunching(sugar)
    do_tree_straightening(sugar)
    do_multi_residue_widening(sugar)
  end

  def remove_layout(sugar)
    @seen_stubs = []
    sugar.residue_composition.each { |res|
      res.position[:x1] = 0
      res.position[:y1] = 0
      res.dimensions[:width] = 0
      res.dimensions[:height] = 0
    }
  end

  def do_initial_layout(sugar)
    @seen_stubs = []
    sugar.depth_first_traversal { |res| 
      if ( res.dimensions[:width] == 0 && res.dimensions[:height] == 0 )
        res.dimensions = DEFAULT_NODE_DIMENSIONS
        res.position[:x2] = res.position[:x1] + res.dimensions[:width]
        res.position[:y2] = res.position[:y1] + res.dimensions[:height]
      end
      y_offset = ( 1 - res.children.length ) * node_spacing[:y]
      res.children.each { |child|
        child[:residue].move(res.position[:x2] + node_spacing[:x] ,y_offset + res.position[:y1])
        y_offset = y_offset + node_dimensions[:height] + node_spacing[:y]
      }
    }
  end
  
  def do_box_layout(sugar)
    sugar.leaves.each { |residue|
      sugar.node_to_root_traversal(residue) { |res|
        if res.parent != nil
          res_box = res.box
          siblings = res.parent.children.collect { |c| c[:residue] }.delete_if {|r| r == res }
          siblings -= seen_stubs
          siblings.each { |sibling|
            sib_box = sibling.box
            if (inter_box = calculate_intersection(sib_box, res_box)) != nil
              spread_siblings(res.parent, inter_box.height)
              res_box = res.box
            end
          }
        end
      }
    }
  end

  def spread_siblings(node, delta)
    return if (delta == 0)
    kids = node.children.collect { |child| child[:residue] }
    above_kids = 1
    below_kids = node.children.collect { |child| child[:residue] }.delete_if { |res|
      res.position[:y1] < 0
    }.length
    kids.each { |kid|
      if (kid.position[:y1] < 0)
        kid.translate(0,-1 * below_kids * delta)
        below_kids = below_kids - 1
      elsif (kid.position[:y1] > 0)
        kid.translate(0,delta * above_kids )
        above_kids = above_kids + 1
      end
    }
  end

  def do_make_stub_residues(sugar)
    sugar.leaves.collect { |r| r.parent }.uniq.each { |r|
      make_children_stubs(r)
    }
  end

  def make_children_stubs(node)
    stubs = node.children.collect { |c| c[:residue] }.delete_if { |r| r.children.size > 0 }.sort_by { |r| r.paired_residue_position }
    stubs = stubs.delete_if { |r| [4,5].include? r.paired_residue_position }
    return if stubs.size > 3
    return if stubs.collect { |r| r.paired_residue_position } == [3,6]
    if stubs[2] != nil
      stubs[2].move_absolute(node.position[:x1],node.position[:y2] + node_spacing[:y])
      stubs[1].move_absolute(node.position[:x2] + node_spacing[:x],node.position[:y1])
      stubs[0].move_absolute(node.position[:x1], node.position[:y1] - node_spacing[:y] - stubs[0].dimensions[:height])
      seen_stubs << stubs[0]
      seen_stubs << stubs[1]
      seen_stubs << stubs[2]
    elsif stubs[1] != nil
      stubs[1].move_absolute(node.position[:x1],node.position[:y2] + node_spacing[:y])
      stubs[0].move_absolute(node.position[:x1], node.position[:y1] - node_spacing[:y] - stubs[0].dimensions[:height])
      seen_stubs << stubs[0]
      seen_stubs << stubs[1]
    elsif stubs[0] != nil && node.children.size > 1
      stubs[0].move_absolute(node.position[:x1], node.position[:y1] - node_spacing[:y] - stubs[0].dimensions[:height])
      seen_stubs << stubs[0]
    end
  end

  def do_tree_straightening(sugar)
    sugar.residue_composition.each { |r|
      kids = r.children.collect { |c| c[:residue] }.delete_if { |res| seen_stubs.include?(res) }
      if kids.size == 1
        kid = kids[0]
        delta = kid.position[:y1] - r.position[:y1]
        kid.translate(0,delta * -1)
      end
    }
  end

  def do_sibling_bunching(sugar)
    (0..(sugar.residue_height-1)).to_a.reverse.each { |dep|
      sugar.residues_at_depth_by_parent(dep).each { |sib_group|        
        group_siblings(sib_group)
      }
    }
  end

  def group_siblings(siblings)
    if ! siblings.is_a? Array
      siblings = [siblings]
    end
    siblings = siblings.sort_by { |r| r.position[:y1].abs }.delete_if { |res| seen_stubs.include?(res) }
    
    return unless siblings[0] && siblings[0].parent
    
    parent = siblings[0].parent
    
    center_y = parent.position[:y1]
    
    positive_siblings = siblings.select { |r| r.position[:y1] > center_y }
    negative_siblings = siblings - positive_siblings
    
    first_down = negative_siblings[0]
    first_up = positive_siblings[0]
    
    delta = 0
    
    delta = first_up.box[:y1] - first_down.box[:y2] - DEFAULT_NODE_SPACING[:y] if (first_up && first_down)
    
    if delta > 0
      first_up.move_box(first_up.position[:x1], center_y )
      first_down.move_box(first_down.position[:x1], center_y - DEFAULT_NODE_SPACING[:y] - first_down.box.height)
    end
    
    current = positive_siblings.shift    
    while positive_siblings.size > 0
      current_box = current.box
      next_sib = positive_siblings[0]
      next_sib.move_box(next_sib.position[:x1],current_box[:y2] + DEFAULT_NODE_SPACING[:y])
      current = positive_siblings.shift
    end
    current = negative_siblings.shift
    while negative_siblings.size > 0
      current_box = current.box
      next_sib = negative_siblings[0]
      next_sib_box = next_sib.box
      next_sib.move_box(next_sib.position[:x1],current_box[:y1] - DEFAULT_NODE_SPACING[:y] - next_sib_box.height)
      current = negative_siblings.shift
    end

  end

  def do_center_boxes_more(sugar)
    (0..(sugar.residue_height-1)).to_a.reverse.each { |dep|
      sugar.residues_at_depth_by_parent(dep).each { |sib_group|
        
#        y1s = sib_group.collect { |r| r.position[:y1] }
#        new_y1 = ((y1s.max - y1s.min) / 2) + y1s.min
        
        if sib_group[0] != nil && sib_group[0].parent != nil
          par_res = sib_group[0].parent
          res_center = par_res.center
          curr_center = par_res.box.center
          delta = curr_center[:y] - res_center[:y]
          par_res.move(0,delta)
        end
      }
    }    
  end

  def do_multi_residue_widening(sugar)
    sugar.breadth_first_traversal { |res| 
      if res.children.size > 4
        multiplier = (res.children.size - 4)
        res.children.each { |child|
          child[:residue].translate(multiplier * DEFAULT_NODE_SPACING[:x],0)
        }
      end
    }    
  end

  def calculate_intersection(rec1, rec2)
    if (rec1[:x1] < rec2[:x1])
      left_rec = rec1
      right_rec = rec2
    else
      left_rec = rec2
      right_rec = rec1
    end
    if (rec1[:y1] < rec2[:y1])
      bottom_rec = rec1
      top_rec = rec2
    else
      bottom_rec = rec2
      top_rec = rec1
    end
    
    contained_x = ( left_rec[:x2] > right_rec[:x2] )
    contained_y = ( bottom_rec[:y2] > top_rec[:y2] )
    
    intersected = { :x1 => right_rec[:x1],
                    :x2 => contained_x ? right_rec[:x2] : left_rec[:x2] ,
                    :y1 => top_rec[:y1],
                    :y2 => bottom_rec[:y2] }.extend(Rectangle)
#                      :y2 => contained_y ? top_rec[:y2] : bottom_rec[:y2] }
    
    if ((intersected[:x2] - intersected[:x1]) >= 0 && (intersected[:y2] - intersected[:y1]) >= 0)
      return intersected
    else
      return nil
    end
  end
end