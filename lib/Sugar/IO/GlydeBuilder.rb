require 'rexml/document'
include REXML

module Sugar::IO::Glyde::Builder

  def self.append_features(base)
    super(base)
    class << base
      def ResidueClass
        GlydeNamespacedMonosaccharide
      end
      def LinkageClass
        Linkage
      end      
    end
  end
  
  def residueClass
    GlydeNamespacedMonosaccharide
  end
  
  def linkageClass
    Linkage    
  end

  def monosaccharide_factory(prototype)
    return Monosaccharide.Factory(residueClass,prototype)
  end
  
  def linkage_factory(prototype)
    return Linkage.Factory(linkageClass, prototype)
  end
  
    class Residue
      attr_accessor :res_id, :name, :res_type, :anomer, :substituents
      def self.factory(part)
        res = new()
        res.res_id = part.attribute('partid').value
        res.anomer, res.name = [part.attribute('ref').value.scan(/.*=(?:([abu])-)?(.*)/)].flatten
        
        res.res_type = :b
        
        if ( res.anomer == nil )
#          res.name = res.anomer
#          res.anomer = nil
          res.res_type = :s
        end
        
        res.substituents = Hash.new()
        res
      end
    end

    class ParseLinkage
      attr_accessor :link_id, :from, :to, :from_position, :to_position
      def self.factory(linkage_node)
        link = new()
        link.from = linkage_node.attribute('from').value
        link.to = linkage_node.attribute('to').value
        link.link_id = "#{link.from}-#{link.to}"
        link.from_position = XPath.first(linkage_node, 'link/@from').value.match(/\d/)[0]
        link.to_position = XPath.first(linkage_node, 'link/@to').value.match(/\d/)[0]
        link
      end
    end


    def parse_sequence(sequence)
      
      glycoct_residues = Hash.new()
      glycoct_linkages = Hash.new()


      glyde_document = Document.new sequence

      residues = XPath.match glyde_document, "/*/structure/part[@type='residue']"
      linkages = XPath.match glyde_document, '/*/structure/link'
      
      residues.collect { |res_node| Sugar::IO::Glyde::Builder::Residue.factory(res_node) }.each { |res| glycoct_residues[res.res_id] = res }
      linkages.collect { |link_node| Sugar::IO::Glyde::Builder::ParseLinkage.factory(link_node) }.each { |link| glycoct_linkages[link.link_id] = link }

      residues = glycoct_residues
      linkages = glycoct_linkages

      collapse_substituents(linkages,residues)

      root = nil

      if linkages.values.select { |lin| lin.from != nil }.length == 0
        residues.values.each { |res|
          if res.res_type == :b
            root = monosaccharide_factory(res.name)
          end
        }
      end

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

        linkage = linkage_factory({:to => link.from_position, :from => link.to_position})
        to_residue.add_child(residue,linkage)
      }
      
      residues.values.each { |res|
        if res.is_a?(Monosaccharide) && res.parent == nil
          root = res
        end
      }
      return root
    end

    def collapse_substituents(linkages,residues)
      linkages.each { |link_id,link|
        if (residues[link.from].res_type == :s)
          residues[link.to].substituents[link.to_position] = residues[link.from].name
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