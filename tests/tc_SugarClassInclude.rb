require 'test/unit'
require 'Sugar'

require 'Sugar/IO/CondensedIupac'


class Sugar
  include Sugar::IO::CondensedIupac::Builder
  include  Sugar::IO::CondensedIupac::Writer
end

NamespacedMonosaccharide.Default_Namespace = :ic

Monosaccharide.Load_Definitions('data/dictionary.xml')

class TC_SugarClassInclude < Test::Unit::TestCase

  IUPAC_CORE_N_LINKED_FUC = "Man(a1-3)[Man(a1-6)]Man(b1-4)GlcNAc(b1-4)[Fuc(a1-6)]GlcNAc"
  IUPAC_DISACCHARIDE = "Man(a1-3)GalNAc"
  INVALID_SEQUENCE = "aNyTHING124!!?$$"
  IUPAC_SINGLE_RESIDUE = "Man"
  LARGE_STRUCTURE = "Man(a1-3)[Man(a1-6)]Man(b1-4)GlcNAc(b1-4)[Fuc(a1-6)]GlcNAc"
  SMALL_STRUCTURE = "GlcNAc(b1-4)GlcNAc"
  SMALL_STRUCTURE_2 = "GlcNAc(b1-3)GlcNAc"
  SMALL_STRUCTURE_3 = "GalNAc(b1-3)GalNAc"


	DebugLog.log_level(5)

  def test_NewMethod
    sugar = Sugar.new()
    assert_nothing_raised {
      sugar.sequence = LARGE_STRUCTURE
    }
    assert_equal(LARGE_STRUCTURE, sugar.sequence)
  end

end