require 'test/unit'
require 'Sugar'
require 'Sugar/IO/CondensedIupac'

require 'Render/Renderable'
require 'Render/CondensedLayout'
require 'Render/SvgRenderer'

NamespacedMonosaccharide.Default_Namespace = :ic

class SvgSugar < Sugar
  include Sugar::IO::CondensedIupac::Builder
  include  Sugar::IO::CondensedIupac::Writer
  include Renderable::Sugar

  class ResidueClass < self.ResidueClass
    include Renderable::Residue
  end

  class LinkageClass < self.LinkageClass
    include Renderable::Link
  end

  def residueClass
    ResidueClass
  end
  
  def linkageClass
    LinkageClass
  end
  
end

DebugLog.log_level(5)

class TC_SugarLayout < Test::Unit::TestCase

  # Test for making sure that we can load the dictionary
  # file for the Monosaccharide definitions and also 
  # instantiate a Simple sugar
	def setup

		assert_nothing_raised {
			Monosaccharide.Load_Definitions('data/dictionary.xml')
		}
	
		assert_nothing_raised {
			sugar = SvgSugar.new()
		}
 
	end

  def a_sugar
    sugar = SvgSugar.new()
    sugar.sequence = 'NeuAc(a2-3)Man(b1-6)[Man(b1-3)]Man(a1-3)Man(b1-6)[Man(b1-3)]Man(a1-3)Man(b1-6)[Man(b1-3)]Man(a1-3)GlcNAc(b1-4)GlcNAc'
    sugar
  end
  
  def test_layout
    sugar = a_sugar
    node_num = 0
    renderer = SvgRenderer.new()
    renderer.sugar = sugar
    renderer.initialise_prototypes()

    CondensedLayout.new().layout(sugar)
#    p sugar.box
#    sugar.depth_first_traversal { |res|
#      p sugar.sequence_from_residue(res)
#      p res.position      
#    }
    renderer.render(sugar)
  end
end