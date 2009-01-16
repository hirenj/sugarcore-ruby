require 'Monosaccharide'
require 'Linkage'

module Sugar::IO::CondensedIupac::LinkageBuilder

  attr :anomer

  def initialize(*args)
    super
    class << self 
      alias_method :base_set_first_residue, :set_first_residue unless method_defined?(:base_set_first_residue)
      alias_method :set_first_residue, :set_anomer_on_first_residue      
    end
  end
  
  def set_anomer_on_first_residue(residue, position=@first_position)
    base_set_first_residue(residue,position)
    residue.anomer = @anomer
  end

  def read_linkage(linkage_string)
  	if linkage_string =~ /([abu])([\d\?u])-([\d\?u])/
  		result = {}
  		@anomer = $1
  		if @first_position =~ /[\?u]/
  		  @first_position = -1
  	  end
  		if @second_position =~ /[\?u]/
  		  @second_position = -1
  	  end

  		@first_position = $2.to_i
  		@second_position = $3.to_i
  		return result
  	else
  		raise MonosaccharideException.new("Linkage #{linkage_string} is not a valid linkage")
  	end    
  end
end

# Condensed IUPAC-based builder
module Sugar::IO::CondensedIupac::Builder

  class IupacLinkage < Linkage
    include Sugar::IO::CondensedIupac::LinkageBuilder
  end

  # This is a bit tricky!
  # Append features is called when you call an include
  # on this module. We could almost hard code the classes created 
  # by the factory into the instance methods of monosaccharide_factory
  # and linkage_factory, but we can save on some code by having them call
  # these two other instance methods: residueClass and linkageClass.
  # These methods return the classes which need to be instantiated
  # Also - we can't just directly call the class methods ResidueClass and 
  # LinkageClass because objects that have their building functionality 
  # added in by an extend() will not have the class methods.
  
  # However - for any other module which is further modifying the 
  # base linkage and residue classes, we want a method to basically 
  # subclass the classes on the classes we specify here. So, in
  # the append_features method, we add some class methods.
  
  def self.append_features(base)
    super(base)
    class << base
      def ResidueClass
        NamespacedMonosaccharide
      end
      def LinkageClass
        Sugar::IO::CondensedIupac::Builder::IupacLinkage
      end
    end
  end
  
  attr_accessor :input_namespace
  
  def residueClass
    NamespacedMonosaccharide
  end
  
  def linkageClass
    Sugar::IO::CondensedIupac::Builder::IupacLinkage
  end
  
  def monosaccharide_factory(prototype)
    prototype = (input_namespace == nil) ? prototype : input_namespace.to_s + ':' + prototype
    return Monosaccharide.Factory(residueClass, prototype)
  end
  
  def linkage_factory(prototype)
    return Linkage.Factory(linkageClass, prototype)
  end
  
	def parse_sequence(input_string)
		units = input_string.reverse.split(/([\]\[])/)
		units = units.collect { |unit| unit.reverse.split(/\)/).reverse }.flatten.compact
		root = monosaccharide_factory( units.shift )
		create_bold_tree(root,units)
		return root
	end
	
	def create_bold_tree(root_mono,unit_array)
		while unit_array.length > 0 do
			unit = unit_array.shift
			if ( unit == ']' )
				debug "Branching on #{root_mono.name}"
				child_info = create_bold_branch(unit_array)
				root_mono.add_child(child_info.shift,linkage_factory( child_info.shift))
			elsif ( unit == '[' )
				debug "Branch closed"
				return
			else
				child_info = unit.split(/\(/)
				root_mono = root_mono.add_child(monosaccharide_factory(child_info.shift),linkage_factory(child_info.shift))
			end
		end
	end
	
	def create_bold_branch(unit_array)
		unit = unit_array.shift
		child_info = unit.split(/\(/)
		mono = monosaccharide_factory(child_info.shift)
		linkage = child_info.shift
		create_bold_tree(mono,unit_array)
		return [mono,linkage]
	end
	
end

