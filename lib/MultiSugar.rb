require 'SugarException'

module Sugar::MultiResidue
  def can_accept?(linkage)
    true
  end

  def parent
    self.residue_at_position(@parent_position)[0]
  end

  def residue_at_position(attachment_position)
    if (attachment_position == @parent_position && attachment_position_consumed?(attachment_position) )
      return [ linkage_at_position(attachment_position).get_paired_residue(self) ]
    end
    kids = children.delete_if { |child| child[:link].get_position_for(self) != attachment_position }.collect { |child| child[:residue] }
    return kids
  end

  def paired_residue_position(attachment_position=@parent_position)
    if (linkage_at_position(attachment_position) == nil)
      return nil
    end
    linkage_at_position(attachment_position).get_position_for(residue_at_position(attachment_position)[0])
  end
  
  def linkage_at_position(attachment_position=@parent_position)
    if attachment_position == @parent_position 
      return @ring_positions[attachment_position]
    end    
    return children.delete_if { |child| child[:link].get_position_for(self) != attachment_position }.collect { child[:link] }
  end
  
  def add_child(mono,linkage)
    mono.residue_composition.each { |res|
      res.extend(Sugar::MultiResidue)
    }
    super(mono,linkage)
  end
end

module Sugar::MultiSugar

  def monosaccharide_factory(proto)
    mono = super(proto)
    mono.extend(Sugar::MultiResidue)
    mono
  end

  def get_unique_sugar
    leaf_paths = leaves.collect { |leaf| get_sugar_to_root(leaf) }
    result = leaf_paths.shift.extend( Sugar::MultiSugar )
    leaf_paths.each { |leaf_sug|
      result.union!(leaf_sug.extend( Sugar::MultiSugar ))
    }      
    result
  end

  def find_residue_by_linkage_path(path)
    results = [@root]
  	while (path || []).size > 0
  	  path_element = path.shift    	  
  	  results = results.collect { |loop_residue|
  	    loop_residue.residue_at_position(path_element)
  	  }.flatten    	  
	  end
	  if results.size > 1
	    puts self.sequence
	    raise SugarException.new("Could not unambiguously find residue along path found instead #{results.size} residues")
    end
  	return results.first  	
  end

  def intersect(sugar,&block)
    matched = Hash.new()
    sugar.paths.each { |path|
      mypath = path.reverse
      path_follower = lambda { |residues, children|
        if residues.is_a? Monosaccharide
          residues = [ residues ]
        end
        test_residue = mypath.shift
        (residues || []).each { |residue|
          test_success = false
          if block_given?
             if yield(residue, test_residue, matched[residue])
               matched[residue] = true
               test_success = true
             end
          else
            if residue.equals?(test_residue)
              matched[residue] = true
              test_success = true
            end
          end
          if test_success && mypath[0] != nil
            path_follower.call(residue.residue_at_position(mypath[0].paired_residue_position()), nil)
          end
        }
        [true]
      }
      perform_traversal_with_algorithm(&path_follower)
    }
    return matched.keys
  end
  
  def self.extend_object(sug)
    sug.residue_composition.each { |res|
      res.extend(Sugar::MultiResidue)
    }
    super
  end

end
