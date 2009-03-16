require "DebugLog"

class CondensedScalableLayout < CondensedLayout
  include DebugLog
  
  attr_accessor :scaling_symbol
  
  def initialize()
    super()
    @scaling_symbol = :hots
  end
  
  # Rules for layout of sugars
  # If there's a Type I/II chain put that in the centre, and put the decorations on opposite sides
  # If there are two Type I/II chains as children, split the difference
  # GlcNAc residues that are children of Man should be straight across
  def layout(sugar)
    # otherwise use standard layout for non moved residues?
    remove_layout(sugar)
    do_initial_layout(sugar)
    setup_scaling(sugar)
    setup_lacnacs(sugar)
    seen_residues = do_chain_layout(sugar)
    seen_residues += do_stubs(sugar,seen_residues)
    do_basic_layout(sugar,seen_residues)
    do_box_layout(sugar)
    do_sibling_bunching(sugar)
    do_center_boxes_more(sugar)
    do_sibling_bunching(sugar)
    do_multi_residue_widening(sugar)
  end

  def do_multi_residue_widening(sugar)
    sugar.breadth_first_traversal { |res| 
      res_kids = res.children.reject { |r| r[:residue].is_stub? }
      if res_kids.size > 4
        multiplier = (res_kids.size - 4)
        res_kids.each { |child|
          child[:residue].translate(multiplier * DEFAULT_NODE_SPACING[:x],0)
        }
      end
    }    
  end

  def setup_scaling(sugar)    
    return unless sugar.root.respond_to?(self.scaling_symbol)
    sugar.residue_composition.each { |res|
      res.scale_by_factor(Math.log(Math.log(res.method(self.scaling_symbol).call)+10))
      res.position[:x2] = res.position[:x1] + res.dimensions[:width]
      res.position[:y2] = res.position[:y1] + res.dimensions[:height]
    }
  end

  def setup_lacnacs(sugar)
    lacnacs = sugar.residue_composition.select { |r| r.name(:ic) == 'GalNAc' && r.parent && r.parent.name(:ic) == 'GlcNAc'}
    lacnacs.each { |lacnac|
      lacnac.scale_by_factor(0.5)
      lacnac.position[:x2] = lacnac.position[:x1] + lacnac.dimensions[:width]
      lacnac.position[:y2] = lacnac.position[:y1] + lacnac.dimensions[:height]
    }
  end

  def do_center_boxes_more(sugar)
    (0..(sugar.residue_height-1)).to_a.reverse.each { |dep|
      sugar.residues_at_depth_by_parent(dep).each { |sib_group|

        if sib_group[0] != nil && sib_group[0].parent != nil
          par_res = sib_group[0].parent
          res_center = par_res.centre
          kid_box = (par_res.children.reject { |child| child[:residue].is_stub? }.collect{ |child| child[:residue].box {|r| ! r.is_stub? } }.inject(nil) { |curr_box,a_box|
            a_box.union(curr_box)
          } || next)
          curr_center = kid_box.centre
          if par_res.position[:y2] < kid_box[:y1] || par_res.position[:y1] > kid_box[:y2]
            delta = curr_center[:y] - res_center[:y]
            par_res.move(0,delta)
            par_res.children.select {|child| child[:residue].is_stub? }.each { |child|
              child[:residue].move(0,delta)
            }            
          end
          
        end
      }
    }    
  end

  def group_siblings(siblings)
    if ! siblings.is_a? Array
      siblings = [siblings]
    end
    siblings = siblings.sort_by { |r| r.position[:y1].abs }.delete_if { |res| res.is_stub? }
    
    return unless siblings[0] && siblings[0].parent
    
    parent = siblings[0].parent
    
    center_y = parent.position[:y1]
    
    positive_siblings = siblings.select { |r| r.position[:y1] > center_y }
    
    center_residues = siblings.select { |r| r.position[:y1] == center_y }
    
    positive_minimum = (center_residues.collect { |r| r.box[:y2] }).max || center_y
    negative_minimum = (center_residues.collect { |r| r.box[:y1] }).min || center_y
    
    negative_siblings = siblings.select { |r| r.position[:y1] < center_y }
    
    first_down = negative_siblings[0]
    first_up = positive_siblings[0]
    
    delta = 0
    
    first_down_top = first_down ? first_down.box[:y2] : positive_minimum
    first_up_bottom = first_up ? first_up.box[:y1] : negative_minimum
        
    delta = first_up_bottom - first_down_top - node_spacing[:y]
    
    if delta > 0
      first_up.move_box(first_up.position[:x1], positive_minimum ) if first_up
      first_down.move_box(first_down.position[:x1], negative_minimum - node_spacing[:y] - first_down.box.height) if first_down
    end
    
    current = positive_siblings.shift    
    while positive_siblings.size > 0
      current_box = current.box
      next_sib = positive_siblings[0]
      next_sib.move_box(next_sib.position[:x1],current_box[:y2] + node_spacing[:y])
      current = positive_siblings.shift
    end
    current = negative_siblings.shift
    while negative_siblings.size > 0
      current_box = current.box
      next_sib = negative_siblings[0]
      next_sib_box = next_sib.box
      next_sib.move_box(next_sib.position[:x1],current_box[:y1] - node_spacing[:y] - next_sib_box.height)
      current = negative_siblings.shift
    end

  end

  def do_stubs(sugar,seen_residues)
    stub_residues = sugar.residue_composition.select { |res|
      ! seen_residues.include?(res) &&
      [2,3,4,6].include?(res.paired_residue_position) &&
      ( ["Fuc","NeuAc", "NeuGc"].include?(res.name(:ic)) ||
      (["Gal","GalNAc"].include?(res.name(:ic)) && res.anomer == 'a') ||
      (["GalNAc"].include?(res.name(:ic)) && res.anomer == 'b' && res.paired_residue_position == 4)
      ) &&
      res.siblings.size > 0
    }
    stub_residues.each { |res|
      if res.paired_residue_position <= res.siblings[0].paired_residue_position
        res.move_absolute(res.parent.position.centre[:x]-0.5*res.dimensions[:width],res.parent.position[:y1]-node_spacing[:y]-res.dimensions[:height])
      else
        res.move_absolute(res.parent.position.centre[:x]-0.5*res.dimensions[:width],node_spacing[:y]+res.parent.position[:y2])      
      end
      
      # We need to set the linkage endpoint offset to the centre of the residue
      
      def res.offset(linkage)
        { :x => dimensions[:width] / 2, :y => dimensions[:height] / 2 }
      end
      
      def res.is_stub?
        true
      end
    }
    stub_residues
  end

  def do_basic_layout(sugar,laid_out_residues)
    debug("These are the laid out already residues")
    laid_out_residues.each{ |res|
      debug(sugar.sequence_from_residue(res))
    }
    
    debug("Laid out residues #{laid_out_residues.collect {|r| r.name(:ic)+"#{r.paired_residue_position}"}.join(',')}")
    
    sugar.depth_first_traversal { |res| 
      kid_size = 0
      kids_to_layout = res.children.reject { |kid| 
        (kid[:residue].is_stub? && (kid_size += kid[:residue].dimensions[:height]) > 0) ||
        (laid_out_residues.include?(kid[:residue]) && ! kid[:residue].is_chain_start?)
      }
      if kids_to_layout.size <= 1
        y_offset = 0
      else
        kid_size -= kids_to_layout[0][:residue].dimensions[:height]
        y_offset = 0.5 * ( ( 1 - kids_to_layout.length ) * node_spacing[:y] + kid_size )
      end
      debug("Total kids to lay out #{kids_to_layout.size}")
      debug("Starting y_offset is #{y_offset}")
      res.children.each { |child|
        if laid_out_residues.include?(child[:residue])
          debug("I have laid out #{child[:residue].name(:ic)}")
          if ! child[:residue].is_chain_start?
            debug("But i am skipping #{child[:residue].name(:ic)} on pos #{child[:residue].paired_residue_position} because it's not a chain start")
            next
          end
        end
        delta_x = node_spacing[:x] + res.dimensions[:width]
        if child[:residue].is_chain_start?
          debug("I am a chain start")
          delta_x = 0
        end
        # if child[:residue].siblings.select { |sib| laid_out_residues.include?(sib) && ! sib.is_stub? }.size > 0
        #   y_offset += 2 * node_spacing[:y] + child[:residue].dimensions[:height]
        # end
        debug("Doing a standard layout for children of #{sugar.sequence_from_residue(res)}, shifting a kid #{delta_x},#{y_offset}")
        child[:residue].translate(delta_x ,y_offset)
        y_offset += node_spacing[:y] + child[:residue].dimensions[:height]
        debug("y_offset now is #{y_offset}")
      }
    }    
  end

  # Layout chains as straight lines
  # Layout decorations on chains as fanning out from the base of the chain
  def do_chain_layout(sugar)  
    seen_chains = []
    sugar.residue_composition.select { |r| ['GlcNAc','Gal'].include?(r.name(:ic)) }.each { |chain_start|
      debug("CHAIN:Start residue name is #{chain_start.name(:ic)}")
      next if seen_chains.include?(chain_start)
      debug("CHAIN:Not seen before")
      child_chains = sugar.get_chains_from_residue(chain_start).sort_by { |chain| chain.size }
      debug("CHAIN:In total there are #{child_chains.size} chains from this position")
      child_chains.each { |child_chain|
        debug("CHAIN:A chain size is #{child_chain.size}")
        next unless child_chain.size > 1
        info("Doing a chain layout")
        chain_desc = child_chain.collect {|r| r.name(:ic)+"#{r.anomer},#{r.paired_residue_position}"}.join(',')
        debug("CHAIN:Chain is #{chain_desc}")

        chain_end = child_chain[-1]
        
        child_chain.reject! { |c| seen_chains.include?(c) }

        if child_chain.size > 0
          layout_chain(child_chain)
          seen_chains += child_chain
        end
        debug("CHAIN:Trying to arrange children for #{chain_end.name(:ic)}")
        
        layout_chain_terminals(chain_end)

        seen_chains += (sugar.residue_composition(chain_end))[1..-1]
      }
    }
    return seen_chains
    # All chains should be starting at 0,0 and be laid out as straight (or shifted up for 6) lines
  end
  
  def layout_chain(chain)
#    to_edit = ['Gal','GlcNAc'].include?(chain[0].parent.name(:ic)) ? chain : chain[0..-1]
    to_edit = chain
    chain_start = chain[0]
    debug("CHAINLAYOUT:Setting chain start flag on #{chain[0].name(:ic)}#{chain[0].anomer}#{chain[0].paired_residue_position}")
    chain_desc = to_edit.collect {|r| r.name(:ic)+"#{r.anomer}#{r.paired_residue_position}"}.join(',')
    debug("CHAIN:Chain is #{chain_desc}")

    def chain_start.is_chain_start?
      true
    end
    to_edit.each { |residue|
      next unless residue.parent
      x_delta = node_spacing[:x] + residue.parent.dimensions[:width]
      y_delta = 0
      # Push up the 6-linkage
      if residue.paired_residue_position == 6
          debug("CHAINLAYOUT:Pushing up the y delta for a 6-chain")
          y_delta = residue.dimensions[:height] + node_spacing[:y] 
      end
      
      if residue.name(:ic) == 'Gal'
        debug("CHAINLAYOUT:Pushing up the y delta for a Gal-multiple-chain")
        max_sibling_height = residue.siblings.select { |r| r.name(:ic) == 'Gal' && r.anomer == 'b' }.collect { |r| r.dimensions[:height]}.max || 0
        debug("CHAINLAYOUT:Max sibling height is #{max_sibling_height} total ")
        y_delta = residue.paired_residue_position == 3 ? -0.5*(node_spacing[:y]+max_sibling_height) : 0.5*(node_spacing[:y]+max_sibling_height)
        if residue.siblings.select { |r| r.name(:ic) == 'Gal' && r.anomer == 'b'}.size == 0
          y_delta = 0
        end
      end
      
      residue.translate(x_delta,y_delta)
    }
  end

  def layout_chain_terminals(res)
    kid_size = 0
    kids_to_layout = res.children.reject { |kid| kid[:residue].is_stub? && (kid_size += kid[:residue].dimensions[:height]) > 0 }
    if kids_to_layout.size <= 1
      y_offset = 0
    else
      kid_size -= kids_to_layout[0][:residue].dimensions[:height]
      y_offset = 0.5 * ( ( 1 - kids_to_layout.length ) * node_spacing[:y] + kid_size )
    end
    debug("Starting y_offset is #{y_offset}")
    res.children.each { |child|
      delta_x = node_spacing[:x] + res.dimensions[:width]
      if child[:residue].is_chain_start?
        delta_x = 0
      end
      child[:residue].translate(delta_x ,y_offset)
      y_offset += node_spacing[:y] + child[:residue].dimensions[:height]
      debug("y_offset now is #{y_offset}")
    }
  end


  def do_box_layout(sugar)
    sugar.leaves.each { |residue|
      sugar.node_to_root_traversal(residue) { |res|
        if res.parent != nil
          res_height = sugar.residue_height(res,true)
          siblings = res.siblings.reject { |r| r.is_stub? }
          siblings -= seen_stubs
          siblings.each { |sibling|
            sib_height = sugar.residue_height(sibling,true)
            min_height = [res_height,sib_height].min
            debug("Minimum height is res #{res_height}, sib #{sib_height}")
            debug("Sibling currently at depth #{sugar.depth(sibling)} test res at #{sugar.depth(res)}")
            debug(sugar.sequence_from_residue(sibling)+sibling.anomer+sibling.paired_residue_position.to_s)
            debug(sugar.sequence_from_residue(res)+res.anomer+res.paired_residue_position.to_s)

            res_box = res.children_box { |r|
              ! r.is_stub? &&
              sugar.depth(r) <= min_height &&
              ! (['Gal','GalNAc'].include?(r.name(:ic)) && r.anomer == 'a' && r.paired_residue_position == 3)
            }

            sib_box = sibling.children_box { |r|
              ! r.is_stub? &&
              sugar.depth(r) <= min_height &&
              ! (['Gal','GalNAc'].include?(r.name(:ic)) && r.anomer == 'a' && r.paired_residue_position == 3)
            }
            next unless sib_box && res_box
            if (inter_box = calculate_intersection(sib_box, res_box)) != nil
              debug("Spreading siblings")
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
    kids = node.children.reject { |r| r[:residue].is_stub? }.collect { |child| child[:residue] }
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

  def remove_layout(sugar)
    @seen_stubs = []
    sugar.residue_composition.each { |res|
      res.position[:x1] = 0
      res.position[:y1] = 0
    }
  end

  def do_initial_layout(sugar)
    sugar.depth_first_traversal { |res| 
      if ( res.dimensions[:width] == 0 && res.dimensions[:height] == 0 )
        res.dimensions = DEFAULT_NODE_DIMENSIONS
      end
      res.position[:x2] = res.position[:x1] + res.dimensions[:width]
      res.position[:y2] = res.position[:y1] + res.dimensions[:height]
      def res.is_stub?
        false
      end
      def res.is_chain_start?
        false
      end
    }
  end

end