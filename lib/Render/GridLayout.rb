require 'DebugLog'

class GridLayout
  include DebugLog
  
  DEFAULT_NODE_DIMENSIONS = { :width => 100, :height => 100 }
  DEFAULT_NODE_SPACING = { :x => 300, :y => 100 }

  attr_accessor :node_dimensions
  attr_accessor :node_spacing

  def initialize()
    @node_dimensions = DEFAULT_NODE_DIMENSIONS
    @node_spacing = DEFAULT_NODE_SPACING
  end
  
  def layout(sugar)
    do_initial_layout(sugar)
  end
  
  def do_initial_layout(sugar)
    sugar.breadth_first_traversal { |res|
      if ( res.dimensions[:width] == 0 && res.dimensions[:height] == 0 )
        res.dimensions = DEFAULT_NODE_DIMENSIONS
        res.position[:x2] = res.position[:x1] + res.dimensions[:width]
        res.position[:y2] = res.position[:y1] + res.dimensions[:height]
      end

      if ( ! res.parent )
        res.move(0,0)
      else
        linkage = res.linkage_at_position()
        link_pos = res.paired_residue_position()
        case link_pos
          when 0
            delta = { :x => 200, :y => 0}
          when 2
            delta = { :x => 0, :y => -200 }
          when 3
            delta = { :x => 200, :y => -200 }
          when 4
            delta = { :x => 200, :y => 0 }
          when 6
            delta = { :x => 200, :y => 200 }
          when 8
            delta = { :x => 0, :y => 200}
          else
            delta = { :x => 200, :y => 0 }
        end
        res.translate(delta[:x],delta[:y])
      end
    }
  end
  
end