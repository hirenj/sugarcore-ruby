module Sugar::IO::GlycoCT::Builder

  def self.append_features(base)
    super(base)
    class << base
      def ResidueClass
        NamespacedMonosaccharide
      end
      def LinkageClass
        Linkage
      end      
    end
  end
  
  def residueClass
    NamespacedMonosaccharide
  end
  
  def linkageClass
    Linkage    
  end

  attr_accessor :input_namespace

  def monosaccharide_factory(prototype=nil)
    prototype = (input_namespace == nil) ? prototype : input_namespace.to_s + ':' + prototype
    return Monosaccharide.Factory(residueClass,prototype)
  end
  
  def linkage_factory(prototype=nil)
    return Linkage.Factory(linkageClass, prototype)
  end


  class Residue
    attr_accessor :res_id, :name, :res_type, :anomer, :substituents
    def self.factory(string)
      res = new()
      res.res_id, res.res_type, res.anomer, res.name = [string.scan(/(\d+)([bsn]):(?:([abux])-)?(.*)/)].flatten
      if ( ! res.name )
        res.name = res.anomer
      end
      if ( res.anomer == 'x')
        res.anomer = 'u'
      end
      if res.res_type == nil
        raise MonosaccharideException.new("Could not parse residue #{string}")
      end
      res.res_type = res.res_type.to_sym
      res.substituents = Hash.new()
      res
    end
  end

  class ParseLinkage
    attr_accessor :link_id, :from, :to, :from_position, :to_position
    def self.factory(string)
      string.gsub!(/\d(\|\d)+/,'u')
      link = new()
      link.link_id, link.from, link.from_position, link.to_position, link.to = [ string.scan(/(\d+):(\d+)[a-z]?\(([\du\-]+)[\-\+]([\du]+)\)(\d+)[a-z]?/)].flatten
      if link.from_position == '-1'
        link.from_position = 'u'
      end
      if link.link_id == nil
        raise LinkageException.new("Could not parse linkage string #{string}")
      end
      link
    end
  end


  def parse_sequence(sequence)
    glycoct_residues = Hash.new()
    glycoct_linkages = Hash.new()
    sequence.gsub!(/\r/,'')
    sequence.gsub!(/[\\\/]*/,'')
    residues, linkages = sequence.split(/(?:LIN|RES)[\s\n]+/).reject{|s| s.empty? }.collect { |block| block.split(/;?[\n\s]+/) }
    (residues || []).reject { |r| r.match(/^[\n\s]+$/) }.collect { |res_string| Sugar::IO::GlycoCT::Builder::Residue.factory(res_string.downcase) }.each { |res| glycoct_residues[res.res_id] = res }
    (linkages || []).reject { |l| l.match(/^[\n\s]+$/) }.collect { |link_string| Sugar::IO::GlycoCT::Builder::ParseLinkage.factory(link_string.downcase) }.each { |link| glycoct_linkages[link.link_id] = link }

    residues = glycoct_residues
    linkages = glycoct_linkages

    collapse_substituents(linkages,residues)

    root = nil
    
    if linkages.values.select { |lin| lin.from != nil }.length == 0
      root = monosaccharide_factory(residues.values.first.name)
    end

    min_id = nil
    
    linkages.keys.select { |id| linkages[id].from != nil }.sort_by { |id| residues[linkages[id].from].res_id }.each { |id|
      link = linkages[id]
      residue = residues[link.from]
      unless residue.is_a?(Monosaccharide)
        residue = monosaccharide_factory(residues[link.from].name)
        residue.anomer = residues[link.from].anomer
      end
      residues[link.from] = residue

      to_residue = residues[link.to]
      unless to_residue.is_a?(Monosaccharide)
        to_residue = monosaccharide_factory(residues[link.to].name)
        to_residue.anomer = residues[link.to].anomer
      end
      residues[link.to] = to_residue

      if (min_id == nil || id.to_i < min_id)
        root = residue
        min_id = id.to_i
      end
      linkage = linkage_factory({:from => link.from_position, :to => link.to_position})
      residue.add_child(to_residue,linkage)
    }
    return root
  end
  
  def collapse_substituents(linkages,residues)
    linkages.each { |link_id,link|
      if (residues[link.to].res_type == :s || residues[link.to].res_type == :n )
        residues[link.from].substituents[link.from_position] = residues[link.to].name
#        residues[link.from].name = "#{residues[link.from].name}|#{link.from_position}#{residues[link.to].name}"
        link.from = nil
        link.to = nil
      end    
    }
    residues.each { |key,res|
      res.substituents.keys.sort.each { |pos|
        res.name = "#{res.name}|#{pos}#{res.substituents[pos]}"
      }
    }
  end
end