require "DebugLog"
require "Monosaccharide"

# Default implementation of a reader and writer for sugar sequences
# This is automatically added to all Sugar objects
module DefaultReaderWriter

  protected
    # Any mixins for reading sequences must overwrite this method
    def parse_sequence(sequence)
      raise SugarException.new("Could not parse sequence. Perhaps you haven't added parsing capability to this sugar")
    end

    # Any mixins for reading sequences must overwrite this method
    def write_sequence(sequence)
      raise SugarException.new("Could not write sequence. Perhaps you haven't added writing capability to this sugar")
    end

end

# Sugar class for representing sugars for various bioinformatic manipulations
# Since there are circular references within objects, it is very important to 
# finish off all sugars once you are finished with them by calling the finish()
# method.
#   sug = Sugar.new
#   sug.sequence = 'Gal(b1-3)GlcNAc(b1-4)[Fuc(a1-6)]GlcNAc'
#   sug.residue_composition                           # [Gal,GlcNAc,GlcNAc]
#   sug.size                                          # 3
#   sug.breadth_first_traversal { |res| p res.name }  # GlcNAc, GlcNAc, Fuc, Gal
#   sug.depth_first_traversal { |res| p res.name }    # GlcNAc, GlcNAc, Gal, Fuc
#   sug.finish
class Sugar
	  #mixin Debugging tools
    include DebugLog
    include DefaultReaderWriter

    @@seq_hashes = Hash.new()

    attr :root
    attr_accessor :name

    # Finish this sugar by breaking any cyclical references
		def finish
		  if (@root != nil)
		    @root.finish
		    @root = nil
	    end
	  end
		
		# Perform a deep cloning of this sugar - equivalent to creating another 
		# sugar with the same sequence
    def deep_clone
      cloned = self.dup
      cloned.initialize_from_copy(self)
      cloned
    end

		def initialize_from_copy(original)
		  @root = original.get_path_to_root[0].deep_clone
	  end
	  
	  protected :initialize_from_copy

    def eql?(o)
      o.is_a?(Sugar) && sequence == o.sequence
    end
    
    def hash
       if (@@seq_hashes == nil)
        @@seq_hashes = Hash.new()
      end
      seq = self.sequence
      if (@@seq_hashes.has_key?(seq))
        return @@seq_hashes[seq]
      end
      @@seq_hashes[seq] = @@seq_hashes.length + 1
      return @@seq_hashes[seq]
    end
	  
	  def root=(new_root=@root)
      @root = new_root
    end
	  
    # Set the sequence for this sugar. The Sugar must be able to 
    # parse this sequence (done by extending the Sugar), otherwise
    # it will raise a SugarException
    #   sug = Sugar.new()
    #   sug.sequence = 'Gal(b1-3)GlcNAc'    # SugarException => "Could not parse sequence"
    #   sug.extend(Sugar::IO::CondensedIupac::Builder)
    #   sug.sequence = 'Gal(b1-3)GlcNAc'
    #   sug.size                            # 2
    def sequence=(seq)
    	if (@root != nil)
    		finish
    	end
      debug "Input sequence is " + seq
      begin
        @root = parse_sequence(seq)        
      rescue Exception => e
        error "Could not parse the sequence, setting root to nil:\n#{seq}\n\n#{e}\n"+e.backtrace.join("\n")
        @root = nil
        raise SugarException.new("Could not parse the sequence, setting root to nil:\n#{seq}\n\nBase cause: #{e}")
      end      
    end
    
    # Compute the sequence for this sugar. This method is an alias for computing 
    # sequence_from_residue() with a start_residue of root.
    #     sug = Sugar.new()
    #     sug.sequence            # nil
    def sequence
    	sequence_from_residue(@root)
    end
    
    # Create a Sugar object based upon an array of Linkages passed to it. The first
    # linkage in the array will define the root of the Sugar. Will destroy all objects
    # related to the current sugar
    # Doesn't work for more than one linkage at the moment. How do you figure out
    # if the linkages are not from disconnected graphs
    def linkages=(linkages)
      self.finish
      new_residues = Hash.new() { |h,k| h[k] = k.shallow_clone }
      linkages.each { |link|
        parent = new_residues[link[:link].get_paired_residue(link[:residue])]
        child = new_residues[link[:residue]]
        if @root == nil
          @root = parent
        end
        parent.add_child(child,link[:link].deep_clone)
      }
    end

    def linkages(start_residue=@root)
      return residue_composition(start_residue).collect { |r| r.linkage_at_position }
    end

    # Compute the sequence for this sugar from a particular start residue.
    # If no residue is specified, the sequence is calculated from the root 
    # of the sugar.
    def sequence_from_residue(start_residue=@root)
      debug "Creating sequence"
		  write_sequence(start_residue)
    end
    
    # Find the residue composition of this sugar
    def residue_composition(start_residue=@root)
      debug "Un-cached residue_composition #{caller[0]}"
    	return start_residue ? start_residue.residue_composition : []
    end
    
    def size(start_residue=@root)
      return residue_composition(start_residue).size
    end
    
    # Find the residues which comprise this sugar that match a particular prototype
    def composition_of_residue(prototype,start_residue=@root)
      if (prototype.class == String)
        prototype = monosaccharide_factory( prototype )
      end
    	return residue_composition(start_residue).reject { |m|
    	  m.name != prototype.name
    	}
    end    
    
    # Return a string representation of this sugar
    def to_s
        return @root.to_s
    end
    
    # Find the paths from the leaves in this sugar to the root
    def paths(start_residue=@root)
    	return leaves(start_residue).map{ |leaf|
    		get_path_to_root(leaf)
    	}
    end
    
    # List the leaf elements of this sugar - any residues which don't have 
    # any child residues
    def leaves(start_residue=@root)
  		return residue_composition(start_residue).reject { |residue|
  			residue.children.length != 0
  		}    	
    end

    def residue_height(start_residue=@root,absolute=false)      
            
      absolute_depth = leaves(start_residue).collect { |l| get_path_to_root(l).size }.max

      if start_residue == @root
        return absolute_depth
      end

      if ! absolute && start_residue != @root
        absolute_depth -= get_path_to_root(start_residue).size
      end
      return absolute_depth
    end

    def depth(a_residue)
      return get_path_to_root(a_residue).size
    end

    def residues_at_depth(depth,start_residue=@root)
      if depth == 0
        return [start_residue]
      end      
      return leaves(start_residue).collect { |l| get_path_to_root(l).reverse[depth] }.uniq.compact
    end
    
    def residues_at_depth_by_parent(depth,start_residue=@root)
      return [[start_residue]] if (depth == 0)
      
      parents = Hash.new() { |h,k| h[k] = Array.new() }
      residues_at_depth(depth,start_residue).each { |r|
        parents[r.parent] << r
      }
      return parents.values || []
    end
    
    def branch_points
      # Get all GlcNAcs. Add 1 to the branch count if it is a glcnac on a 2/4/6 with a sibling. Add 1 to branch count if no ancestor glcnacs on 3 or 6
      glcnacs = self.residue_composition.select { |r|
        r.name(:ic) == 'GlcNAc' && (r.paired_residue_position || 0) > 0
      }
      glcnacs.reject! { |r|
        r == @root ||
        (r.parent == @root && r.parent.name(:ic) == 'GlcNAc')
      }
      glcnacs.select { |r|
        ([2,4,6].include?(r.paired_residue_position) &&
        (r.siblings.select { |r| r.name(:ic) == 'GlcNAc' && r.paired_residue_position > 0 }.size > 0)) ||
        (! r.parent) || ( r.parent.name(:ic) != 'Gal' && r.anomer != 'b') || ( ! r.parent.parent ) ||
        (r.parent.parent.name(:ic) != 'GlcNAc')
      }
    end
    
    # The path to the root residue from the specified residue
  	def get_path_to_root(start_residue=@root)
  	  @cached_path ||= {}
  	  @cached_path[start_residue] ||= node_to_root_traversal(start_residue)
  	  @cached_path[start_residue]
  	end
    
    def get_sugar_to_root(start_residue=@root)
      new_sugar = self.class.new()
      residues = get_path_to_root(start_residue).reverse
      residues.shift
      if residues.size > 0
        new_sugar.linkages = residues.collect { |r| { :link => r.linkage_at_position, :residue => r } }
      else
        new_sugar.root = @root.shallow_clone
      end
      new_sugar
    end

    def get_sugar_from_residue(start_residue=@root)
      new_sugar = self.class.new()
      new_sugar.root = start_residue.deep_clone
      new_sugar
    end

    def get_unambiguous_path_to_root(start_residue=@root)
  		if ( ! start_residue.parent )
  			return []
  		end
  		linkage = start_residue.linkage_at_position();
  		return [ { :link => linkage.get_position_for(linkage.get_paired_residue(start_residue)), :residue => start_residue },
  				 get_unambiguous_path_to_root(start_residue.parent) ].flatten;
    end

    # The linkage position path from the specified residue to the root.
  	def get_attachment_point_path_to_root(start_residue=@root)
  		if ( ! start_residue.parent )
  			return []
  		end
  		linkage = start_residue.linkage_at_position();
  		return [ linkage.get_position_for(linkage.get_paired_residue(start_residue)),
  				 get_attachment_point_path_to_root(start_residue.parent) ].flatten;
  	end

    def get_chains_from_residue(start_residue=@root)
      if start_residue.name(:ic) == 'GlcNAc' && (start_residue == @root || start_residue.anomer == 'b')
        positions = [3,4]
        next_name = 'Gal'
        if start_residue.parent 
          # Allowed parents of a GlcNAc residue are Man, Gal and GalNAc
          if start_residue.parent.name(:ic) != 'Man' && start_residue.parent.name(:ic) != 'Gal' && start_residue.parent.name(:ic) != 'GalNAc'
            return []
          else
            # Chains coming off Gal should be on a 3 and 6 linkage
            if start_residue.parent.name(:ic) == 'Gal'
              return [] unless [3,6].include?( start_residue.paired_residue_position  )
            end
            # Chains off the core of the O-linked glycans
            if start_residue.parent.name(:ic) == 'GalNAc'
              return [] unless start_residue.parent == @root
            end
          end
        end
      elsif start_residue.name(:ic) == 'Gal' && (start_residue == @root || start_residue.anomer == 'b')
          positions = [3,6]
          next_name = 'GlcNAc'
          if start_residue.parent && ! ['GlcNAc','GalNAc'].include?(start_residue.parent.name(:ic))
            return []
          else
            if start_residue.parent && start_residue.parent.name(:ic) == 'GlcNAc'
              return [] unless [3,4].include?( start_residue.paired_residue_position  )
            end
            if start_residue.parent && start_residue.parent.name(:ic) == 'GalNAc'
              return [] unless [3,4].include?( start_residue.paired_residue_position) && start_residue.parent == @root
            end
          end
        else
          return []
      end
      if positions == nil
        return []
      end
      my_chains = []      
      positions.each { |pos|
        residue = start_residue.residue_at_position(pos)
        if residue && residue.name(:ic) == next_name && residue.anomer == 'b'
          new_chains = get_chains_from_residue(residue).collect {|arr| [start_residue] + arr }
          if new_chains.size == 0
            new_chains = [[start_residue,residue]]
          end
          my_chains += new_chains
        end
      }
      if my_chains.size == 0
        my_chains = [[start_residue]]
      end
      return my_chains
    end


    # Calculate the intersection of two sugars aligned together at the root
    # returns the residues which have matched up with the given sugar
    def intersect(sugar,&block)
      matched = Hash.new()
      sugar.paths.each { |path|
        mypath = path.reverse
        path_follower = lambda { |residue, children|
          if residue
            test_residue = mypath.shift
            test_success = false
            if block_given?
               if yield(residue, test_residue)
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
          end
          [true]
        }
        perform_traversal_with_algorithm(&path_follower)
      }
      return matched.keys
    end

    # Subtract the given sugar from this sugar. Returns a list of residues which exist in this sugar, but do
    # not exist in the sugar given as an argument
    def subtract(sugar, &block)
      matched = self.intersect(sugar,&block)
      residue_composition - matched
    end

    def union(sugar, &block)
      new_sug = self.deep_clone
      new_sug.union!(sugar,&block)
      return new_sug
    end

    def union!(sugar, &block)
      matched_sugar = nil
      if block_given?
        matched_sugar = sugar.subtract(self) { |a,b,c| block.call(b,a,c) }
      else
        matched_sugar = sugar.subtract(self)
      end
      matched_sugar = matched_sugar.delete_if { |res| matched_sugar.include? res.parent }
      matched_sugar.each { |res|
        path = sugar.get_unambiguous_path_to_root(res.parent).reverse
        path_text = path.collect { |path_el| "#{path_el[:link]} -> #{path_el[:residue].anomer} - #{path_el[:residue].name(:ic)}"}.join(',')
        attachment_res = self.find_residue_by_unambiguous_path(path)
        new_res = res.deep_clone
        if attachment_res == nil
          raise SugarException.new("Could not find residue from path #{path_text}")
        end
        attachment_res.add_child(new_res,res.linkage_at_position.deep_clone)
      }      
      return self
    end

    # Run a comparator across the residues in a sugar, passing a block to use as a comparator, and optionally specifying a method
    # to use as a traverser. By default, a depth first traversal is performed.
    # The comparator block for residues is a simple true or false comparator, evaluating to true if the two
    # residues are the same, and false if they are different
    def compare_by_block(sugar, traverser=:depth_first_traversal)
      raise SugarException.new("No comparator block for residues provided") unless ( block_given? )
      raise SugarException.new("Traverser method does not belong to Sugar being compared") unless(
        respond_to?(traverser) && sugar.respond_to?(traverser)
      )
      myresidues = self.method(traverser).call()
      compresidues = sugar.method(traverser).call()
      sugars_equal = true
      while ! myresidues.empty? && ! compresidues.empty? && sugars_equal = yield(myresidues.shift, compresidues.shift)
      end
      return sugars_equal && myresidues.empty? && compresidues.empty?
    end

    def find_residue_by_unambiguous_path(path,&block)
      looper_path = [] + path
    	results = [@root]
    	while (looper_path || []).size > 0
    	  path_element = looper_path.shift
    	  results = results.collect { |loop_residue|
    	    [loop_residue.residue_at_position(path_element[:link])].flatten.select { |res|
    	      if block_given?
    	        yield(res,path_element[:residue])
  	        else
     	        res.equals?(path_element[:residue])  	          
	          end
    	    }
    	  }.flatten    	  
  	  end
  	  if results.size > 1
  	    raise SugarException.new("Could not unambiguously find residue along path found instead #{results.size} residues")
      end
    	return results.first
    end

    # Search for a residue based upon a traversal using the linkage path.
    # FIXME - UNTESTED
    def find_residue_by_linkage_path(linkage_path)
      
    	loop_residue = @root
    	
    	(linkage_path || []).each{ |linkage_position|
    		loop_residue = loop_residue.residue_at_position(linkage_position) || return
    	}
    	return loop_residue
    end

    # Depth first traversal of a sugar. If you pass an optional block to the method, you will visit
    # the residue and perform the block action on that node
    def depth_first_traversal(start_residue=@root)
        dfs = lambda { | start, children |
          begin
            results = []
            if block_given?
              results.push(yield(start))
            else
              results.push(start)
            end
            children.each { |child|
              results += dfs.call( child[:residue], child[:residue].children )
            }
            results
          rescue SugarTraversalBreakSignal
            results
          end
      }
      perform_traversal_with_algorithm(start_residue, &dfs)
    end

    # Breadth first traversal of a sugar. If you pass an optional block to the method, you will visit
    # the residue and perform the block action on that node
    def breadth_first_traversal(start_residue=@root)

      # Scoped variables and blocks - let's see you do this in Java! 
      queue = []
      results = []

      bfs = lambda { | start, children | 
        begin
          if block_given?
            results.push(yield(start))
          else
            results.push(start)
          end
          queue += children.collect { |child| child[:residue] }
          current = queue.shift
          if (current != nil)
            bfs.call( current, current.children )
          else
            results
          end
        rescue SugarTraversalBreakSignal
          results
        end
      }
      perform_traversal_with_algorithm(start_residue, &bfs)
      return results
    end
    
    # Traverse the sugar from a given node to the root of the structure. If you pass an optional
    # block to the method, you will visit the residue and perform the block action on that node
    def node_to_root_traversal(start_residue)
      results = Array.new()
      root_traversal = lambda { | start, children |
        begin
          if block_given?
            results.push(yield(start))
          else
            results.push(start)
          end
          if (start.parent)
            root_traversal.call( start.parent, nil )
          else
            results
          end
        rescue SugarTraversalBreakSignal
          results
        end
      }
      perform_traversal_with_algorithm(start_residue, &root_traversal)
      return results
    end

    # Perform a traversal of the sugar using a specified block to choose residues to
    # traverse over. If no block is given, a depth first search is performed
    # FIXME - This should work a bit more like collect
    def perform_traversal_with_algorithm(start_residue=@root)
      if block_given?
        results = []
        results += yield( start_residue, start_residue.children )
        return results        
      else
        return depth_first_traversal(start_residue)
      end
    end

end
