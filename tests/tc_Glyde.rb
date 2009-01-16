require 'test/unit'
require "Sugar"
require 'Sugar/IO/CondensedIupac'
require 'Sugar/IO/Glyde'

class ReadingSugar < Sugar
  include Sugar::IO::Glyde::Builder
  include  Sugar::IO::CondensedIupac::Writer

  def residueClass
    GlydeNamespacedMonosaccharide
  end

end

NamespacedMonosaccharide.Default_Namespace = :ic

GlydeNamespacedMonosaccharide.logger = Logger.new(STDERR)
GlydeNamespacedMonosaccharide.log_level(100)
DebugLog.log_level(5)

class TC_Glyde < Test::Unit::TestCase
  SIMPLE_GLYDE = <<__GLYDE__
<GlydeCT xmlns:GlydeCT="http://glycomics.ccrc.uga.edu/GLYDE-CT_v2.12"> 

     <structure type="molecule" id="molecule_1" name="pentaglycoside"> 
        <part type="residue" partid="1" ref="&mDBget;=n-acetyl"/> 
        <part type="residue" partid="2" ref="&mDBget;=n-acetyl"/> 
        <part type="residue" partid="3" ref="&mDBget;=b-dglc-hex-1:5"/> 
        <part type="residue" partid="4" ref="&mDBget;=b-dglc-hex-1:5"/> 
        <part type="residue" partid="5" ref="&mDBget;=b-dman-hex-1:5"/> 
        <part type="residue" partid="6" ref="&mDBget;=a-dman-hex-1:5"/>
     <part type="residue" partid="7" ref="&mDBget;=a-dman-hex-1:5"/> 

     <link from="1" to="3"> 
        <link from="N1" to="C2" from_replaces="O2" bond_order="1"/> 
     </link> 
     <link from="2" to="4"> 
        <link from="N1" to="C2" from_replaces="O2" bond_order="1"/> 
     </link> 
     <link from="4" to="3"> 
        <link from="C1" to="O4" to_replaces="O1" bond_order="1"/> 
     </link> 
     <link from="5" to="4"> 
        <link from="C1" to="O4" to_replaces="O1" bond_order="1"/> 
     </link> 
     <link from="6" to="5"> 
        <link from="C1" to="O3" to_replaces="O1" bond_order="1"/> 
     </link> 
     <link from="7" to="5"> 
        <link from="C1" to="O6" to_replaces="O1" bond_order="1"/> 
     </link> 
  </structure>
</GlydeCT>
__GLYDE__

  SIMPLE_GLYDE_AS_IC = 'Man(a1-3)[Man(a1-6)]Man(b1-4)GlcNAc(b1-4)GlcNAc'

  def setup
    Monosaccharide.Load_Definitions('data/dictionary.xml')
  end
  
  def test_reading
    sug = ReadingSugar.new 
    sug.sequence = SIMPLE_GLYDE
    sug.target_namespace = NamespacedMonosaccharide::NAMESPACES[:ic]
    assert_equal(SIMPLE_GLYDE_AS_IC, sug.sequence)
  end
  
end