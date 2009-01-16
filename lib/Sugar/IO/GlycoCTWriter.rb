module Sugar::IO::GlycoCT::Writer

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
    string_rep = "RES\n"
    residues = Hash.new()
    links = Hash.new()
    self.residue_composition(root_element).each { |residue|
      names = residue.name(target_namespace).scan(/(\d)?([\w\-\d\:]+)/)
      residues[residue] = "b:#{residue.anomer || 'u'}-#{names.shift[1]};\n"
      names.each { |pos,substituent|
        residues[substituent] = "s:#{substituent};\n"
        if ( ! links[residue] )
          links[residue] = Hash.new()            
        end
        links[residue][pos] = substituent
      }
    }
    counter = 1
    residues.keys.sort_by { |el| el.is_a?(String) ? '2'+el : el == root_element ? '00' : '1'+residues[el]+get_attachment_point_path_to_root(el).join(',') }.each { |res|
      string_rep += "#{counter}#{residues[res]}"
      residues[res] = counter
      counter = counter + 1
    }
    
    string_rep += "\\\\\\\n" if self.target_namespace == NamespacedMonosaccharide::NAMESPACES[:glyde]
    string_rep += "LIN\n"
    counter = 1
    self.breadth_first_traversal(root_element) { |res| 
      res.children.collect { |kid| kid[:link] }.each { |link|
        red_residue = link.reducing_end_substituted_residue
        opp_residue = link.get_paired_residue(red_residue)
        if self.target_namespace == NamespacedMonosaccharide::NAMESPACES[:glyde]
          string_rep += "#{counter}:#{residues[opp_residue]}o(#{write_linkage(link.get_position_for(opp_residue))}+#{write_linkage(link.get_position_for(red_residue))})#{residues[red_residue]}d;\n"
        else
          string_rep += "#{counter}:#{residues[opp_residue]}(#{write_linkage(link.get_position_for(opp_residue))}-#{write_linkage(link.get_position_for(red_residue))})#{residues[red_residue]};\n"
        end
        counter = counter + 1
      }
    }
    links.keys.sort_by { |res| residues[res] }.each { |res|
      links[res].each { |posn, sub|
        if self.target_namespace == NamespacedMonosaccharide::NAMESPACES[:glyde]
          string_rep += "#{counter}:#{residues[res]}d(#{posn}+1)#{residues[sub]}n;\n"
        else
          string_rep += "#{counter}:#{residues[res]}o(#{posn}-1)#{residues[sub]};\n"
        end
        counter = counter + 1
      }
    }
    string_rep += "\\\\\\\\\\\n" if self.target_namespace == NamespacedMonosaccharide::NAMESPACES[:glyde]
    string_rep
  end
  
  def write_linkage(position)
    if (position > 0)
      position.to_s
    else
      'u'
    end
  end
  
  private :write_linkage
  
end