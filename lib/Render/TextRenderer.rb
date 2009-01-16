require 'DebugLog'
require 'Render/AbstractRenderer'

class TextRenderer
  include AbstractRenderer
  include DebugLog
  
  def initialise_prototypes()
  end

  def render(sugar)
    info("Switching rendering scheme to #{scheme.to_s}")
    case scheme
      when :ic
        info("Rendering as Iupac condensed")
        sugar.extend(Sugar::IO::CondensedIupac::Writer)
        sugar.target_namespace = NamespacedMonosaccharide::NAMESPACES[:ic]
      when :ecdb
        info("Rendering as ECDB")
        sugar.extend(Sugar::IO::GlycoCT::Writer)
      when :glyde
        info("Rendering as Glyde-like")
        sugar.extend(Sugar::IO::GlycoCT::Writer)
        sugar.target_namespace = :glyde
    end
    return sugar.sequence
  end

  def initialize()
  end
  
end
