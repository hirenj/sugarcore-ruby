require 'Render/TextRenderer'

module MarkedUpWriting
  include Sugar::IO::CondensedIupac::Writer
  
  def write_linkage(linkage)
    line = Element.new('span')
    line.text = linkage.to_sequence
    if linkage.labels.length > 0
      line.add_attribute('class', linkage.labels.join(" "))
    end
    linkage.callbacks.each { |callback|
      callback.call(line)
    }
    return line.to_s
  end
  
  def write_residue(residue)
    icon = Element.new('span')
    icon.text = self.target_namespace ? residue.alternate_name(self.target_namespace) : residue.name()
    if residue.labels.length > 0 
      icon.add_attribute('class', residue.labels.join(" "))
    end
    
    residue.callbacks.each { |callback|
      callback.call(icon)
    }
    error(icon.to_s)
    return icon.to_s
  end
  
end


class HtmlTextRenderer < TextRenderer
  def render(sugar)
    case scheme
      when :ic
        error("Rendering as iupac condensed")
        sugar.extend(MarkedUpWriting)
        sugar.target_namespace = NamespacedMonosaccharide::NAMESPACES[:ic]
      when :ecdb
        sugar.extend(Sugar::IO::GlycoCT::Writer)
    end
    return sugar.sequence
  end
end