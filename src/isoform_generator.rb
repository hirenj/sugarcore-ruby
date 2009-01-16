#!/usr/bin/ruby

$:.push('../lib')

require 'Sugar'
include DebugLog

Sugar.log_level(Logger::ERROR)

SUGAR_COMPONENTS = 	[ 	'Gal(b1-3)', 
					 	'Gal(b1-4)',
					 	'Gal(b1-2)',
					 	'GlcNAc(b1-3)',
					 	'GlcNAc(b1-4)',
					 	'GlcNAc(b1-2)',
					]

# Gal 10 , GlcNAc 6
MAX_GAL = 3
MAX_GLCNAC = 2
					
sugars = [ Sugar.new('Gal'), Sugar.new('GlcNAc') ]
completed_sugars = []

test_condition = true

while test_condition

	new_sugars = []
	
	sugars.each { |sugar|

		if (sugar.composition_of('GlcNAc').length == MAX_GLCNAC &&
			sugar.composition_of('Gal').length == MAX_GAL
		   )					
			completed_sugars.push(sugar)
		else

		SUGAR_COMPONENTS.each { |component|
	
			count = sugar.composition.length - 1
			sugar.composition.length.times {
		
				component =~ /([A-Za-z]+)\((.*)\)/
	
				# We need to clone the sugar - what better way than de/serialising!
		
				cloned_sugar = Sugar.new(sugar.sequence)
				if ( cloned_sugar.composition[count].has_child($2) == false )
					cloned_sugar.composition[count].add_child($1,$2)
					
					if (cloned_sugar.composition_of('GlcNAc').length < (MAX_GLCNAC+1) &&
						cloned_sugar.composition_of('Gal').length < (MAX_GAL+1)
					   )					
						new_sugars.push( cloned_sugar )
						#puts cloned_sugar.sequence
					end
				end
				count -= 1
			
			}
		}
		end
	}

	if (new_sugars.length == 0)
		test_condition = false
	else	
		sugars.replace(new_sugars)
	end

end

completed_sugars.each { |sugar|
	puts sugar.sequence
}
