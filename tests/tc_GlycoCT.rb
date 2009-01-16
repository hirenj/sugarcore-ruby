require 'test/unit'
require "Sugar"
require 'Sugar/IO/GlycoCT'
require 'Sugar/IO/CondensedIupac'


class WritableSugar < Sugar
  include Sugar::IO::CondensedIupac::Builder
#  include  Sugar::IO::CondensedIupac::Writer
  include Sugar::IO::GlycoCT::Writer  

  def residueClass
    ICNamespacedMonosaccharide
  end

end


class ReadingSugar < Sugar
  include Sugar::IO::GlycoCT::Builder
  include  Sugar::IO::CondensedIupac::Writer

  def residueClass
    ECDBNamespacedMonosaccharide
  end

end

DebugLog.log_level(5)

class TC_GlycoCT < Test::Unit::TestCase

  SMALL_STRUCTURE_AS_CT = <<__FOO__
RES
1b:u-dglcp;
2b:b-dgalp;
3s:nac;
LIN
1:1(3-1)2;
2:1o(2-1)3;
__FOO__

  SMALL_STRUCTURE_AS_IUPAC = 'Gal(b1-3)GlcNAc'

  def setup
    Monosaccharide.Load_Definitions('data/dictionary.xml')
  end

  def test_write_simple_sequence
    sug = WritableSugar.new()
    sug.sequence = SMALL_STRUCTURE_AS_IUPAC
    sug.target_namespace = :ecdb
    seq = sug.sequence
    seq.gsub!(/\\/,'')
    seq.gsub!(/\n\n/,"\n")
    assert_equal( SMALL_STRUCTURE_AS_CT, seq )
    sug.finish
  end
  
  def test_read_simple_sequence
    sug = ReadingSugar.new()
    sug.sequence = SMALL_STRUCTURE_AS_CT
    sug.target_namespace = NamespacedMonosaccharide::NAMESPACES[:ic]
    assert_equal( SMALL_STRUCTURE_AS_IUPAC, sug.sequence )
    sug.finish
  end
  def teardown
    
  end
end
