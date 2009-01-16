require 'test/unit'
require 'Sugar/IO/CondensedIupac'

require 'Sugar'
include ObjectSpace

NamespacedMonosaccharide.Default_Namespace = :ic

class PrettySugar < Sugar
  include Sugar::IO::CondensedIupac::Builder
  include  Sugar::IO::CondensedIupac::Writer
end

DebugLog.log_level(5)

class TC_SugarGc < Test::Unit::TestCase

  attr :instance_var

  def setup
    Monosaccharide.Load_Definitions('data/dictionary.xml')
    Monosaccharide.Flush_Factory
    assert_equal(0, ObjectSpace.each_object(Monosaccharide) {})
    assert_equal(0, ObjectSpace.each_object(Linkage) {})    
  end

  def test_a_init
    assert_equal(0, ObjectSpace.each_object(Sugar) {})
  end

  def test_simple_monosaccharide
    object_refs = Array.new()
    begin
      object_refs << ObjectSpace.each_object(Monosaccharide) {}
      foo = Monosaccharide.Factory(NamespacedMonosaccharide, 'Gal')
      object_refs << ObjectSpace.each_object(Monosaccharide) {}
      foo.finish()
      foo = nil
      Monosaccharide.Flush_Factory
      ObjectSpace.garbage_collect
    end
    
    ObjectSpace.garbage_collect
    object_refs << ObjectSpace.each_object(Monosaccharide) {}
    
    assert_equal([0,2,0], object_refs)
    assert_equal(0, ObjectSpace.each_object(Monosaccharide) {})
    assert_equal(0, ObjectSpace.each_object(Linkage) {})    
  end
  
  def test_simple_sugar
    object_refs = Array.new()
    begin
      object_refs << ObjectSpace.each_object(Monosaccharide) {}
      foo = PrettySugar.new()
      foo.sequence = 'Gal(b1-3)GlcNAc'
      object_refs << ObjectSpace.each_object(Monosaccharide) {}
      foo.finish
      foo = nil
      Monosaccharide.Flush_Factory
      ObjectSpace.garbage_collect
    end
    ObjectSpace.garbage_collect
    object_refs << ObjectSpace.each_object(Monosaccharide) {}
    
    assert_equal([0,4,0], object_refs)    
    assert_equal(0, ObjectSpace.each_object(Monosaccharide) {})
    assert_equal(0, ObjectSpace.each_object(Linkage) {})
  end
  
  def test_array_of_sugars
    begin
      sugars = Array.new()
      1000.times do
        foo = PrettySugar.new()
        foo.sequence = 'Gal(b1-3)GlcNAc(b1-4)GlcNAc'
        sugars << foo
      end
      assert_equal(3002, ObjectSpace.each_object(Monosaccharide) {})
      assert_equal(2000, ObjectSpace.each_object(Linkage) {})
      sugars.each { |sugar|
        sugar.finish
      }
      sugars = nil
      Monosaccharide.Flush_Factory
      ObjectSpace.garbage_collect
    end
    ObjectSpace.garbage_collect    
    assert_equal(0, ObjectSpace.each_object(Monosaccharide) {})
    assert_equal(0, ObjectSpace.each_object(Linkage) {})
  end
  
  def test_sequence_redefinition
    object_refs = Array.new()
    begin
      object_refs << ObjectSpace.each_object(Monosaccharide) {}
      foo = PrettySugar.new()
      foo.sequence = 'Gal(b1-3)GlcNAc'
      object_refs << ObjectSpace.each_object(Monosaccharide) {}
      begin
        foo.sequence = 'Glc(b1-3)Man(a1-3)GalNAc'
        ObjectSpace.garbage_collect
        object_refs << ObjectSpace.each_object(Monosaccharide) {}        
      end
      foo.finish
      foo = nil
      Monosaccharide.Flush_Factory
      ObjectSpace.garbage_collect
    end
    ObjectSpace.garbage_collect    
    object_refs << ObjectSpace.each_object(Monosaccharide) {}
    
    assert_equal([0,4,9,0], object_refs)    
    assert_equal(0, ObjectSpace.each_object(Monosaccharide) {})
    assert_equal(0, ObjectSpace.each_object(Linkage) {})    
  end

  def test_scope_instance_var
    begin
      results = get_ref_counts_set_instance_var
      results += get_ref_counts_clear_instance_var
      Monosaccharide.Flush_Factory
      ObjectSpace.garbage_collect
    end
    results << ObjectSpace.each_object(Monosaccharide) {}
    assert_equal([0,4,4,0], results)
    assert_equal(0, ObjectSpace.each_object(Monosaccharide) {})
    assert_equal(0, ObjectSpace.each_object(Linkage) {})    
  end
  
  def get_ref_counts_set_instance_var    
    object_refs = Array.new()
    object_refs << ObjectSpace.each_object(Monosaccharide) {}
    @instance_var = PrettySugar.new()
    @instance_var.sequence = 'Gal(b1-3)GlcNAc'
    object_refs << ObjectSpace.each_object(Monosaccharide) {}
    object_refs
  end

  def get_ref_counts_clear_instance_var
    object_refs = Array.new()
    object_refs << ObjectSpace.each_object(Monosaccharide) {}
    @instance_var.finish
    @instance_var = nil
    ObjectSpace.garbage_collect
    object_refs
  end

  def test_clone
    object_refs = Array.new()
    begin
      cloned = nil
      begin
        object_refs << ObjectSpace.each_object(Monosaccharide) {}
        somevar = PrettySugar.new()
        somevar.sequence = 'Gal(b1-3)GlcNAc'
        object_refs << ObjectSpace.each_object(Monosaccharide) {}      
        cloned = somevar.deep_clone
        object_refs << ObjectSpace.each_object(Monosaccharide) {}
        somevar.finish
        somevar = nil
        ObjectSpace.garbage_collect            
      end
      ObjectSpace.garbage_collect            
      object_refs << ObjectSpace.each_object(Monosaccharide) {}

      assert_equal('Gal(b1-3)GlcNAc', cloned.sequence)
      cloned.finish
      cloned = nil
      Monosaccharide.Flush_Factory
      ObjectSpace.garbage_collect            
    end
    ObjectSpace.garbage_collect    
    object_refs << ObjectSpace.each_object(Monosaccharide) {}
    assert_equal([0,4,6,4,0], object_refs)

    assert_equal(0, ObjectSpace.each_object(Monosaccharide) {})
    assert_equal(0, ObjectSpace.each_object(Linkage) {})    
  end

  def test_lots_of_cloning
    begin
      sugar = PrettySugar.new()
      sugar.sequence = 'Gal(b1-3)GlcNAc'
      1000.times do
        somesugar = sugar.deep_clone
        somesugar.sequence
        somesugar.finish
        somesugar = nil
      end
      sugar.finish
      sugar = nil
    end
    Monosaccharide.Flush_Factory
    ObjectSpace.garbage_collect
    assert_equal(0, ObjectSpace.each_object(Monosaccharide) {})
    assert_equal(0, ObjectSpace.each_object(Linkage) {})    
  end

  def test_simple_sugar_and_cleanup
    test_simple_sugar
    test_z_cleanup
  end

  def test_z_cleanup
    Monosaccharide.Flush_Factory
    ObjectSpace.garbage_collect      
    assert_equal(0, ObjectSpace.each_object(Monosaccharide) {})
    assert_equal(0, ObjectSpace.each_object(Linkage) {})
    assert_equal(0, ObjectSpace.each_object(Sugar) {})
  end

end