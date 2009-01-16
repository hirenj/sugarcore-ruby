require 'DebugLog'
require 'SugarException'

module DefaultLinkageReader
  def read_linkage(linkage_string)
    @second_position = linkage_string[:from].to_i
    @first_position = linkage_string[:to].to_i
  end
end

=begin rdoc
  Models a linkage between residues
=end
class Linkage
	include DebugLog
	include DefaultLinkageReader
	
	
	attr_reader :first_position, :second_position
	attr_reader :first_residue, :second_residue

  def Linkage.Factory( proto_class , linkage_string )
    linkage  = proto_class.new()
    if (linkage_string != nil)
      linkage.read_linkage(linkage_string)
    end
    linkage
  end
  
	public
	
	def deep_clone
	  new_link = self.dup
	  new_link.initialize_from_copy(self)
	  new_link
  end
	
	def set_first_residue( residue, position=@first_position )
		residue.consume_attachment_position(position,self)

		if @first_residue && @first_residue != residue
		  @first_residue.release_attachment_position(@first_position)
		end

		@first_residue = residue
		@first_position = position
	end

	def set_second_residue( residue, position=@second_position )
		residue.consume_attachment_position(position,self)

    if @second_residue && @second_residue != residue
		  @second_residue.release_attachment_position(@second_position)
		end
		@second_residue = residue
		@second_position = position
	end

	def get_position_for( residue )
		if residue == @first_residue
			return @first_position
		elsif residue == @second_residue
			return @second_position
		else
			raise LinkageException.new("Residue #{residue} not in linkage")
		end
	
	end
	
	def get_paired_residue( residue )
		if residue == @first_residue
			return @second_residue
		elsif residue == @second_residue
			return @first_residue
		else
			raise LinkageException.new("Residue #{residue} not in linkage")
		end
	end
	
	def is_unknown?
	  return ( (@first_position == 0) || (@second_position == 0) )
  end
	
	def reducing_end_substituted_residue # i.e. the child residue
	  if (@first_residue.linkage_at_position() == self)
	    return @first_residue
    end
	  if (@second_residue.linkage_at_position() == self)
	    return @second_residue
    end
    raise LinkageException.new("Neither residue has linkage as parent linkage")
  end

	def non_reducing_end_substituted_residue # i.e. the parent residue
	  if (@first_residue.linkage_at_position() == self)
	    return @second_residue
    end
	  if (@second_residue.linkage_at_position() == self)
	    return @first_residue
    end
  end

	
	alias :child_residue :reducing_end_substituted_residue
	alias :parent_residue :non_reducing_end_substituted_residue
	
	
	
	def finish
		@first_residue = nil
		@second_residue = nil
	end

	def initialize_from_copy(original)
	  @first_position = original.first_position
	  @second_position = original.second_position
	  @first_residue = nil
	  @second_residue = nil
  end
	
	private
	
end
