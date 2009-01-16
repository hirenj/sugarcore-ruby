module Sugar::IO::CondensedIupac::Writer

	def self.append_features(includingClass)
		
		super
				
		@target_namespace = nil
		
		def includingClass.Target_Namespace=(ns)
			@target_namespace = ns
		end

		def includingClass.Target_Namespace
			@target_namespace
		end

	end

  def target_namespace=(ns)
    if ns.is_a? Symbol
      ns = NamespacedMonosaccharide::NAMESPACES[ns]
    end
    @target_namespace = ns
  end

	def target_namespace
	  return @target_namespace if (@target_namespace != nil)

	  return self.class.Target_Namespace() if (self.class.respond_to?(:Target_Namespace) && self.class.Target_Namespace != nil )
		  
	  return @root.class.Default_Namespace
	end

	def write_sequence(root_element)
    string_rep = ''
    children = root_element.children
    first_child = children.shift
    if ( first_child )
      first_child[:link].extend(Sugar::IO::CondensedIupac::LinkageWriter)
      string_rep += sequence_from_residue(first_child[:residue]) + write_linkage(first_child[:link])
    end
    children.reverse.each { |branch|
      branch[:link].extend(Sugar::IO::CondensedIupac::LinkageWriter)
      string_rep += wrap_branch(sequence_from_residue(branch[:residue]) + write_linkage(branch[:link])) 
    }
    string_rep += write_residue(root_element)
    return string_rep	
	end
	
	def write_linkage(linkage)
	  return "(#{linkage.to_sequence})"
  end
	
	def write_residue(root_element)
	  return self.target_namespace ? root_element.alternate_name(self.target_namespace) : root_element.name()
  end
  
  def wrap_branch(branch_sequence)
    return "[#{branch_sequence}]"
  end
  
end

module Sugar::IO::CondensedIupac::LinkageWriter
  def to_sequence
    red_residue = self.reducing_end_substituted_residue
    opp_residue = self.get_paired_residue(red_residue)
    red_position = get_position_for(red_residue)
    opp_position = get_position_for(opp_residue)
    first_pos_string = red_position > 0 ? red_position : 'u'
    second_pos_string = opp_position > 0 ? opp_position : 'u'
    
		return "#{red_residue.anomer}#{first_pos_string}-#{second_pos_string}"
	end
end