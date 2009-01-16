require "Sugar"
require "set"
require 'DebugLog'

class Glycotransferase
	include DebugLog

  attr_accessor :substrate_pattern, :donor
  attr  :seen

  def Glycotransferase.Apply_Set(enzymes, sugar, max_size=10)
    sugarset = Array.new()
    seen_sugars = Set.new([ sugar.sequence ])
    sugarset << sugar
    added = true
    while added
      added = false
      enzymes.each { |enzyme|
        resultset = Array.new()
        resultset += sugarset
        sugarset.each { |sugar|
          if ( sugar.size < max_size )
            enzyme.acceptors(sugar)
            callback = nil
            if block_given?
              callback = lambda { |sugar,link|
                yield(enzyme,sugar,link)
              }
            end
            new_sugars = enzyme.apply_to_each_substrate(sugar, &callback)
            enzyme.acceptors(sugar)
            new_sugars.each { |sug|
              seq = sug.sequence
              if ! seen_sugars.include?( seq ) 
                seen_sugars << seq
                resultset << sug
              end
            }
          end
        }
        added = ( added || (resultset.size != sugarset.size))
        sugarset = resultset
      }
    end
    sugarset
  end

  def Glycotransferase.CreateFromSugar(sugar)
    enzyme = Glycotransferase.new()
    first_child = sugar.get_path_to_root()[0]
    second_child = first_child.children[0][:residue]
    enzyme.substrate_pattern = first_child.shallow_clone
    enzyme.donor = sugar.get_path_to_root()[0].children[0][:link].deep_clone
    enzyme.donor.set_first_residue(second_child.shallow_clone)
    return enzyme
  end

  def acceptors(sugar)
    results = Array.new()
    sugar.depth_first_traversal { |residue|
      # FIXME - Should be a bit smarter about deciding which namespace to compare?
      if substrate_pattern.name(:id) == residue.name(:id) && residue.can_accept?(donor)
        residue
      end
    }.compact
  end
  
  def accepted_on?(sugar)
    acceptors(sugar).length > 0
  end
  
  def apply(sugar, &callback)
    cloned = sugar.deep_clone
    apply_in_place(cloned, &callback)
    cloned
  end
  
  def apply_in_place(sugar,acceptor=nil)
    acceptors(sugar).find_all { |residue|
      if (acceptor)
        acceptor == residue
      else
        true
      end
    }.each { |residue|
      link = donor.deep_clone
      res = donor.first_residue.deep_clone
      link.set_first_residue(res)      
      if (residue.can_accept?(link))
        residue.add_child(res, link)
        if block_given?
          yield(sugar,link)
        end
      end
    }
    sugar
  end

  def apply_to_each_substrate(sugar, &callback)
    if ( @seen[sugar] )
      return []
    end
    @seen[sugar] = true
    results = Array.new()
    acceptor_count = acceptors(sugar).length - 1
    (0..acceptor_count).each do
      target = sugar.deep_clone
      apply_in_place(target,acceptors(target)[results.length], &callback)
      results << target
    end
    results
  end
  
  def finish
    @substrate_pattern.finish
    @substrate_pattern = nil
    @donor.first_residue.finish
    if (donor.second_residue != nil)
      @donor.second_residue.finish
    end
    @donor.finish
    @donor = nil
  end
  
  def initialize()
    @seen = Hash.new()
  end
  
end
