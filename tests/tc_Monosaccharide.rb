require 'test/unit'
require 'Monosaccharide'

NamespacedMonosaccharide.Default_Namespace = :ic

class TC_Monosaccharide < Test::Unit::TestCase
	require 'Sugar/IO/CondensedIupac'
	

	DebugLog.log_level(5)

	def setup

		assert_nothing_raised {
			Monosaccharide.Load_Definitions('data/dictionary.xml')
		}

    assert_raise(NoMethodError) {  
      Monosaccharide.new('Foobar')
    }
	 
	end

	def test_simple_namespace
		assert_nothing_raised {
			mono = Monosaccharide.Factory( NamespacedMonosaccharide, 'Gal')
		}
		
		# We should not be able to create this Monosaccharide as it is
		# not in the target namespace
		
		assert_raise( MonosaccharideException ) {
			Monosaccharide.Factory( NamespacedMonosaccharide, 'SomeNamespace')		  
		}
	end

  def test_explicit_namespace
		assert_nothing_raised {
			mono = Monosaccharide.Factory( NamespacedMonosaccharide, 'dkfz:D-Galp')
			mono = Monosaccharide.Factory( NamespacedMonosaccharide, 'ic:Gal')
			mono = Monosaccharide.Factory( NamespacedMonosaccharide, 'ecdb:dgalp')
		}    
  end

  def test_namespace_switching
		
		# We should be able to use the DKFZ namespace here
		
		assert_nothing_raised {
		  NamespacedMonosaccharide.Default_Namespace=:dkfz
		  NamespacedMonosaccharide.Load_Definitions('data/dictionary.xml')
			mono = Monosaccharide.Factory( DKFZNamespacedMonosaccharide, 'D-Araf')
		}
		
		# We shouldn't be able to use IUPAC here
		
		assert_raise( MonosaccharideException ) {
		  Monosaccharide.Factory( DKFZNamespacedMonosaccharide, 'Gal')
		}

		assert_raise( MonosaccharideException ) {
		  Monosaccharide.Factory( ICNamespacedMonosaccharide, 'D-Galp')
		}

		
		# We should reset the namespace here
	  NamespacedMonosaccharide.Default_Namespace=:ic
	  setup()
  end

  def test_alternate_namespaces
    mono = Monosaccharide.Factory( NamespacedMonosaccharide, 'Gal')
#    assert_equal(3, mono.alternate_namespaces.length)
#    assert_equal(mono.alternate_namespaces.sort,
#          ['http://glycosciences.de','http://ns.eurocarbdb.org/glycoct','http://www.iupac.org/condensed'])
  end

  def test_attachment_position_consumption
    mono1 = Monosaccharide.Factory( NamespacedMonosaccharide, 'Gal')
    mono2 = Monosaccharide.Factory( NamespacedMonosaccharide, 'Glc')
    mono3 = Monosaccharide.Factory( NamespacedMonosaccharide, 'Man')
    mono1.add_child(mono2, Linkage.Factory( Linkage, {:from => 3, :to => 1}))
    mono2.anomer = 'a'
    mono1.add_child(mono3, Linkage.Factory( Linkage, {:from => 4, :to => 1}))
    mono3.anomer = 'a'
    assert_equal(2,mono1.children.length)
    assert(mono1.attachment_position_consumed?(3) &&
           mono1.attachment_position_consumed?(4) ,
           "Attachment positions not consumed by linkages")
    assert( mono1.attachment_position_consumed?(2) != true,
            "Attachment position mistakenly consumed")
    assert( mono1.residue_at_position(3) == mono2 &&
            mono1.residue_at_position(4) == mono3,
            "Attachment positions correctly mapped to residues")
    assert_equal([3,4], mono1.consumed_positions.sort)
    
    mono4 = Monosaccharide.Factory( NamespacedMonosaccharide, 'Man')
    
    assert_raise( MonosaccharideException ) {
      mono1.add_child(mono4, Linkage.Factory( Linkage, {:from => 4, :to => 1} ))
      mono4.anomer = 'a'
    }
    
    mono5 = Monosaccharide.Factory( NamespacedMonosaccharide, "Man")
    mono6 = Monosaccharide.Factory( NamespacedMonosaccharide, "Gal")    
    mono7 = Monosaccharide.Factory( NamespacedMonosaccharide, "Fuc")    

    mono5.add_child(mono6, Linkage.Factory( Linkage, {:from => 0, :to => 1} ))
    mono5.add_child(mono7, Linkage.Factory( Linkage, {:from => 0, :to => 1} ))

    assert( mono6.parent == mono5)
    assert( mono7.parent == mono5)
    assert( mono5.children.collect { |child| child[:residue].name }.sort == [mono7.name,mono6.name].sort )
    
    mono2.finish()
    mono3.finish()
    mono4.finish()
    mono1.finish()
  end

end


