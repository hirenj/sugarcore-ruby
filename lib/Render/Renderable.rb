module Rectangle
  def height
    (self[:y2] - self[:y1]).abs
  end
  
  def width
    (self[:x2] - self[:x1]).abs
  end

  def centre
    { :x => ( self[:x1] + self[:x2] ) / 2 , :y => ( self[:y1] + self[:y2] ) / 2 }
  end
  
end

module Renderable
  
  attr_accessor :position, :prototype, :dimensions, :labels, :callbacks

  def callbacks
    if ( ! @callbacks )
      @callbacks = Array.new()
    end
    @callbacks
  end

  def labels
    if ( ! @labels )
      @labels = Array.new()
    end
    @labels
  end

  def centre
    { :x => ( position[:x1] + position[:x2] ) / 2 , :y => ( position[:y1] + position[:y2] ) / 2 }
  end

  def dimensions
    if ( @dimensions == nil )
      return { :width => 0, :height => 0}
    end
    return @dimensions
  end

  def width
    return position[:x2] - position[:x1]
  end

  def height    
    return position[:y2] - position[:y1]
  end

  def distance(other)
    p1 = centre
    p2 = other.centre
    Math.sqrt((p1[:x] - p2[:x])**2 + (p1[:y] - p2[:y])**2)
  end

  def position 
    if (@position == nil)
      @position = { :x1 => 0, :x2 => dimensions[:width], :y1 => 0, :y2 => dimensions[:height] }.extend(Rectangle)
    end
    return @position
  end

  def translate(deltax=0,deltay=0)
    move(deltax,deltay)
  end

  def move(deltax=0, deltay=0)
    position[:x1] = position[:x1] + deltax
    position[:x2] = position[:x2] + deltax
    position[:y1] = position[:y1] + deltay
    position[:y2] = position[:y2] + deltay
  end

  def move_absolute(new_x,new_y)
    delta_x = position[:x1] - new_x
    delta_y = position[:y1] - new_y
    translate(delta_x,delta_y)
  end

  def move_box(new_x,new_y)
    current_box = box
    delta_x = new_x - box[:x1]
    delta_y = new_y - box[:y1]
    translate(delta_x,delta_y)
  end
  
end

module Renderable::Residue
  include Renderable
  
  attr_accessor :offsets
  
  def translate(deltax=0,deltay=0)
    move(deltax,deltay)
    children.each { |child|
      child[:residue].translate(deltax,deltay)
    }
  end
  
  def offset( linkage )
    if ( an_offset = offsets[linkage.get_position_for(self)] ) != nil
      return  an_offset
    end
    offsets[1]
  end

  def offsets
    if ( @offsets == nil || @offsets.length == 0 )
      return { 0 => nil, 1 => { :x => 50, :y => 50 } }
    end
    @offsets
  end

  def box
    min_x = nil
    min_y = nil
    max_x = nil
    max_y = nil

    children.each { |child|
      link_box = child[:link].get_paired_residue(self).box

      if min_x == nil || link_box[:x1] < min_x
        min_x = link_box[:x1]
      end
      if max_x == nil || link_box[:x2] > max_x
        max_x = link_box[:x2]
      end
      if min_y == nil || link_box[:y1] < min_y
        min_y = link_box[:y1]
      end
      if max_y == nil || link_box[:y2] > max_y
        max_y = link_box[:y2]
      end      
    }
    if min_x == nil || position[:x1] < min_x
      min_x = position[:x1]
    end
    if min_y == nil || position[:y1] < min_y
      min_y = position[:y1]
    end
    if max_x == nil || position[:x2] > max_x
      max_x = position[:x2]
    end
    if max_y == nil || position[:y2] > max_y
      max_y = position[:y2]
    end

    return { :x1 => min_x, :x2 => max_x, :y1 => min_y, :y2 => max_y }.extend(Rectangle)

  end
  
end

module Renderable::Link
  include Renderable
  
  def position
    left_residue = second_residue
    right_residue = first_residue

    if first_residue.position[:x1] < second_residue.position[:x2]
      left_residue = first_residue
      right_residue = second_residue
    end

    bottom_residue = second_residue
    top_residue = first_residue
    
    if first_residue.position[:y1] < second_residue.position[:y2]
      bottom_residue = first_residue
      top_residue = second_residue
    end

    result= { :x1 => left_residue.position[:x1] + left_residue.offset(self)[:x],
      :x2 => right_residue.position[:x1] + right_residue.offset(self)[:x],
      :y1 => bottom_residue.position[:y1] + bottom_residue.offset(self)[:y],
      :y2 => top_residue.position[:y1] + top_residue.offset(self)[:y],
    }.extend(Rectangle)
    if bottom_residue != left_residue
      result[:y1] = top_residue.position[:y1] + top_residue.offset(self)[:y]
      result[:y2] = bottom_residue.position[:y1] + bottom_residue.offset(self)[:y]
    end
    return result
  end

  def length
    Math.hypot(width,height)
  end

  def box
    min_x = nil
    min_y = nil
    max_x = nil
    max_y = nil
    
    if min_x == nil || position[:x1] < min_x
      min_x = position[:x1]
    end
    if min_y == nil || position[:y1] < min_y
      min_y = position[:y1]
    end
    if max_x == nil || position[:x2] > max_x
      max_x = position[:x2]
    end
    if max_y == nil || position[:y2] > max_y
      max_y = position[:y2]
    end

    node = nil

    if first_residue.node_number > second_residue.node_number
      node = first_residue
    else
      node = second_residue
    end
    
    node_box = node.box
    
    if min_x == nil || node_box[:x1] < min_x
      min_x = node_box[:x1]
    end
    if max_x == nil || node_box[:x2] > max_x
      max_x = node_box[:x2]
    end
    if min_y == nil || node_box[:y1] < min_y
      min_y = node_box[:y1]
    end
    if max_y == nil || node_box[:y2] > max_y
      max_y = node_box[:y2]
    end
    
    return { :x1 => min_x, :x2 => max_x, :y1 => min_y, :y2 => max_y }.extend(Rectangle)

  end  

end

module Renderable::Sugar
  include Renderable
  
  def self.extend_object(sug)
    sug.residue_composition.each { |res|
      res.extend(Renderable::Residue)
      if res.parent != nil
        res.linkage_at_position.extend(Renderable::Link)
      end
    }
    super
  end
  
  def overlays
    @overlays = Array.new() unless @overlays
    @overlays
  end

  def underlays
    @underlays = Array.new() unless @underlays
    @underlays
  end

  
  def box
    @root.box
  end
    
end
