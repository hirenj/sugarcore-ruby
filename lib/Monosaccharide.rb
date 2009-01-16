require 'DebugLog'
require 'Linkage'
require 'SugarException'

require 'rexml/document'
include REXML

# Base Monosaccharide class for representing Monosaccharide units
# Author:: hirenj
class Monosaccharide
    include DebugLog

  @@MONO_DATA = nil
  @@MONO_DATA_FILENAME = nil
  @@FACTORY_CACHES = Hash.new()
  
  MONO_DICTIONARY_NAMESPACE = 'http://penguins.mooh.org/research/glycan-dict-0.2'
  
  # Class methods
  
  class << self

  public

    # Load the definitions for a particular Monosaccharide dataset
    # This method must be called before any monosaccharides can be
    # instantiated

    def Load_Definitions(datafile="data/dictionary.xml")
      path = File.dirname(datafile)
      Monosaccharide.Do_Load_Definitions(datafile)
#      ICNamespacedMonosaccharide.Do_Load_Definitions("#{path}/ic-dictionary.xml")
#      DKFZNamespacedMonosaccharide.Do_Load_Definitions("#{path}/dkfz-dictionary.xml")
    end

    def Monosaccharide.Flush_Factory
      @@FACTORY_CACHES.each { |key,class_cache|
        class_cache.values.each { |res|
          res.finish
        }
        class_cache.clear
      }
    end

    def Monosaccharide.Show_Factory_Status
      @@FACTORY_CACHES.keys.each { |clazz| 
        @@FACTORY_CACHES[clazz].keys.each { |key|
          p @@FACTORY_CACHES[classname][key].object_id
        }
      }
    end

    # Instantiate a new Monosaccharide using a particular subclass, and having
    # the identifier as specified
    #
    # For example:
    #   Monosaccharide.Factory( NamespacedMonosaccharide, 'Gal' )
    # or
    #   Monosaccharide.Factory( NamespacedMonosaccharide, 'D-Fruf' )
    def Monosaccharide.Factory( classname, identifier )
      
      if @@FACTORY_CACHES[classname] == nil
        @@FACTORY_CACHES[classname] = Hash.new()
      end
      if @@FACTORY_CACHES[classname][identifier.to_sym] == nil
        new_mono = classname.new_mono(identifier)        
    	  @@FACTORY_CACHES[classname][identifier.to_sym] = new_mono
    	  new_mono.alternate_namespaces_as_symbols.each { |ns|
      	  @@FACTORY_CACHES[classname][(ns.to_s+':'+new_mono.name(ns)).to_sym] = new_mono    	    
    	  }
    	end
    	new_mono = @@FACTORY_CACHES[classname][identifier.to_sym].shallow_clone
    	new_mono
    end

    # Retrieve the monosaccharide data for this particular class
    def mono_data
      clazz = self
      data = nil
      while ( clazz != nil && data == nil )
        data = @@MONO_DATA[clazz]
        clazz = clazz.superclass
      end
      return data
    end

    # The file that contains the monosaccharide data for this class
    def mono_data_filename
      clazz = self
      data = nil
      while ( clazz != nil && data == nil ) 
        data = @@MONO_DATA_FILENAME[clazz]
        clazz = clazz.superclass
      end
      return data
    end

  protected

    # A wrapper around the new method so that only subclasses can actually
    # directly instantiate a monosaccharide.
    def new_mono(*args)
      new(*args)
    end
  
    # Actually load up the definitions from the data files. The main Load_Definitions 
    # class is just used to set the definitions for the implementing classes
    def Do_Load_Definitions(datafile="data/dictionary.xml")
      if @@MONO_DATA == nil
        @@MONO_DATA = Hash.new()
        @@MONO_DATA_FILENAME = Hash.new()
      end
      @@MONO_DATA_FILENAME[self] = datafile
    	@@MONO_DATA[self] = XPath.first(Document.new( File.new(datafile) ), "/dict:glycanDict", { 'dict' => MONO_DICTIONARY_NAMESPACE })
    	unless @@MONO_DATA[self] != nil
    	  raise MonosaccharideException.new('Could not load up dictionary file - expecting version '+MONO_DICTIONARY_NAMESPACE)
  	  end
    end

  end

  # Anomer configuration for this residue
  attr_accessor :anomer
  
  # Alternate name for this residue
  #--
  # FIXME We should put this into the NamespacedMonosaccahride subclass, as it's not
  # common to all residues
  #++
  attr_reader :alternate_name
  
  # An array of child nodes attached to this residue
  attr :children

  # The name/identifier for this residue
  attr_reader :name

  # The namespace that the name of this identifier is found within
  attr		:namespace

  # Set the integer position that is consumed by a linkage that is defined
  # as a linkage to the parent residue of this residue
  attr_writer :parent_position
  
  # Get access to the raw XML data node for this particular residue
  attr_reader :raw_data_node
  
  # Ring positions that are consumed by linkages on children
  #--
  # FIXME We should be deriving this from the children array.
  #++
  attr :ring_positions

  private :ring_positions
    
  def initialize(name)    
    debug "Doing the initialisation for #{name}."
    @name = name.strip
    @children = []
    @ring_positions = {}
    @alternate_name = {}
    initialize_from_data()
  end
    
  # This should really be the == override, but I was so brilliant to use
  # == all over the place when I was really testing for object equality which
  # should be equal?. So now I've got to use yet another method for equality.
  
  def equals?(test_residue)
    return self.name(:id) == test_residue.name(:id) && self.anomer == test_residue.anomer
  end
  
  # Perform a deep clone on this residue, copying all the children and any 
  # state for this object
  def deep_clone
    cloned = self.clone
    cloned.initialize_from_copy(self)
    cloned
  end
  
  # Perform a shallow clone of this residue
  def shallow_clone
    cloned = self.clone
    cloned.remove_relations
    return cloned
  end
    
  # New method which is hidden to avoid direct instantiation of the 
  # monosaccharide class
  private_class_method :new
    
  public
  
  # Add a paired residue to this residue, using the specified
  # linkage. The residue can be either specified as a  
  # Monosaccharide object, and the linkage can be 
  # specified as a Linkage object
  #   linkage = Linkage.Factory( LinkageClass, '1-2' )
  #   p mono.children.length
  #   # 0
  #   mono.add_child(linkage, Monosaccharide.Factory(MonosaccharideClass, 'Foo'))
  #   p mono.children.length
  #   # 1
  #--
  # FIXME We should not be assuming the first and second positions, and should
  # be dynamically attaching this residue to the open position on the linkage.
  #++
  def add_child(mono,linkage)
    if (! can_accept?(linkage))
      raise MonosaccharideException.new("Cannot attach linkage to this monosaccharide, attachment point already consumed - want #{linkage.second_position}")
    end

    @children.push( :link => linkage, :residue => mono )
    
    linkage.set_first_residue(mono)
    linkage.set_second_residue(self)
    mono.parent_position = linkage.get_position_for(mono)
    return mono
  end

  def is_parent_of?(mono)
    @children.collect { |r| r[:residue] }.include?(mono)
  end
  
  def remove_child(mono)
    if ! self.is_parent_of?(mono)
      raise MonosaccharideException.new("This residue is not the parent of the given residue")
    end
    release_attachment_position(mono.paired_residue_position)
    @children.delete_if { |kid| kid[:residue] == mono }
  end

  def to_sugar
    sug = Sugar.new()
    sug.root = self
    sug
  end

  # Can this residue accept the given linkage. Will return true if the attachment
  # position on this residue is not already consumed
  #   linkage = Linkage.Factory( LinkageClass, '1-2' )
  #   linkage.set_first_residue(somemono)
  #   mono.add_child(somemono, linkage)
  #
  #   a_linkage = Linkage.Factory( LinkageClass, '1-2' )
  #   a_linkage.set_first_residue(someothermono)
  #   p mono.can_accept?(a_linkage) # false
  #
  #   b_linkage = Linkage.Factory( LinkageClass, '1-3' )
  #   b_linkage.set_first_residue(someothermono)
  #   p mono.can_accept?(b_linkage) # true
  #--
  # FIXME We should not be assuming the first and second positions, and should
  # be dynamically attaching this residue to the open position on the linkage.
  #++  
  def can_accept?(linkage)
    if (linkage.second_position == 0)
      return true
    end
    ! self.attachment_position_consumed?(linkage.second_position)
  end
  
  # Retrieve an alternate name for this residue, as found in another 
  # namespace
  #   p mono.name # Gal
  #   p mono.alternate_name(mono.alternate_namespaces[1]) # Gal-alternate-1
	def alternate_name(namespace)
		if ( ! @alternate_name[namespace] )
			raise MonosaccharideException.new("No name defined in namespace #{namespace} for #{name}")
		end
		return @alternate_name[namespace]
	end

  def name(namespace=nil)
    if (namespace != nil)
      return alternate_name(namespace)
    end
    return @name
  end

  # Get the set of alternate namespaces defined for this residue
  #   p mono.alternate_namespaces # [ 'http://glycosciences.de', 'http://iupac' ]
  def alternate_namespaces
      return @alternate_name.keys()
  end

  def alternate_namespaces_as_symbols
    return @alternate_name.keys().collect { |ns| NamespacedMonosaccharide.Lookup_Namespace_Symbol(ns) }
  end

  # The residues which are attached to this residue
  # Returns an array of hash slices with linkage and child
  #   mono.children   # [ {:link => Linkage , :residue => Residue }, {:link => Linkage, :residue => Residue }] 
  #--
  # FIXME - We need to enshrine a sorting algorithm into the branches
  #++
  def children
    newarray = @children.sort_by { |a|
  	  a[:link].get_position_for(self)
    }
    return newarray
  end

  def siblings
    parent.children.collect { |child| child[:residue] } - [ self ]
  end


  # Test for seeing if a residue is a parent of this residue
  #   mono.children[0][:residue].child_of?(mono)             # true
  #   mono.children[0][:residue].children[0][:residue].child_of?(mono) # true
  #   mono.children[0][:residue].child_of?(mono.children[1][:residue]) # false
  def child_of?(residue)
    residue.residue_composition.include?(self)
  end

  # Consume an attachment position on the ring
  #--
  # FIXME - We shouldn't be keeping track of this. Maybe maintain the attachment
  # positions from the children arrays?
  #++
	def consume_attachment_position(attachment_position, linkage)
		@ring_positions[attachment_position] = linkage
		# FIXME - NEED TO HAVE LIST OF POSITIONS TO CONSUME
	end

  # Release a residue from the specified attachment position on the ring
  # Will not do anything if the attachment position is not consumed 
	def release_attachment_position(attachment_position)
		@ring_positions.delete(attachment_position)
		# FIXME - NEED TO HAVE LIST OF POSITIONS TO CONSUME
	end

  # Test to see if the attachment position specified has been consumed by
  # another residue
  #   sugar = Sugar.new()
  #   sugar.sequence = Gal(b1-3)GlcNAc
  #   root.attachment_position_consumed?(3)    # true
  #   root.attachment_position_consumed?(2)    # false
  def attachment_position_consumed?(attachment_position)
    return linkage_at_position(attachment_position) != nil
  end
  
  # The residue at the specified attachment position
  #   sugar = Sugar.new()
  #   sugar.sequence = Gal(b1-3)GlcNAc
  #   root.residue_at_position(3)       # Gal
  #   gal.residue_at_position(1)     # GlcNAc
  #   glcnac.residue_at_position(3)     # nil  
	def residue_at_position(attachment_position)
		if ( attachment_position_consumed?(attachment_position) )
			return linkage_at_position(attachment_position).get_paired_residue(self)
		else
			return nil
		end
	end

  # The linkage object associated with any residue attached at the given 
  # attachment position using the parent position as default
	def linkage_at_position(attachment_position=@parent_position)
		return @ring_positions[attachment_position]
	end

  # Consumed positions on the ring
  #   sugar.sequence                # Gal(b1-3)[Gal(b1-4)]GalNAc
  #   root.consumed_positions       # [3,4]
  def consumed_positions
    return @ring_positions.keys
  end

  # The position this residue is linked to on to at a given position ( uses the parent position by default )
  #   sugar.sequence                      # Gal(b1-3)GlcNAc
  #   gal.paired_residue_position()       # 3
  #   root.paired_residue_position(3)     # 1
  def paired_residue_position(attachment_position=@parent_position)
    if (linkage_at_position(attachment_position) == nil)
      return nil
    end
    linkage_at_position(attachment_position).get_position_for(residue_at_position(attachment_position))
  end

  # The residue composition of this monosaccharide and all of its attached
  # residues
  #   sugar.sequence                  # Gal(b1-3)[Gal(b1-4)]GlcNAc(b1-4)GlcNAc
  #   root.residue_copmosition        # [Gal, Gal, GlcNAc, GlcNAc]
  def residue_composition
  	descendants = [self]
  	kids = children.collect { |child| child[:residue] }
  	kids.each { |child|
  		descendants += child.residue_composition
  	}
  	return descendants
  end

  # The Parent residue of this residue - an alias for retrieving the residue found 
  # attached at the parent position.
	def parent
		self.residue_at_position(@parent_position)
	end

  # String representation of this residue
  def to_s
      stringified = "#{@name}["
      @children.each { |kid| stringified += "#{kid[:link]} -> #{kid[:residue]}" }
      stringified += "]\n" 
  end

  # Clean up circular references that this residue may have
  def finish
    @children.each { |kid| 
      kid[:link].finish()
      kid[:link] = nil
      kid[:residue].finish()
      kid[:residue] = nil
    }

    @ring_positions.each { |pos,node| 
      node.finish()
    }

    remove_relations
    
  end
    
  protected

	def initialize_from_copy(original)
    remove_relations
	  original.children.each { |child|
	    add_child(child[:residue].deep_clone, child[:link].deep_clone)
	  }
  end

  def remove_relations
    @ring_positions = {}
    @children = []
  end

  private

  def initialize_from_data
  	raise MonosaccharideException.new("Trying to initialize base Monosaccharide")
  end

end

# Residue entity that implements a namespaced monosaccharide
class NamespacedMonosaccharide < Monosaccharide

  NAMESPACES = Hash.new()

	NAMESPACES[:ic] =  "http://www.iupac.org/condensed"
	NAMESPACES[:dkfz] = "http://glycosciences.de"
	NAMESPACES[:ecdb] = "http://ns.eurocarbdb.org/glycoct"
	NAMESPACES[:glyde] = "http://ns.eurocarbdb.org/glyde"
	NAMESPACES[:stephan] = "http://www.dkfz.de/stephan"
	
	NAMESPACES[:id] = NAMESPACES[:ecdb]
	
	@@DEFAULT_NAMESPACE = NAMESPACES[:ecdb]

  # The Default Namespace that new residues will be created in, and in which
  # their names will be validated
	def NamespacedMonosaccharide.Default_Namespace
		@@DEFAULT_NAMESPACE
	end

  # Set the default namespace to initialise residues from
  # and validate their names in
	def NamespacedMonosaccharide.Default_Namespace=(ns)
    if ns.is_a? Symbol
      ns = NAMESPACES[ns]
    end
		@@DEFAULT_NAMESPACE = ns
	end

  # List of supported namespaces
  def NamespacedMonosaccharide.Supported_Namespaces
    return NAMESPACES.values
  end

  def NamespacedMonosaccharide.Lookup_Namespace_Symbol(ns)
    return NAMESPACES.index(ns)
  end

  def NamespacedMonosaccharide.Supported_Residues(ns=nil)
    ns = ns || self.Default_Namespace

	  namespaces = Hash.new()

	  XPath.match(self.mono_data, '@*').select {|att| att.prefix = 'xmlns' }.each { |ns_dec|
	    namespaces[ns_dec.value] = ns_dec.name
	  }

    return XPath.match( self.mono_data, "./dict:unit/dict:name[@ns='#{namespaces[ns]}']/@value", {'dict' => MONO_DICTIONARY_NAMESPACE}).collect { |att| att.value }
  end

  def name(namespace=nil)
    if namespace.is_a? Symbol
      namespace = NAMESPACES[namespace]
    end
    super(namespace)
  end

  protected
  
	def initialize_from_data
	  ns = self.class.Default_Namespace
	  @name = self.name.sub(/^(\w+):/) { |_match| ns = NAMESPACES[$1.to_sym]; '' }
    debug "Initialising #{name} in namespace #{ns}."
	  data_source = self.class.mono_data
	  
	  namespaces = Hash.new()
	  
	  XPath.match(data_source, '@*').select {|att| att.prefix = 'xmlns' }.each { |ns_dec|
	    namespaces[ns_dec.value] = ns_dec.name
	  }
  	mono_data_node = XPath.first(	data_source, 
									"./dict:unit[dict:name[@ns='#{namespaces[ns]}' and @value='#{@name}']]",
									{ 'dict' => MONO_DICTIONARY_NAMESPACE }
  									 )

  									 
  #		string(namespace::*[name() =substring-before(@type, ':')]) 
			
  	if ( mono_data_node == nil )
  		raise MonosaccharideException.new("Residue #{self.name} not found in default namespace #{ns} #{namespaces[ns]} from #{self.class.mono_data_filename ? self.class.mono_data_filename : @@MONO_DATA_FILENAME}")
  	end

  	#@alternate_name[ns] = self.name()


  	XPath.each(mono_data_node, "./name") { |altname|
  		namespace = altname.attribute('ns').value()
  		alternate_name = altname.attribute('value').value()
  		if ( @alternate_name[altname.namespace(namespace)] == nil )
  		  @alternate_name[altname.namespace(namespace)] = alternate_name
    		debug "Adding #{alternate_name} in namespace #{namespace} for #{name}."
		  end
  	}

    @name = @alternate_name[ns]

    @raw_data_node = mono_data_node

      # FIXME - ADD ATTACHMENT POSITION INFORMATION	
	end
		
end

class ICNamespacedMonosaccharide < NamespacedMonosaccharide
  def self.Default_Namespace
    NAMESPACES[:ic]
  end
end

class DKFZNamespacedMonosaccharide < NamespacedMonosaccharide
  def self.Default_Namespace
    NAMESPACES[:dkfz]
  end
end

class ECDBNamespacedMonosaccharide < NamespacedMonosaccharide
  def self.Default_Namespace
    NAMESPACES[:ecdb]
  end
end

class GlydeNamespacedMonosaccharide < NamespacedMonosaccharide
  def self.Default_Namespace
    NAMESPACES[:glyde]
  end
end
